angular.module('omega').controller 'SwitchProfileCtrl', ($scope, $rootScope,
  $location, $timeout, $q, $modal, profileIcons, getAttachedName, omegaTarget,
  trFilter, downloadFile) ->
  # == Rule list ==
  $scope.ruleListFormats = OmegaPac.Profiles.ruleListFormats

  exportRuleList = ->
    text = OmegaPac.RuleList.Switchy.compose(
      rules: $scope.profile.rules
      defaultProfileName: $scope.attachedOptions.defaultProfileName
    )

    eol = '\r\n'
    info = '\n'
    info += '; Require: SwitchyOmega >= 2.3.2' + eol
    info += "; Date: #{new Date().toLocaleDateString()}" + eol
    info += "; Usage: #{trFilter('ruleList_usageUrl')}" + eol

    text = text.replace('\n', info)

    blob = new Blob [text], {type: "text/plain;charset=utf-8"}
    fileName = $scope.profile.name.replace(/\W+/g, '_')
    downloadFile(blob, "OmegaRules_#{fileName}.sorl")

  exportLegacyRuleList = ->
    wildcardRules = ''
    regexpRules = ''
    for rule in $scope.profile.rules
      i = ''
      if rule.profileName == $scope.attachedOptions.defaultProfileName
        i = '!'
      switch rule.condition.conditionType
        when 'HostWildcardCondition'
          wildcardRules += i + '@*://' + rule.condition.pattern + '/*' + '\r\n'
        when 'UrlWildcardCondition'
          wildcardRules += i + '@' + rule.condition.pattern + '\r\n'
        when 'UrlRegexCondition'
          regexpRules += i + rule.condition.pattern + '\r\n'

    text = """
      ; Summary: Proxy Switchy! Exported Rule List
      ; Date: #{new Date().toLocaleDateString()}
      ; Website: #{trFilter('ruleList_usageUrl')}

      #BEGIN

      [wildcard]
      #{wildcardRules}
      [regexp]
      #{regexpRules}
      #END
    """
    blob = new Blob [text], {type: "text/plain;charset=utf-8"}
    fileName = $scope.profile.name.replace(/\W+/g, '_')
    downloadFile(blob, "SwitchyRules_#{fileName}.ssrl")

  # == Condition types ==
  $scope.conditionHelp =
    show: ($location.search().help == 'condition')

  $scope.basicConditionTypes = [
    {
      group: 'default'
      types: [
        'HostWildcardCondition'
        'UrlWildcardCondition'
        'UrlRegexCondition'
        'FalseCondition'
      ]
    }
  ]

  $scope.advancedConditionTypes = [
    {
      group: 'host'
      types: [
        'HostWildcardCondition'
        'HostRegexCondition'
        'HostLevelsCondition'
        'IpCondition'
      ]
    }
    {
      group: 'url'
      types: [
        'UrlWildcardCondition'
        'UrlRegexCondition'
        'KeywordCondition'
      ]
    }
    {
      group: 'special'
      types: [
        'WeekdayCondition'
        'TimeCondition'
        'FalseCondition'
      ]
    }
  ]

  expandGroups = (groups) ->
    result = []
    for group in groups
      for type in group.types
        result.push({type: type, group: 'condition_group_' + group.group})
    result

  basicConditionTypesExpanded = expandGroups($scope.basicConditionTypes)
  advancedConditionTypesExpanded = expandGroups($scope.advancedConditionTypes)

  basicConditionTypeSet = {}
  for type in basicConditionTypesExpanded
    basicConditionTypeSet[type.type] = type.type

  $scope.conditionTypes = basicConditionTypesExpanded

  $scope.showConditionTypes = 0
  $scope.hasConditionTypes = 0
  $scope.hasUrlConditions = false
  $scope.isUrlConditionType =
    'UrlWildcardCondition': true
    'UrlRegexCondition': true

  updateHasConditionTypes = ->
    return unless $scope.profile?.rules?

    $scope.hasUrlConditions = false
    for rule in $scope.profile.rules
      if $scope.isUrlConditionType[rule.condition.conditionType]
        $scope.hasUrlConditions = true
        break

    return unless $scope.hasConditionTypes == 0
    for rule in $scope.profile.rules
      # Convert TrueCondition to a HostWildcardCondition with pattern '*'.
      if rule.condition.conditionType == 'TrueCondition'
        rule.condition = {
          conditionType: 'HostWildcardCondition'
          pattern: '*'
        }
      if not basicConditionTypeSet[rule.condition.conditionType]
        $scope.hasConditionTypes = 1
        $scope.showConditionTypes = 1
        break

  $scope.$watch 'options["-showConditionTypes"]', (show) ->
    show ||= 0
    if show > 0
      $scope.showConditionTypes = show
    else
      updateHasConditionTypes()
      $scope.showConditionTypes = $scope.hasConditionTypes

    if $scope.options['-exportLegacyRuleList']
      if $scope.showConditionTypes > 0
        $scope.setExportRuleListHandler(exportRuleList, {warning: true})
      else
        $scope.setExportRuleListHandler(exportLegacyRuleList)
    else
      $scope.setExportRuleListHandler(exportRuleList)

    if $scope.showConditionTypes == 0
      $scope.conditionTypes = basicConditionTypesExpanded
      if $scope.options['-exportLegacyRuleList']
        $scope.setExportRuleListHandler exportLegacyRuleList
    else
      $scope.conditionTypes = advancedConditionTypesExpanded
      if not $scope.options["-showConditionTypes"]?
        $scope.options["-showConditionTypes"] = $scope.showConditionTypes
      unwatchRules?()

  if $scope.hasConditionTypes == 0
    unwatchRules = $scope.$watch 'profile.rules', updateHasConditionTypes, true

  # == Rules ==
  rulesReadyDefer = $q.defer()
  rulesReady = rulesReadyDefer.promise
  stopWatchingForRules = $scope.$watch 'profile.rules', (rules) ->
    return unless rules
    stopWatchingForRules()
    rulesReadyDefer.resolve(rules)

  $scope.addRule = ->
    rule =
      if $scope.profile.rules.length > 0
        [..., templ] = $scope.profile.rules
        angular.copy(templ)
      else
        condition: {conditionType: 'HostWildcardCondition', pattern: ''}
        profileName: $scope.attachedOptions.defaultProfileName
    if rule.condition.pattern
      rule.condition.pattern = ''
    $scope.profile.rules.push rule

  $scope.validateCondition = (condition, pattern) ->
    if condition.conditionType.indexOf('Regex') >= 0
      try
        new RegExp(pattern)
      catch
        return false
    return true

  $scope.conditionHasWarning = (condition) ->
    if condition.conditionType == 'HostWildcardCondition'
      pattern = condition.pattern
      return pattern.indexOf(':') >= 0 || pattern.indexOf('/') >= 0
    return false

  $scope.validateIpCondition = (condition, input) ->
    return false unless input
    ip = OmegaPac.Conditions.parseIp(input)
    return ip?

  $scope.getWeekdayList = OmegaPac.Conditions.getWeekdayList
  $scope.updateDay = (condition, i, selected) ->
    condition.days ||= '-------'
    char = if selected then 'SMTWtFs'[i] else '-'
    condition.days = condition.days.substr(0, i) + char +
      condition.days.substr(i + 1)
    delete condition.startDay
    delete condition.endDay

  $scope.removeRule = (index) ->
    removeForReal = ->
      $scope.profile.rules.splice index, 1
    if $scope.options['-confirmDeletion']
      scope = $scope.$new('isolate')
      scope.rule = $scope.profile.rules[index]
      scope.ruleProfile = $scope.profileByName(scope.rule.profileName)
      scope.dispNameFilter = $scope.dispNameFilter
      scope.options = $scope.options
      $modal.open(
        templateUrl: 'partials/rule_remove_confirm.html'
        scope: scope
      ).result.then removeForReal
    else
      removeForReal()

  $scope.cloneRule = (index) ->
    rule = angular.copy($scope.profile.rules[index])
    $scope.profile.rules.splice(index + 1, 0, rule)
    $timeout ->
      input = angular.element(".switch-rule-row:nth-child(#{index + 2}) input")
      input[0]?.focus()
      input[0]?.select()

  $scope.resetRules = ->
    scope = $scope.$new('isolate')
    scope.ruleProfile =
      $scope.profileByName($scope.attachedOptions.defaultProfileName)
    scope.dispNameFilter = $scope.dispNameFilter
    scope.options = $scope.options
    $modal.open(
      templateUrl: 'partials/rule_reset_confirm.html'
      scope: scope
    ).result.then ->
      for rule in $scope.profile.rules
        rule.profileName = $scope.attachedOptions.defaultProfileName

  $scope.sortableOptions =
    handle: '.sort-bar'
    tolerance: 'pointer'
    axis: 'y'
    forceHelperSize: true
    forcePlaceholderSize: true
    containment: 'parent'

  # == Attached ==
  attachedReadyDefer = $q.defer()
  attachedReady = attachedReadyDefer.promise
  $scope.$watch 'profile.name', (name) ->
    $scope.attachedName = getAttachedName(name)
    $scope.attachedKey = OmegaPac.Profiles.nameAsKey($scope.attachedName)

  $scope.$watch 'options[attachedKey]', (attached) ->
    $scope.attached = attached

  $scope.watchAndUpdateRevision 'options[attachedKey]'

  oldSourceUrl = null
  oldLastUpdate = null
  oldRuleList = null
  onAttachedChange = (attached, oldAttached) ->
    return unless attached and oldAttached
    if attached.sourceUrl != oldAttached.sourceUrl
      if attached.lastUpdate
        oldSourceUrl = oldAttached.sourceUrl
        oldLastUpdate = attached.lastUpdate
        oldRuleList = oldAttached.ruleList
        attached.lastUpdate = null
      else if oldSourceUrl and attached.sourceUrl == oldSourceUrl
        attached.lastUpdate = oldLastUpdate
        attached.ruleList = oldRuleList
  $scope.$watch 'options[attachedKey]', onAttachedChange, true

  $scope.attachedOptions = {enabled: false}
  $scope.$watch 'profile.defaultProfileName', (name) ->
    $scope.attachedOptions.enabled = (name == $scope.attachedName)
    if not $scope.attached or not $scope.attachedOptions.enabled
      $scope.attachedOptions.defaultProfileName = name

  $scope.$watch 'attachedOptions.enabled', (enabled, oldValue) ->
    return if enabled == oldValue
    if enabled
      if $scope.profile.defaultProfileName != $scope.attachedName
        $scope.profile.defaultProfileName = $scope.attachedName
    else
      if $scope.profile.defaultProfileName == $scope.attachedName
        if $scope.attached
          $scope.profile.defaultProfileName = $scope.attached.defaultProfileName
          $scope.attachedOptions.defaultProfileName =
            $scope.attached.defaultProfileName
        else
          $scope.profile.defaultProfileName = 'direct'
          $scope.attachedOptions.defaultProfileName = 'direct'

  $scope.$watch 'attached.defaultProfileName', (name) ->
    if name and $scope.attachedOptions.enabled
      $scope.attachedOptions.defaultProfileName = name

  $scope.$watch 'attachedOptions.defaultProfileName', (name) ->
    attachedReadyDefer.resolve()
    if $scope.attached and $scope.attachedOptions.enabled
      $scope.attached.defaultProfileName = name
    else
      $scope.profile.defaultProfileName = name

  $scope.attachNew = ->
    $scope.attached = OmegaPac.Profiles.create(
      name: $scope.attachedName
      defaultProfileName: $scope.profile.defaultProfileName
      profileType: 'RuleListProfile'
      color: $scope.profile.color
    )
    OmegaPac.Profiles.updateRevision($scope.attached)
    $scope.options[$scope.attachedKey] = $scope.attached
    $scope.attachedOptions.enabled = true
    $scope.profile.defaultProfileName = $scope.attachedName

  $scope.removeAttached = ->
    return unless $scope.attached
    scope = $scope.$new('isolate')
    scope.attached = $scope.attached
    scope.dispNameFilter = $scope.dispNameFilter
    scope.options = $scope.options
    $modal.open(
      templateUrl: 'partials/delete_attached.html'
      scope: scope
    ).result.then ->
      $scope.profile.defaultProfileName = $scope.attached.defaultProfileName
      delete $scope.options[$scope.attachedKey]

  # == Edit source ==
  stateEditorKey = 'web._profileEditor.' + $scope.profile.name
  $scope.loadRules = false
  $scope.editSource = false
  parseOmegaRules = (code, {detect, requireResult} = {}) ->
    setError = (error) ->
      if error.reason
        args = error.args ? [
          error.sourceLineNo
          error.source
        ]
        message = trFilter('ruleList_error_' + error.reason, args)
        error.message = message if message
      return {error: error}
    if detect and not OmegaPac.RuleList.Switchy.detect(code)
      return {error: {reason: 'notSwitchy'}}
    refs = OmegaPac.RuleList.Switchy.directReferenceSet({
      ruleList: code
    })
    if requireResult and not refs
      return setError({reason: 'resultNotEnabled'})
    for own key, name of refs
      if not OmegaPac.Profiles.byKey(key, $scope.options)
        return setError({reason: 'unknownProfile', args: [name]})
    try
      return rules: OmegaPac.RuleList.Switchy.parseOmega(code, null, null,
        {strict: true, source: false})
    catch err
      return setError(err)
  parseSource = ->
    return true unless $scope.source
    {rules, error} = parseOmegaRules($scope.source.code.trim(),
      requireResult: true)
    if error
      $scope.source.error = error
      $scope.editSource = true
      return false
    else
      $scope.source.error = undefined
    $scope.attachedOptions.defaultProfileName = rules.pop().profileName
    # Try to merge with existing rules if possible.
    diff = jsondiffpatch.create(
      objectHash: (obj) -> JSON.stringify(obj)
      textDiff: minLength: 1 / 0
    )
    oldRules = angular.fromJson(angular.toJson($scope.profile.rules))
    patch = diff.diff(oldRules, rules)
    jsondiffpatch.patch($scope.profile.rules, patch)
    return true
  $scope.toggleSource = -> $q.all([attachedReady, rulesReady]).then ->
    $scope.editSource = not $scope.editSource
    if $scope.editSource
      args =
        rules: $scope.profile.rules
        defaultProfileName: $scope.attachedOptions.defaultProfileName
      code = OmegaPac.RuleList.Switchy.compose(args, withResult: true)
      $scope.source = {code: code}
    else
      return unless parseSource()
      $scope.source = null
      $scope.loadRules = true
    omegaTarget.state(stateEditorKey, {editSource: $scope.editSource})

  $rootScope.$on '$stateChangeStart', (event, _, __, fromState) ->
    if $scope.editSource and $scope.source.touched
      sourceValid = parseSource()
      event.preventDefault() unless sourceValid

  $scope.$on 'omegaApplyOptions', (event) ->
    if $scope.attached?.ruleList and not $scope.attached.sourceUrl
      $scope.attachedRuleListError = undefined
      {error} = parseOmegaRules($scope.attached.ruleList.trim(), detect: true)
      if error
        if error.reason != 'resultNotEnabled' and error.reason != 'notSwitchy'
          $scope.attachedRuleListError = error
          event.preventDefault()
          angular.element('#attached-rulelist')[0].focus()
      else
        $scope.attached.format = 'Switchy'

    if $scope.editSource and $scope.source.touched
      event.preventDefault()
      if parseSource()
        $scope.source.touched = false
        $timeout ->
          $rootScope.applyOptions()

  omegaTarget.state(stateEditorKey).then (opts) ->
    if opts?.editSource
      $scope.toggleSource()
    else
      $scope.loadRules = true
      getState = omegaTarget.state(['web.switchGuide', 'firstRun'])
      $q.all([rulesReady, getState]).then ([_, [switchGuide, firstRun]]) ->
        return if firstRun or switchGuide == 'shown'
        omegaTarget.state('web.switchGuide', 'shown')
        return if $scope.profile.rules.length == 0
        $script 'js/switch_profile_guide.js'
