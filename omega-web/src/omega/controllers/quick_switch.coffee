angular.module('omega').controller 'QuickSwitchCtrl', ($scope, $filter) ->
  $scope.sortableOptions =
    tolerance: 'pointer'
    axis: 'y'
    forceHelperSize: true
    forcePlaceholderSize: true
    connectWith: '.cycle-profile-container'
    containment: '#quick-switch-settings'

  $scope.$watchCollection 'options', (options) ->
    return unless options?
    $scope.notCycledProfiles =
      for profile in $filter('profiles')(options, 'all') when (
        options["-quickSwitchProfiles"].indexOf(profile.name) < 0)
        profile.name
