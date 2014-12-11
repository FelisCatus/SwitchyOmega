OmegaTarget = require('omega-target')
OmegaPac = OmegaTarget.OmegaPac
Promise = OmegaTarget.Promise

module.exports = class ProxyAuth
  constructor: (options) ->
    @options = options

  listening: false
  listen: ->
    return if @listening
    if not chrome.webRequest
      @options.log.error('Proxy auth disabled! No webRequest permission.')
      return
    chrome.webRequest.onAuthRequired.addListener(
      @authHandler.bind(this)
      {urls: ['<all_urls>']}
      ['blocking']
    )
    chrome.webRequest.onCompleted.addListener(
      @_requestDone.bind(this)
      {urls: ['<all_urls>']}
    )
    chrome.webRequest.onErrorOccurred.addListener(
      @_requestDone.bind(this)
      {urls: ['<all_urls>']}
    )
    @listening = true

  _keyForProxy: (proxy) -> "#{proxy.host}:#{proxy.port}"
  setProxies: (profiles) ->
    @_proxies = {}
    processProfile = (profile) =>
      profile = @options.profile(profile)
      return unless profile?.auth
      for scheme in OmegaPac.Profiles.schemes when profile[scheme.prop]
        auth = profile.auth?[scheme.prop]
        continue unless auth
        proxy = profile[scheme.prop]
        key = @_keyForProxy(proxy)
        list = @_proxies[key]
        if not list?
          @_proxies[key] = list = []
        list.push({
          config: proxy
          auth: auth
          name: profile.name + '.' + scheme.prop
        })

    if Array.isArray(profiles)
      for profile in profiles
        processProfile(profile)
    else
      for _, profile of profiles
        processProfile(profile)

  _proxies: {}
  _requests: {}
  authHandler: (details) ->
    return {} unless details.isProxy
    req = @_requests[details.requestId]
    if not req?
      @_requests[details.requestId] = req = {authTries: 0}

    key = @_keyForProxy(
      host: details.challenger.host
      port: details.challenger.port
    )

    proxy = @_proxies[key]?[req.authTries]
    @options.log.log('ProxyAuth', key, req.authTries, proxy?.name)

    return {} unless proxy?
    req.authTries++
    return authCredentials: proxy.auth

  _requestDone: (details) ->
    delete @_requests[details.requestId]
