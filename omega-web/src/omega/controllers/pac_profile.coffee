angular.module('omega').controller 'PacProfileCtrl', ($scope, $modal) ->
  # coffeelint: disable=max_line_length

  # https://github.com/angular/angular.js/blob/master/src/ng/directive/input.js#L13
  $scope.urlRegex = /^(ftp|http|https):\/\/(\w+:{0,1}\w*@)?(\S+)(:[0-9]+)?(\/|\/([\w#!:.?+=&%@!\-\/]))?$/
  # With the file: scheme added to the pattern:
  $scope.urlWithFile = /^(ftp|http|https|file):\/\/(\w+:{0,1}\w*@)?(\S+)(:[0-9]+)?(\/|\/([\w#!:.?+=&%@!\-\/]))?$/

  # coffeelint: enable=max_line_length
  
  $scope.isFileUrl = OmegaPac.Profiles.isFileUrl
  $scope.pacUrlCtrl = {ctrl: null}

  set = OmegaPac.Profiles.referencedBySet($scope.profile, $scope.options)
  $scope.referenced = Object.keys(set).length > 0

  oldPacUrl = null
  oldLastUpdate = null
  oldPacScript = null
  onProfileChange = (profile, oldProfile) ->
    return unless profile and oldProfile
    if profile.pacUrl != oldProfile.pacUrl
      if profile.lastUpdate
        oldPacUrl = oldProfile.pacUrl
        oldLastUpdate = profile.lastUpdate
        oldPacScript = oldProfile.pacScript
        profile.lastUpdate = null
      else if oldPacUrl and profile.pacUrl == oldPacUrl
        profile.lastUpdate = oldLastUpdate
        profile.pacScript = oldPacScript
    $scope.pacUrlIsFile = $scope.isFileUrl(profile.pacUrl)
  $scope.$watch 'profile', onProfileChange, true

  $scope.editProxyAuth = (scheme) ->
    prop = 'all'
    auth = $scope.profile.auth?[prop]
    scope = $scope.$new('isolate')
    scope.auth = auth && angular.copy(auth)
    $modal.open(
      templateUrl: 'partials/fixed_auth_edit.html'
      scope: scope
      size: 'sm'
    ).result.then (auth) ->
      if not auth?.username
        if $scope.profile.auth
          $scope.profile.auth[prop] = undefined
      else
        $scope.profile.auth ?= {}
        $scope.profile.auth[prop] = auth
