angular.module('omega').constant('builtinProfiles',
  OmegaPac.Profiles.builtinProfiles)

profileColors = [
  '#9ce', '#9d9', '#fa8', '#fe9', '#d497ee', '#47b', '#5b5', '#d63', '#ca0'
]
colors = [].concat(profileColors)
profileColorPalette = (colors.splice(0, 3) while colors.length)

angular.module('omega').constant('profileColors', profileColors)
angular.module('omega').constant('profileColorPalette', profileColorPalette)

attachedPrefix = '__ruleListOf_'
angular.module('omega').constant 'getAttachedName', (name) ->
  attachedPrefix + name
angular.module('omega').constant 'getParentName', (name) ->
  if name.indexOf(attachedPrefix) == 0
    name.substr(attachedPrefix.length)
  else
    undefined

charCodeUnderscore = '_'.charCodeAt(0)
angular.module('omega').constant 'charCodeUnderscore', charCodeUnderscore
angular.module('omega').constant 'isProfileNameHidden', (name) ->
  # Hide profiles beginning with underscore.
  name.charCodeAt(0) == charCodeUnderscore
angular.module('omega').constant 'isProfileNameReserved', (name) ->
  # Reserve profile names beginning with double-underscore.
  (name.charCodeAt(0) == charCodeUnderscore and
  name.charCodeAt(1) == charCodeUnderscore)

angular.module('omega').config ($stateProvider, $urlRouterProvider,
  $httpProvider, $animateProvider, $compileProvider) ->
  $compileProvider.aHrefSanitizationWhitelist(
    /^\s*(https?|ftp|mailto|chrome-extension):/)
  $animateProvider.classNameFilter(/angular-animate/)

  $urlRouterProvider.otherwise '/about'
  
  $urlRouterProvider.otherwise ($injector, $location) ->
    if $location.path() == ''
      $injector.get('omegaTarget').lastUrl() || '/about'
    else
      '/about'
  
  $stateProvider
    .state('ui',
      url: '/ui'
      templateUrl: 'partials/ui.html'
      #controller: 'UiCtrl'
    ).state('general',
      url: '/general'
      templateUrl: 'partials/general.html'
      #controller: 'GeneralCtrl'
    ).state('io',
      url: '/io'
      templateUrl: 'partials/io.html'
      controller: 'IoCtrl'
    ).state('profile',
      url: '/profile/*name'
      templateUrl: 'partials/profile.html'
      controller: 'ProfileCtrl'
    ).state('about',
      url: '/about'
      templateUrl: 'partials/about.html'
      controller: 'AboutCtrl'
    )

angular.module('omega').factory '$exceptionHandler', ($log) ->
  return (exception, cause) ->
    return if exception.message == 'transition aborted'
    return if exception.message == 'transition superseded'
    return if exception.message == 'transition prevented'
    return if exception.message == 'transition failed'
    $log.error(exception, cause)

angular.module('omega').factory 'omegaDebug', ($window, $rootScope,
  $injector) ->
  omegaDebug = $window.OmegaDebug ? {}

  omegaDebug.downloadLog ?= ->
    downloadFile = $injector.get('downloadFile') ? saveAs
    blob = new Blob [localStorage['log']], {type: "text/plain;charset=utf-8"}
    downloadFile(blob, "OmegaLog_#{Date.now()}.txt")

  omegaDebug.reportIssue ?= ->
    $window.open(
      'https://github.com/FelisCatus/SwitchyOmega/issues/new?title=&body=')
    return

  omegaDebug.resetOptions ?= ->
    $rootScope.resetOptions()

  omegaDebug

angular.module('omega').factory 'downloadFile', ->
  if browser?.downloads?.download?
    return (blob, filename) ->
      url = URL.createObjectURL(blob)
      if filename
        browser.downloads.download({url: url, filename: filename})
      else
        browser.downloads.download({url: url})
  else
    return saveAs
