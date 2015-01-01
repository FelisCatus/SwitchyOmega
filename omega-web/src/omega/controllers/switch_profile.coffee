angular.module('omega').controller 'SwitchProfileCtrl', ($scope, $location,
  $modal, profileIcons, getAttachedName, omegaTarget, $timeout) ->

  $scope.showConditionHelp = ($location.search().help == 'condition')

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
        'FalseCondition'
      ]
    }
  ]

  exportRuleList = ->
    wildcardRules = ''
    regexpRules = ''
    for rule in $scope.profile.rules
      i = ''
      if rule.profileName == 'direct'
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
      ; Website: http://bit.ly/proxyswitchy

      #BEGIN

      [wildcard]
      #{wildcardRules}
      [regexp]
      #{regexpRules}
      #END
    """
    blob = new Blob [text], {type: "text/plain;charset=utf-8"}
    fileName = $scope.profile.name.replace(/\W+/g, '_')
    saveAs(blob, "SwitchyRules_#{fileName}.ssrl")

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
  updateHasConditionTypes = ->
    return unless $scope.hasConditionTypes == 0
    return unless $scope.profile?.rules?
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
    if $scope.showConditionTypes == 0
      $scope.conditionTypes = basicConditionTypesExpanded
      $scope.setExportRuleListHandler(exportRuleList)
    else
      $scope.conditionTypes = advancedConditionTypesExpanded
      $scope.setExportRuleListHandler(null)
      if not $scope.options["-showConditionTypes"]?
        $scope.options["-showConditionTypes"] = $scope.showConditionTypes
      unwatchRules?()

  if $scope.hasConditionTypes == 0
    unwatchRules = $scope.$watch 'profile.rules', updateHasConditionTypes, true

  $scope.addRule = ->
    rule =
      if $scope.profile.rules.length > 0
        [..., templ] = $scope.profile.rules
        angular.copy(templ)
      else
        condition: {conditionType: 'HostWildcardCondition', pattern: ''}
        profileName: $scope.profile.defaultProfileName
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
    scope.ruleProfile = $scope.profileByName($scope.defaultProfileName)
    scope.dispNameFilter = $scope.dispNameFilter
    scope.options = $scope.options
    $modal.open(
      templateUrl: 'partials/rule_reset_confirm.html'
      scope: scope
    ).result.then ->
      for rule in $scope.profile.rules
        rule.profileName = $scope.defaultProfileName

  $scope.sortableOptions =
    handle: '.sort-bar'
    tolerance: 'pointer'
    axis: 'y'
    forceHelperSize: true
    forcePlaceholderSize: true
    containment: 'parent'

  $scope.ruleListFormats = OmegaPac.Profiles.ruleListFormats

  $scope.$watch 'profile.name', (name) ->
    $scope.attachedName = getAttachedName(name)
    $scope.attachedKey = OmegaPac.Profiles.nameAsKey($scope.attachedName)

  $scope.$watch 'options[attachedKey]', (attached) ->
    $scope.attached = attached

  $scope.watchAndUpdateRevision 'options[attachedKey]'

  $scope.attachedOptions = {enabled: false}
  $scope.$watch 'profile.defaultProfileName', (name) ->
    $scope.attachedOptions.enabled = (name == $scope.attachedName)
    if not $scope.attached or not $scope.attachedOptions.enabled
      $scope.defaultProfileName = name

  $scope.$watch 'attachedOptions.enabled', (enabled, oldValue) ->
    return if enabled == oldValue
    if enabled
      if $scope.profile.defaultProfileName != $scope.attachedName
        $scope.profile.defaultProfileName = $scope.attachedName
    else
      if $scope.profile.defaultProfileName == $scope.attachedName
        if $scope.attached
          $scope.profile.defaultProfileName = $scope.attached.defaultProfileName
          $scope.defaultProfileName = $scope.attached.defaultProfileName
        else
          $scope.profile.defaultProfileName = 'direct'
          $scope.defaultProfileName = 'direct'

  $scope.$watch 'attached.defaultProfileName', (name) ->
    if name and $scope.attachedOptions.enabled
      $scope.defaultProfileName = name

  $scope.$watch 'defaultProfileName', (name) ->
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

  stopWatchingForGuide = $scope.$watch 'profile.rules', (rules) ->
    return unless rules
    stopWatchingForGuide()
    omegaTarget.state(['web.switchGuide', 'firstRun'
    ]).then ([switchGuide, firstRun]) ->
      return if firstRun or switchGuide == 'shown'
      $script 'js/switch_profile_guide.js'
      omegaTarget.state('web.switchGuide', 'shown')
