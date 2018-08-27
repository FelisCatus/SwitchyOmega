OmegaTarget = require('omega-target')
Promise = OmegaTarget.Promise
chromeApiPromisify = require('../chrome_api').chromeApiPromisify
ProxyImpl = require('./proxy_impl')

class SettingsProxyImpl extends ProxyImpl
  @isSupported: -> chrome?.proxy?.settings?
  features: ['fullUrlHttp', 'pacScript', 'watchProxyChange']
  applyProfile: (profile, meta, options) ->
    meta ?= profile
    if profile.profileType == 'SystemProfile'
      # Clear proxy settings, returning proxy control to Chromium.
      return chromeApiPromisify(chrome.proxy.settings, 'clear')({}).then =>
        chrome.proxy.settings.get {}, @_proxyChangeListener
        return
    config = {}
    if profile.profileType == 'DirectProfile'
      config['mode'] = 'direct'
    else if profile.profileType == 'PacProfile'
      config['mode'] = 'pac_script'

      config['pacScript'] =
        if !profile.pacScript || OmegaPac.Profiles.isFileUrl(profile.pacUrl)
          url: profile.pacUrl
          mandatory: true
        else
          data: OmegaPac.PacGenerator.ascii(profile.pacScript)
          mandatory: true
    else if profile.profileType == 'FixedProfile'
      config = @_fixedProfileConfig(profile)
    else
      config['mode'] = 'pac_script'
      config['pacScript'] =
        mandatory: true
        data: @getProfilePacScript(profile, meta, options)
    return @setProxyAuth(profile, options).then(->
      return chromeApiPromisify(chrome.proxy.settings, 'set')({value: config})
    ).then(=>
      chrome.proxy.settings.get {}, @_proxyChangeListener
      return
    )
  _fixedProfileConfig: (profile) ->
    config = {}
    config['mode'] = 'fixed_servers'
    rules = {}
    protocols = ['proxyForHttp', 'proxyForHttps', 'proxyForFtp']
    protocolProxySet = false
    for protocol in protocols when profile[protocol]?
      rules[protocol] = profile[protocol]
      protocolProxySet = true

    if profile.fallbackProxy
      if profile.fallbackProxy.scheme == 'http'
        # Chromium does not allow HTTP proxies in 'fallbackProxy'.
        if not protocolProxySet
          # Use 'singleProxy' if no proxy is configured for other protocols.
          rules['singleProxy'] = profile.fallbackProxy
        else
          # Try to set the proxies of all possible protocols.
          for protocol in protocols
            rules[protocol] ?= JSON.parse(JSON.stringify(profile.fallbackProxy))
      else
        rules['fallbackProxy'] = profile.fallbackProxy
    else if not protocolProxySet
      config['mode'] = 'direct'

    if config['mode'] != 'direct'
      rules['bypassList'] = bypassList = []
      for condition in profile.bypassList
        bypassList.push(@_formatBypassItem(condition))
      config['rules'] = rules
    return config
  _formatBypassItem: (condition) ->
    str = OmegaPac.Conditions.str(condition)
    i = str.indexOf(' ')
    return str.substr(i + 1)

  _proxyChangeWatchers: null
  _proxyChangeListener: (details) ->
    for watcher in (@_proxyChangeWatchers ? [])
      watcher(details)
  watchProxyChange: (callback) ->
    if not @_proxyChangeWatchers?
      @_proxyChangeWatchers = []
      if chrome?.proxy?.settings?.onChange?
        chrome.proxy.settings.onChange.addListener @_proxyChangeListener
    @_proxyChangeWatchers.push(callback)
    return

module.exports = SettingsProxyImpl
