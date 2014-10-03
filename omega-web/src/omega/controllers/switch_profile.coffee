angular.module('omega').controller 'SwitchProfileCtrl', ($scope, $modal) ->
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
