angular.module('omega').controller 'AboutCtrl', ($scope, $rootScope,
  $uibModal, omegaDebug) ->

  $scope.downloadLog = omegaDebug.downloadLog
  $scope.reportIssue = omegaDebug.reportIssue

  $scope.showResetOptionsModal = ->
    $uibModal.open(templateUrl: 'partials/reset_options_confirm.html').result
      .then -> omegaDebug.resetOptions()

  try
    $scope.version = omegaDebug.getProjectVersion()
  catch _
    $scope.version = '?.?.?'
