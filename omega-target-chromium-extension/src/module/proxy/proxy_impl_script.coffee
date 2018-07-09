OmegaTarget = require('omega-target')
Promise = OmegaTarget.Promise
ProxyImpl = require('./proxy_impl')

class ScriptProxyImpl extends ProxyImpl
  @isSupported: ->
    return browser?.proxy?.register? or browser?.proxy?.registerProxyScript?
  features: ['socks5Auth']
  _proxyScriptUrl: 'js/omega_webext_proxy_script.min.js'
  _proxyScriptDisabled: false
  _proxyScriptInitialized: false
  _proxyScriptState: {}
  watchProxyChange: (callback) -> null
  applyProfile: (profile, state, options) ->
    @log.error(
      'Your browser is outdated! Full-URL based matching, etc. unsupported! ' +
      "Please update your browser ASAP!")
    state = state ? {}
    @_options = options
    state.currentProfileName = profile.name
    if profile.name == ''
      state.tempProfile = profile
    if profile.profileType == 'SystemProfile'
      # MOZ: SystemProfile cannot be done now due to lack of "PASS" support.
      # https://bugzilla.mozilla.org/show_bug.cgi?id=1319634
      # In the mean time, let's just unregister the script.
      if browser.proxy.unregister?
        browser.proxy.unregister()
      else
        # Some older browers may not ship with .unregister API.
        # In that case, let's just set an invalid script to unregister it.
        browser.proxy.registerProxyScript('js/omega_invalid_proxy_script.js')
      @_proxyScriptDisabled = true
    else
      @_proxyScriptState = state
      Promise.all([
        browser.runtime.getBrowserInfo(),
        @_initWebextProxyScript(),
      ]).then ([info]) =>
        if info.vendor == 'Mozilla' and info.buildID < '20170918220054'
          # MOZ: Legacy proxy support expects PAC-like string return type.
          # TODO(catus): Remove support for string return type.
          @log.error(
            'Your browser is outdated! SOCKS5 DNS/Auth unsupported! ' +
            "Please update your browser ASAP! (Current Build #{info.buildID})")
          @_proxyScriptState.useLegacyStringReturn = true
        @_proxyScriptStateChanged()
    return @setProxyAuth(profile, options)
  _initWebextProxyScript: ->
    if not @_proxyScriptInitialized
      browser.proxy.onProxyError.addListener (err) =>
        if err?.message?
          if err.message.indexOf('Invalid Proxy Rule: DIRECT') >= 0
            # DIRECT cannot be parsed in Mozilla earlier due to a bug. Even
            # though it throws, it actually falls back to direct connection
            # so it works.
            # https://bugzilla.mozilla.org/show_bug.cgi?id=1355198
            return
          if err.message.indexOf('Return type must be a string') >= 0
            # MOZ: Legacy proxy support expects PAC-like string return type.
            # TODO(catus): Remove support for string return type.
            #
            @log.error(
              'Your browser is outdated! SOCKS5 DNS/Auth unsupported! ' +
              'Please update your browser ASAP!')
            @_proxyScriptState.useLegacyStringReturn = true
            @_proxyScriptStateChanged()
            return
        @log.error(err)
      browser.runtime.onMessage.addListener (message) =>
        return unless message.event == 'proxyScriptLog'
        if message.level == 'error'
          @log.error(message)
        else if message.level == 'warn'
          @log.error(message)
        else
          @log.log(message)

    if not @_proxyScriptInitialized or @_proxyScriptDisabled
      promise = new Promise (resolve) ->
        onMessage = (message) ->
          return unless message.event == 'proxyScriptLoaded'
          resolve()
          browser.runtime.onMessage.removeListener onMessage
          return
        browser.runtime.onMessage.addListener onMessage
      # The API has been renamed to .register but for some old browsers' sake:
      if browser.proxy.register?
        browser.proxy.register(@_proxyScriptUrl)
      else
        browser.proxy.registerProxyScript(@_proxyScriptUrl)
      @_proxyScriptDisabled = false
    else
      promise = Promise.resolve()
    @_proxyScriptInitialized = true
    return promise

  _proxyScriptStateChanged: ->
    browser.runtime.sendMessage({
      event: 'proxyScriptStateChanged'
      state: @_proxyScriptState
      options: @_options
    }, {
      toProxyScript: true
    })

module.exports = ScriptProxyImpl
