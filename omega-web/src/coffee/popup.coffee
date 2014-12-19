module = angular.module('omegaPopup', ['omegaTarget', 'omegaDecoration',
  'ui.bootstrap', 'ui.validate'])

module.filter 'tr', (omegaTarget) -> omegaTarget.getMessage
module.filter 'dispName', (omegaTarget) ->
  (name) ->
    if typeof name == 'object'
      name = name.name
    omegaTarget.getMessage('profile_' + name) || name

jQuery(document).on 'keydown', (e) ->
  return unless e.keyCode == 38 or e.keyCode == 40
  items = jQuery('.popup-menu-nav > li:not(.ng-hide) > a')

  i = items.index(jQuery(e.target).closest('a'))
  switch e.keyCode
    when 38
      i--
      if i >= 0
        items.eq(i)[0]?.focus()
    when 40
      i++
      items.eq(i)[0]?.focus()

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
    validResultProfiles, refreshOnProfileChange, externalProfile,
    proxyNotControllable]) ->
    $scope.proxyNotControllable = proxyNotControllable
    return if proxyNotControllable
    $scope.availableProfiles = availableProfiles
    $scope.currentProfile = availableProfiles['+' + currentProfileName]
    $scope.currentProfileName = currentProfileName
    $scope.isSystemProfile = isSystemProfile
    $scope.externalProfile = externalProfile
    refreshOnProfileChange = refreshOnProfileChange

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
