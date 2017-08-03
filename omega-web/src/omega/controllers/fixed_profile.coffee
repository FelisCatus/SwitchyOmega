angular.module('omega').controller 'FixedProfileCtrl', ($scope, $modal,
  trFilter) ->
  $scope.urlSchemes = ['', 'http', 'https', 'ftp']
  $scope.urlSchemeDefault = 'fallbackProxy'
  proxyProperties =
    '': 'fallbackProxy'
    'http': 'proxyForHttp'
    'https': 'proxyForHttps'
    'ftp': 'proxyForFtp'
  $scope.schemeDisp =
    '': null
    'http': 'http://'
    'https': 'https://'
    'ftp': 'ftp://'

  defaultPort =
    'http': 80
    'https': 443
    'socks4': 1080
    'socks5': 1080

  $scope.showAdvanced = false

  $scope.optionsForScheme = {}
  for scheme in $scope.urlSchemes
    defaultLabel =
      if scheme
        trFilter('options_protocol_useDefault')
      else
        trFilter('options_protocol_direct')
    $scope.optionsForScheme[scheme] = [
      {label: defaultLabel, value: undefined},
      {label: 'HTTP', value: 'http'},
      {label: 'HTTPS', value: 'https'},
      {label: 'SOCKS4', value: 'socks4'},
      {label: 'SOCKS5', value: 'socks5'},
    ]

  $scope.proxyEditors = {}

  $scope.authSupported = {"http": true, "https": true}
  $scope.isProxyAuthActive = (scheme) ->
    return $scope.profile.auth?[proxyProperties[scheme]]?
  $scope.editProxyAuth = (scheme) ->
    prop = proxyProperties[scheme]
    proxy = $scope.profile[prop]
    scope = $scope.$new('isolate')
    scope.proxy = proxy
    auth = $scope.profile.auth?[prop]
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

  onProxyChange = (proxyEditors, oldProxyEditors) ->
    return unless proxyEditors
    for scheme in $scope.urlSchemes
      proxy = proxyEditors[scheme]
      if $scope.profile.auth and not $scope.authSupported[proxy.scheme]
        delete $scope.profile.auth[proxyProperties[scheme]]
      if not proxy.scheme
        if not scheme
          proxyEditors[scheme] = {}
        delete $scope.profile[proxyProperties[scheme]]
        continue
      else if not oldProxyEditors[scheme].scheme
        if proxy.scheme == proxyEditors[''].scheme
          proxy.port ?= proxyEditors[''].port
        proxy.port ?= defaultPort[proxy.scheme]
        proxy.host ?= proxyEditors[''].host ? 'example.com'
      $scope.profile[proxyProperties[scheme]] ?= proxy
  for scheme in $scope.urlSchemes
    do (scheme) ->
      $scope.$watch (-> $scope.profile[proxyProperties[scheme]]), (proxy) ->
        if scheme and proxy
          $scope.showAdvanced = true
        $scope.proxyEditors[scheme] = proxy ? {}
  $scope.$watch 'proxyEditors', onProxyChange, true

  onBypassListChange = (list) ->
    $scope.bypassList = (item.pattern for item in list).join('\n')

  $scope.$watch 'profile.bypassList', onBypassListChange, true

  $scope.$watch 'bypassList', (bypassList, oldList) ->
    return if not bypassList? or bypassList == oldList
    $scope.profile.bypassList =
      for entry in bypassList.split(/\r?\n/) when entry
        conditionType: "BypassCondition"
        pattern: entry
