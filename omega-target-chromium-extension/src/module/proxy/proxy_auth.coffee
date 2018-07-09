OmegaTarget = require('omega-target')
OmegaPac = OmegaTarget.OmegaPac
Promise = OmegaTarget.Promise

module.exports = class ProxyAuth
  constructor: (log) ->
    @_requests = {}
    @log = log

  listening: false
  listen: ->
    return if @listening
    if not chrome.webRequest
      @log.error('Proxy auth disabled! No webRequest permission.')
      return
    if not chrome.webRequest.onAuthRequired
      @log.error('Proxy auth disabled! onAuthRequired not available.')
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

  _keyForProxy: (proxy) -> "#{proxy.host.toLowerCase()}:#{proxy.port}"
  setProxies: (profiles) ->
    @_proxies = {}
    @_fallbacks = []
    for profile in profiles when profile.auth
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

      fallback = profile.auth?['all']
      if fallback?
        @_fallbacks.push({
          auth: fallback
          name: profile.name + '.' + 'all'
        })

  _proxies: {}
  _fallbacks: []
  _requests: null
  authHandler: (details) ->
    return {} unless details.isProxy
    req = @_requests[details.requestId]
    if not req?
      @_requests[details.requestId] = req = {authTries: 0}

    key = @_keyForProxy(
      host: details.challenger.host
      port: details.challenger.port
    )

    list = @_proxies[key]
    listLen = if list? then list.length else 0
    if req.authTries < listLen
      proxy = list[req.authTries]
    else
      proxy = @_fallbacks[req.authTries - listLen]
    @log.log('ProxyAuth', key, req.authTries, proxy?.name)

    return {} unless proxy?
    req.authTries++
    return authCredentials: proxy.auth

  _requestDone: (details) ->
    delete @_requests[details.requestId]
