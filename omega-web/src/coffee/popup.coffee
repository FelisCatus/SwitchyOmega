module = angular.module('omegaPopup', ['omegaTarget', 'omegaDecoration',
  'ui.bootstrap', 'ui.validate'])

module.filter 'tr', (omegaTarget) -> omegaTarget.getMessage
module.filter 'dispName', (omegaTarget) ->
  (name) -> omegaTarget.getMessage('profile_' + name) || name

module.controller 'PopupCtrl', ($scope, $window, $q, omegaTarget,
  profileIcons, profileOrder) ->

  refreshOnProfileChange = false
  refresh = ->
    if refreshOnProfileChange
      omegaTarget.refreshActivePage().then ->
        $window.close()
    else
      $window.close()
  $scope.profileIcons = profileIcons
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
  $scope.openOptions = (hash) ->
    omegaTarget.openOptions(hash).then ->
      $window.close()
  $scope.openConditionHelp = ->
    pname = encodeURIComponent($scope.currentProfileName)
    $scope.openOptions("#/profile/#{pname}?help=condition")
  $scope.applyProfile = (profile) ->
    omegaTarget.applyProfile(profile.name).then ->
      refresh()

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
    $scope.builtinProfiles = []
    $scope.customProfiles = []
    $scope.availableProfiles = availableProfiles
    charCodeUnderscore = '_'.charCodeAt(0)
    for own key, profile of availableProfiles
      if profile.builtin
        $scope.builtinProfiles.push(profile)
      else if profile.name.charCodeAt(0) != charCodeUnderscore
        $scope.customProfiles.push(profile)
    $scope.customProfiles.sort(profileOrder)
    $scope.currentProfile = availableProfiles['+' + currentProfileName]
    $scope.currentProfileName = currentProfileName
    $scope.isSystemProfile = isSystemProfile
    $scope.externalProfile = externalProfile
    refreshOnProfileChange = refreshOnProfileChange
    $scope.validResultProfiles = []
    for name in validResultProfiles
      shown = (name.charCodeAt(0) != charCodeUnderscore or
               name.charCodeAt(1) != charCodeUnderscore)
      if shown
        $scope.validResultProfiles.push(availableProfiles['+' + name])

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
