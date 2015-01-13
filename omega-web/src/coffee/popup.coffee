module = angular.module('omegaPopup', ['omegaTarget', 'omegaDecoration',
  'ui.bootstrap', 'ui.validate'])

module.filter 'tr', (omegaTarget) -> omegaTarget.getMessage
module.filter 'dispName', (omegaTarget) ->
  (name) ->
    if typeof name == 'object'
      name = name.name
    omegaTarget.getMessage('profile_' + name) || name

shortcutKeys =
  38: (activeIndex, items) -> # Up
    i = activeIndex - 1
    if i >= 0
      items.eq(i)[0]?.focus()
  40: (activeIndex, items) -> # Down
    items.eq(activeIndex + 1)[0]?.focus()
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
  73: 'issue' # i
  76: 'log' # l

for i in [1..9]
  shortcutKeys[48 + i] = i

customProfiles = do ->
  _customProfiles = null
  return ->
    _customProfiles ?= jQuery('.custom-profile:not(.ng-hide) > a')

jQuery(document).on 'keydown', (e) ->
  handler = shortcutKeys[e.keyCode]
  return unless handler
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
            'issue': 'I'
            'log': 'L'
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
    omegaTarget.applyProfile(profile.name).then(->
      if refreshOnProfileChange
        return omegaTarget.refreshActivePage()
    ).then(->
      if profile.profileType == 'SwitchProfile'
        return omegaTarget.state('web.switchGuide').then (switchGuide) ->
          if switchGuide == 'showOnFirstUse'
            return $scope.openOptions("#/profile/#{profile.name}")
    ).then ->
      $window.close()

  $scope.tempRuleMenu = {open: false}
  $scope.nameExternal = {open: false}
  $scope.addTempRule = (domain, profileName) ->
    $scope.tempRuleMenu.open = false
    omegaTarget.addTempRule(domain, profileName).then ->
      refresh()

  $scope.setDefaultProfile = (profileName, defaultProfileName) ->
    omegaTarget.setDefaultProfile(profileName, defaultProfileName).then ->
      refresh()
  
  $scope.addCondition = (condition, profileName) ->
    omegaTarget.addCondition(condition, profileName).then ->
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

  omegaTarget.state([
    'availableProfiles', 'currentProfileName', 'isSystemProfile',
    'validResultProfiles', 'refreshOnProfileChange', 'externalProfile',
    'proxyNotControllable'
  ]).then ([availableProfiles, currentProfileName, isSystemProfile,
    validResultProfiles, refresh, externalProfile,
    proxyNotControllable]) ->
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

  omegaTarget.getActivePageInfo().then((info) ->
    if info
      $scope.currentTempRuleProfile = info.tempRuleProfileName
      $scope.currentDomain = info.domain
    else
      $q.reject()
  ).then(->
    omegaTarget.state('currentProfileCanAddRule')
  ).then (value) ->
    $scope.currentProfileCanAddRule = value
    if $scope.currentProfileCanAddRule
      currentDomain = $scope.currentDomain
      currentDomainEscaped = currentDomain.replace('.', '\\.')
      conditionSuggestion =
        'HostWildcardCondition': '*.' + currentDomain
        'HostRegexCondition': '(^|\\.)' + currentDomainEscaped + '$'
        'UrlWildcardCondition': '*://*.' + currentDomain + '/*'
        'UrlRegexCondition': '://([^/.]+\\.)*' + currentDomainEscaped + '/'
        'KeywordCondition': currentDomain
      $scope.rule =
        condition:
          conditionType: 'HostWildcardCondition'
          pattern: conditionSuggestion['HostWildcardCondition']
        profileName: $scope.currentTempRuleProfile ? 'direct'
      $scope.$watch 'rule.condition.conditionType', (type) ->
        $scope.rule.condition.pattern = conditionSuggestion[type]
