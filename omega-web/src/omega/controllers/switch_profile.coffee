angular.module('omega').controller 'SwitchProfileCtrl', ($scope, $modal,
  profileIcons) ->

  $scope.conditionI18n =
    'HostWildcardCondition': 'condition_hostWildcard'
    'HostRegexCondition': 'condition_hostRegex'
    'HostLevelsCondition': 'condition_hostLevels'
    'UrlWildcardCondition': 'condition_urlWildcard'
    'UrlRegexCondition': 'condition_urlRegex'
    'KeywordCondition': 'condition_keyword'
    'AlwaysCondition': 'condition_always'
    'NeverCondition': 'condition_never'

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
      scope.conditionI18n = $scope.conditionI18n
      scope.ruleProfile = $scope.profileByName(scope.rule.profileName)
      scope.profileIcons = $scope.profileIcons
      $modal.open(
        templateUrl: 'partials/rule_remove_confirm.html'
        scope: scope
      ).result.then removeForReal
    else
      removeForReal()

  $scope.resetRules = ->
    scope = $scope.$new('isolate')
    scope.ruleProfile = $scope.profileByName($scope.profile.defaultProfileName)
    scope.profileIcons = $scope.profileIcons
    $modal.open(
      templateUrl: 'partials/rule_reset_confirm.html'
      scope: scope
    ).result.then ->
      for rule in $scope.profile.rules
        rule.profileName = $scope.profile.defaultProfileName

  $scope.sortableOptions =
    handle: '.sort-bar'
    tolerance: 'pointer'
    axis: 'y'
    forceHelperSize: true
    forcePlaceholderSize: true
    containment: 'parent'

  $scope.ruleListFormats = OmegaPac.Profiles.ruleListFormats

  $scope.$watch 'profile.name', (name) ->
    $scope.attachedName = '__ruleListOf_' + name
    $scope.attachedKey = OmegaPac.Profiles.nameAsKey('__ruleListOf_' + name)

  $scope.$watch 'options[attachedKey]', (attached) ->
    $scope.attached = attached

  onAttachedChange = (profile, oldProfile) ->
    return profile if profile == oldProfile or not profile or not oldProfile
    OmegaPac.Profiles.updateRevision(profile)
    return profile
  $scope.omegaWatchAndChange 'options[attachedKey]', onAttachedChange, true

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
    scope.profileIcons = profileIcons
    $modal.open(
      templateUrl: 'partials/delete_attached.html'
      scope: scope
    ).result.then ->
      $scope.profile.defaultProfileName = $scope.attached.defaultProfileName
      delete $scope.options[$scope.attachedKey]
