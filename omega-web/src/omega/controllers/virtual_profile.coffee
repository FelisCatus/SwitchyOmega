angular.module('omega').controller 'VirtualProfileCtrl', ($scope, $location,
  $modal, profileIcons, getAttachedName) ->

  onProfileChange = (profile, oldProfile) ->
    return if profile == oldProfile or not profile or not oldProfile
    target = $scope.profileByName(profile.defaultProfileName)
    profile.color = target.color
    profile.virtualType = target.profileType
  $scope.$watch 'profile', onProfileChange, true
