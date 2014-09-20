angular.module('omega').controller 'IoCtrl', ($scope, $rootScope) ->
  $scope.exportOptions = ->
    $rootScope.applyOptionsConfirm().then ->
      plainOptions = angular.fromJson(angular.toJson($rootScope.options))
      content = JSON.stringify(plainOptions)
      blob = new Blob [content], {type: "text/plain;charset=utf-8"}
      saveAs(blob, "OmegaOptions.bak")

  $scope.restoreLocal = (content) ->
    $rootScope.resetOptions(content).then ( ->
      $rootScope.showAlert(
        type: 'success'
        i18n: 'options_importSuccess'
        message: 'Options imported.'
      )
    ), -> $scope.restoreLocalError()
  $scope.restoreLocalError = ->
    $rootScope.showAlert(
      type: 'error'
      i18n: 'options_importFormatError'
      message: 'Invalid backup file!'
    )
  $scope.downloadError = ->
    $rootScope.showAlert(
      type: 'error'
      i18n: 'options_importDownloadError'
      message: 'Error downloading backup file!'
    )
  $scope.triggerFileInput = ->
    angular.element('#restore-local-file').click()
    return
  $scope.restoreOnline = ->
    $.ajax(
      url: $scope.restoreOnlineUrl,
      success: (content) -> $scope.$apply ->
        $scope.restoreLocal(content)
      error: $scope.downloadError,
      dataType: "text",
      cache: false,
      timeout: 10000
    )
