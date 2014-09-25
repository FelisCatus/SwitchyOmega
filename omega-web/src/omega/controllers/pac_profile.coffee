angular.module('omega').controller 'PacProfileCtrl', ($scope) ->
  # coffeelint: disable=max_line_length

  # https://github.com/angular/angular.js/blob/master/src/ng/directive/input.js#L13
  $scope.urlRegex = /^(ftp|http|https):\/\/(\w+:{0,1}\w*@)?(\S+)(:[0-9]+)?(\/|\/([\w#!:.?+=&%@!\-\/]))?$/
  # With the file: scheme added to the pattern:
  $scope.urlWithFile = /^(ftp|http|https|file):\/\/(\w+:{0,1}\w*@)?(\S+)(:[0-9]+)?(\/|\/([\w#!:.?+=&%@!\-\/]))?$/

  # coffeelint: enable=max_line_length
  
  $scope.isFileUrl = OmegaPac.Profiles.isFileUrl
  $scope.pacUrlCtrl = {ctrl: null}
  $scope.$watch 'pacUrlCtrl.ctrl', console.log.bind(console)

  set = OmegaPac.Profiles.referencedBySet($scope.profile, $scope.options)
  $scope.referenced = Object.keys(set).length > 0

  onProfileChange = (profile) ->
    $scope.pacUrlIsFile = $scope.isFileUrl(profile.pacUrl)
  $scope.$watch 'profile', onProfileChange, true
