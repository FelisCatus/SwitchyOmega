module = angular.module('omegaPopup', ['omegaTarget', 'omegaDecoration',
  'ui.bootstrap', 'ui.validate'])

module.filter 'tr', (omegaTarget) -> omegaTarget.getMessage
module.filter 'dispName', (omegaTarget) ->
  (name) ->
    if typeof name == 'object'
      name = name.name
    omegaTarget.getMessage('profile_' + name) || name

moveUp = (activeIndex, items) ->
  i = activeIndex - 1
  if i >= 0
    items.eq(i)[0]?.focus()
moveDown = (activeIndex, items) -> items.eq(activeIndex + 1)[0]?.focus()
shortcutKeys =
  38: moveUp # Up
  40: moveDown # Down
  74: moveDown # j
  75: moveUp # k
  48: '+direct' # 0
  83: '+system' # s
  191: 'help' # /
  63: 'help' # ?
  69: 'external' # e
  65: 'addRule' # a
  43: 'addRule' # +
  61: 'addRule' # =
  84: 'tempRule' # t
  79: 'option' # o
  82: 'requestInfo' # r

for i in [1..9]
  shortcutKeys[48 + i] = i

customProfiles = do ->
  _customProfiles = null
  return ->
    _customProfiles ?= jQuery('.custom-profile:not(.ng-hide) > a')

jQuery(document).on 'keydown', (e) ->
  handler = shortcutKeys[e.keyCode]
  return unless handler
  return if e.target.tagName == 'INPUT' or e.target.tagName == 'TEXTAREA'
  switch typeof handler
    when 'string'
      switch handler
        when 'help'
          showHelp = (element, key) ->
            if typeof element == 'string'
              element = jQuery("a[data-shortcut='#{element}']")
            span = jQuery('.shortcut-help', element)
            if span.length == 0
              span = jQuery('<span/>').addClass('shortcut-help')
            span.text(key)
            element.find('.glyphicon').after(span)
          keys =
            '+direct': '0'
            '+system': 'S'
            'external': 'E'
            'addRule': 'A'
            'tempRule': 'T'
            'option': 'O'
            'requestInfo': 'R'
          for shortcut, key of keys
            showHelp(shortcut, key)
          customProfiles().each (i, el) ->
            if i <= 8
              showHelp(jQuery(el), i + 1)
        else
          jQuery("a[data-shortcut='#{handler}']")[0]?.click()
    when 'number'
      customProfiles().eq(handler - 1)?.click()
    when 'function'
      items = jQuery('.popup-menu-nav > li:not(.ng-hide) > a')
      i = items.index(jQuery(e.target).closest('a'))
      if i == -1
        i = items.index(jQuery('.popup-menu-nav > li.active > a'))
      handler(i, items)

  return false

module.controller 'PopupCtrl', ($scope, $window, $q, omegaTarget,
  profileIcons, profileOrder, dispNameFilter, getVirtualTarget) ->

  $scope.closePopup = ->
    $window.close()

  $scope.openManage = ->
    omegaTarget.openManage()
    $window.close()

  refreshOnProfileChange = false
  refresh = ->
    if refreshOnProfileChange
      omegaTarget.refreshActivePage().then ->
        $window.close()
    else
      $window.close()
  $scope.profileIcons = profileIcons
  $scope.dispNameFilter = dispNameFilter
  $scope.isActive = (profileName) ->
    if $scope.isSystemProfile
      profileName == 'system'
    else
      $scope.currentProfileName == profileName
  $scope.isEffective = (profileName) ->
    $scope.isSystemProfile and $scope.currentProfileName == profileName
  $scope.getIcon = (profile, normal) ->
    return unless profile
    if not normal and $scope.isEffective(profile.name)
      'glyphicon-ok'
    else
      undefined
  $scope.getProfileTitle = (profile, normal) ->
    desc = ''
    while profile
      desc = profile.desc
      profile = getVirtualTarget(profile, $scope.availableProfiles)
    desc || profile?.name || ''
  $scope.openOptions = (hash) ->
    omegaTarget.openOptions(hash).then ->
      $window.close()
  $scope.openConditionHelp = ->
    pname = encodeURIComponent($scope.currentProfileName)
    $scope.openOptions("#/profile/#{pname}?help=condition")

  $scope.applyProfile = (profile) ->
    next = ->
      if profile.profileType == 'SwitchProfile'
        return omegaTarget.state('web.switchGuide').then (switchGuide) ->
          if switchGuide == 'showOnFirstUse'
            return $scope.openOptions("#/profile/#{profile.name}")
    if not refreshOnProfileChange
      omegaTarget.applyProfileNoReply(profile.name)
      apply = next()
    else
      apply = omegaTarget.applyProfile(profile.name).then(->
        return omegaTarget.refreshActivePage()
      ).then(next)

    if apply
      apply.then -> $window.close()
    else
      $window.close()

  $scope.tempRuleMenu = {open: false}
  $scope.nameExternal = {open: false}
  $scope.addTempRule = (domain, profileName) ->
    $scope.tempRuleMenu.open = false
    omegaTarget.addTempRule(domain, profileName).then ->
      omegaTarget.state('lastProfileNameForCondition', profileName)
      refresh()

  $scope.setDefaultProfile = (profileName, defaultProfileName) ->
    omegaTarget.setDefaultProfile(profileName, defaultProfileName).then ->
      refresh()
  
  $scope.addCondition = (condition, profileName) ->
    omegaTarget.addCondition(condition, profileName).then ->
      omegaTarget.state('lastProfileNameForCondition', profileName)
      refresh()

  $scope.addConditionForDomains = (domains, profileName) ->
    conditions = []
    for own domain, enabled of domains when enabled
      conditions.push({
        conditionType: 'HostWildcardCondition'
        pattern: domain
      })
    omegaTarget.addCondition(conditions, profileName).then ->
      omegaTarget.state('lastProfileNameForCondition', profileName)
      refresh()
  
  $scope.validateProfileName =
    conflict: '!$value || !availableProfiles["+" + $value]'
    hidden: '!$value || $value[0] != "_"'

  $scope.saveExternal = ->
    $scope.nameExternal.open = false
    name = $scope.externalProfile.name
    if name
      omegaTarget.addProfile($scope.externalProfile).then ->
        omegaTarget.applyProfile(name).then ->
          refresh()

  $scope.returnToMenu = ->
    if location.hash.indexOf('!') >= 0
      location.href = 'popup/index.html'
      return
    $scope.showConditionForm = false
    $scope.showRequestInfo = false

  preselectedProfileNameForCondition = 'direct'

  if $window.location.hash == '#!requestInfo'
    $scope.showRequestInfo = true
  else if $window.location.hash == '#!external'
    $scope.nameExternal = {open: true}

  omegaTarget.state([
    'availableProfiles', 'currentProfileName', 'isSystemProfile',
    'validResultProfiles', 'refreshOnProfileChange', 'externalProfile',
    'proxyNotControllable', 'lastProfileNameForCondition'
  ]).then ([availableProfiles, currentProfileName, isSystemProfile,
    validResultProfiles, refresh, externalProfile,
    proxyNotControllable, lastProfileNameForCondition]) ->
    $scope.proxyNotControllable = proxyNotControllable
    return if proxyNotControllable
    $scope.availableProfiles = availableProfiles
    $scope.currentProfile = availableProfiles['+' + currentProfileName]
    $scope.currentProfileName = currentProfileName
    $scope.isSystemProfile = isSystemProfile
    $scope.externalProfile = externalProfile
    refreshOnProfileChange = refresh

    charCodeUnderscore = '_'.charCodeAt(0)
    profilesByNames = (names) ->
      profiles = []
      for name in names
        shown = (name.charCodeAt(0) != charCodeUnderscore or
                 name.charCodeAt(1) != charCodeUnderscore)
        if shown
          profiles.push(availableProfiles['+' + name])
      profiles

    $scope.validResultProfiles = profilesByNames(validResultProfiles)

    if lastProfileNameForCondition
      for profile in $scope.validResultProfiles
        if profile.name == lastProfileNameForCondition
          preselectedProfileNameForCondition = lastProfileNameForCondition

    $scope.builtinProfiles = []
    $scope.customProfiles = []
    for own key, profile of availableProfiles
      if profile.builtin
        $scope.builtinProfiles.push(profile)
      else if profile.name.charCodeAt(0) != charCodeUnderscore
        $scope.customProfiles.push(profile)
      if profile.validResultProfiles
        profile.validResultProfiles =
          profilesByNames(profile.validResultProfiles)

    $scope.customProfiles.sort(profileOrder)

  $scope.domainsForCondition = {}
  $scope.requestInfoProvided = null
  omegaTarget.setRequestInfoCallback (info) ->
    info.domains = []
    for own domain, domainInfo of info.summary
      domainInfo.domain = domain
      info.domains.push(domainInfo)
    info.domains.sort (a, b) -> b.errorCount - a.errorCount
    $scope.$apply ->
      $scope.requestInfo = info
      $scope.requestInfoProvided ?= (info?.domains.length > 0)
      for domain in info.domains
        $scope.domainsForCondition[domain.domain] ?= true
      $scope.profileForDomains ?= preselectedProfileNameForCondition

  $q.all([
    omegaTarget.state('currentProfileCanAddRule')
    omegaTarget.getActivePageInfo(),
  ]).then ([canAddRule, info]) ->
    $scope.currentProfileCanAddRule = canAddRule
    if info
      $scope.currentTempRuleProfile = info.tempRuleProfileName
      if $scope.currentTempRuleProfile
        preselectedProfileNameForCondition = $scope.currentTempRuleProfile
      $scope.currentDomain = info.domain
      if $window.location.hash == '#!addRule'
        $scope.prepareConditionForm()

  $scope.prepareConditionForm = ->
    currentDomain = $scope.currentDomain
    currentDomainEscaped = currentDomain.replace(/\./g, '\\.')
    domainLooksLikeIp = false
    if currentDomain.indexOf(':') >= 0
      domainLooksLikeIp = true
      if currentDomain[0] != '['
        currentDomain = '[' + currentDomain + ']'
        currentDomainEscaped = currentDomain.replace(/\./g, '\\.')
          .replace(/\[/g, '\\[').replace(/\]/g, '\\]')
    else if currentDomain[currentDomain.length - 1] >= 0
      domainLooksLikeIp = true

    if domainLooksLikeIp
      conditionSuggestion =
        'HostWildcardCondition': currentDomain
        'HostRegexCondition': '^' + currentDomainEscaped + '$'
        'UrlWildcardCondition': '*://' + currentDomain + '/*'
        'UrlRegexCondition': '://' + currentDomainEscaped + '(:\\d+)?/'
        'KeywordCondition': currentDomain
    else
      conditionSuggestion =
        'HostWildcardCondition': '*.' + currentDomain
        'HostRegexCondition': '(^|\\.)' + currentDomainEscaped + '$'
        'UrlWildcardCondition': '*://*.' + currentDomain + '/*'
        'UrlRegexCondition':
          '://([^/.]+\\.)*' + currentDomainEscaped + '(:\\d+)?/'
        'KeywordCondition': currentDomain

    $scope.rule =
      condition:
        conditionType: 'HostWildcardCondition'
        pattern: conditionSuggestion['HostWildcardCondition']
      profileName: preselectedProfileNameForCondition
    $scope.$watch 'rule.condition.conditionType', (type) ->
      $scope.rule.condition.pattern = conditionSuggestion[type]

    $scope.showConditionForm = true
