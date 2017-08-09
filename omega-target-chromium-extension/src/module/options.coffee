OcontextMenu_inspectElementmegaTarget = require('omega-target')
OmegaPac = OmegaTarget.OmegaPac
Promise = OmegaTarget.Promise
querystring = require('querystring')
chromeApiPromisifyAll = require('./chrome_api')
if chrome?.proxy?.settings
  proxySettings = chromeApiPromisifyAll(chrome.proxy.settings)
else
  proxySettings =
    setAsync: -> Promise.resolve()
    clearAsync: -> Promise.resolve()
    get: -> null
    onChange: addListener: -> null
parseExternalProfile = require('./parse_external_profile')
ProxyAuth = require('./proxy_auth')
WebRequestMonitor = require('./web_request_monitor')
ChromePort = require('./chrome_port')
fetchUrl = require('./fetch_url')
Url = require('url')

class ChromeOptions extends OmegaTarget.Options
  _inspect: null
  parseExternalProfile: (details) ->
    parseExternalProfile(details, @_options, @_fixedProfileConfig.bind(this))

  fetchUrl: fetchUrl

  updateProfile: (args...) ->
    super(args...).then (results) ->
      error = false
      for own profileName, result of results
        if result instanceof Error
          error = true
          break
      if error
        # TODO(catus): Find a better way to notify the user.
        ###
        @setBadge(
          text: '!'
          color: '#faa732'
          title: chrome.i18n.getMessage('browserAction_titleDownloadFail')
        )
        ###
      return results

  _proxyNotControllable: null
  proxyNotControllable: -> @_proxyNotControllable
  setProxyNotControllable: (reason, badge) ->
    @_proxyNotControllable = reason
    if reason
      @_state.set({'proxyNotControllable': reason})
      @setBadge(badge)
    else
      @_state.remove(['proxyNotControllable'])
      @clearBadge()

  _badgeTitle: null
  setBadge: (options) ->
    if not options
      options =
        if @_proxyNotControllable
          text: '='
          color: '#da4f49'
        else
          text: '?'
          color: '#49afcd'
    chrome.browserAction.setBadgeText(text: options.text)
    chrome.browserAction.setBadgeBackgroundColor(color: options.color)
    if options.title
      @_badgeTitle = options.title
      chrome.browserAction.setTitle(title: options.title)
    else
      @_badgeTitle = null
  clearBadge: ->
    return if @externalApi.disabled
    if @_badgeTitle
      @currentProfileChanged('clearBadge')
    if @_proxyNotControllable
      @setBadge()
    else
      chrome.browserAction.setBadgeText?(text: '')
    return

  _formatBypassItem: (condition) ->
    str = OmegaPac.Conditions.str(condition)
    i = str.indexOf(' ')
    return str.substr(i + 1)
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

  _proxyChangeWatchers: null
  _proxyChangeListener: null
  watchProxyChange: (callback) ->
    @_proxyChangeWatchers = []
    if not @_proxyChangeListener?
      @_proxyChangeListener = (details) =>
        for watcher in @_proxyChangeWatchers
          watcher(details)
      proxySettings.onChange.addListener @_proxyChangeListener
    @_proxyChangeWatchers.push(callback)
  applyProfileProxy: (profile, meta) ->
    if chrome?.proxy?.settings?
      return @applyProfileProxySettings(profile, meta)
    else if browser?.proxy?.registerProxyScript?
      return @applyProfileProxyScript(profile, meta)
    else
      ex = new Error('Your browser does not support proxy settings!')
      return Promise.reject ex
  applyProfileProxySettings: (profile, meta) ->
    meta ?= profile
    if profile.profileType == 'SystemProfile'
      # Clear proxy settings, returning proxy control to Chromium.
      return proxySettings.clearAsync({}).then =>
        proxySettings.get {}, @_proxyChangeListener
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
        data: null
        mandatory: true
      setPacScript = @pacForProfile(profile).then (script) ->
        profileName = OmegaPac.PacGenerator.ascii(JSON.stringify(meta.name))
        profileName = profileName.replace(/\*/g, '\\u002a')
        profileName = profileName.replace(/\\/g, '\\u002f')
        prefix = "/*OmegaProfile*#{profileName}*#{meta.revision}*/"
        config['pacScript'].data = prefix + script
        return
    setPacScript ?= Promise.resolve()
    setPacScript.then(=>
      @_proxyAuth ?= new ProxyAuth(this)
      @_proxyAuth.listen()
      @_proxyAuth.setProxies(@_watchingProfiles)
      proxySettings.setAsync({value: config})
    ).then =>
      proxySettings.get {}, @_proxyChangeListener
      return

  _proxyScriptUrl: 'js/omega_webext_proxy_script.min.js'
  _proxyScriptDisabled: false
  applyProfileProxyScript: (profile, state) ->
    state = state ? {}
    state.currentProfileName = profile.name
    if profile.name == ''
      state.tempProfile = @_tempProfile
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
      @_initWebextProxyScript().then => @_proxyScriptStateChanged()
    # Proxy authentication is not covered in WebExtensions standard now.
    # MOZ: Mozilla has a bug tracked to implemented it in PAC return value.
    # https://bugzilla.mozilla.org/show_bug.cgi?id=1319641
    return Promise.resolve()

  _proxyScriptInitialized: false
  _proxyScriptState: {}
  _initWebextProxyScript: ->
    if not @_proxyScriptInitialized
      browser.proxy.onProxyError.addListener (err) =>
        if err and err.message.indexOf('Invalid Proxy Rule: DIRECT') >= 0
          # DIRECT cannot be parsed in Mozilla earlier due to a bug. Even though
          # it throws, it actually falls back to direct connection so it works.
          # https://bugzilla.mozilla.org/show_bug.cgi?id=1355198
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

  _quickSwitchInit: false
  _quickSwitchContextMenuCreated: false
  _quickSwitchCanEnable: false
  setQuickSwitch: (quickSwitch, canEnable) ->
    @_quickSwitchCanEnable = canEnable
    if not @_quickSwitchContextMenuCreated
      @_quickSwitchContextMenuCreated = true
      if quickSwitch
        chrome.contextMenus?.update('enableQuickSwitch', {checked: true})
      window.OmegaContextMenuQuickSwitchHandler = (info) =>
        changes = {}
        changes['-enableQuickSwitch'] = info.checked
        setOptions = @_setOptions(changes)
        if info.checked and not @_quickSwitchCanEnable
          setOptions.then ->
            chrome.tabs.create(
              url: chrome.extension.getURL('options.html#/ui')
            )

    if quickSwitch or not chrome.browserAction.setPopup?
      chrome.browserAction.setPopup?({popup: ''})
      if not @_quickSwitchInit
        @_quickSwitchInit = true
        chrome.browserAction.onClicked.addListener (tab) =>
          @clearBadge()
          if not @_options['-enableQuickSwitch']
            # If we reach here, then the browser does not support popup.
            # Let's open the popup page in a tab.
            chrome.tabs.create(url: 'popup/index.html')
            return
          profiles = @_options['-quickSwitchProfiles']
          index = profiles.indexOf(@_currentProfileName)
          index = (index + 1) % profiles.length
          @applyProfile(profiles[index]).then =>
            if @_options['-refreshOnProfileChange']
              url = tab.url
              return if not url
              return if url.substr(0, 6) == 'chrome'
              return if url.substr(0, 6) == 'about:'
              return if url.substr(0, 4) == 'moz-'
              chrome.tabs.reload(tab.id)
    else
      chrome.browserAction.setPopup({popup: 'popup/index.html'})
    Promise.resolve()

  setInspect: (settings) ->
    if @_inspect
      if settings.showMenu
        @_inspect.enable()
      else
        @_inspect.disable()
    return Promise.resolve()

  _requestMonitor: null
  _monitorWebRequests: false
  _tabRequestInfoPorts: null
  setMonitorWebRequests: (enabled) ->
    @_monitorWebRequests = enabled
    if enabled and not @_requestMonitor?
      @_tabRequestInfoPorts = {}
      wildcardForReq = (req) -> OmegaPac.wildcardForUrl(req.url)
      @_requestMonitor = new WebRequestMonitor(wildcardForReq)
      @_requestMonitor.watchTabs (tabId, info) =>
        return unless @_monitorWebRequests
        if info.errorCount > 0
          info.badgeSet = true
          badge = {text: info.errorCount.toString(), color: '#f0ad4e'}
          chrome.browserAction.setBadgeText(text: badge.text, tabId: tabId)
          chrome.browserAction.setBadgeBackgroundColor(
            color: badge.color
            tabId: tabId
          )
        else if info.badgeSet
          info.badgeSet = false
          chrome.browserAction.setBadgeText(text: '', tabId: tabId)
        @_tabRequestInfoPorts[tabId]?.postMessage({
          errorCount: info.errorCount
          summary: info.summary
        })

      chrome.runtime.onConnect.addListener (rawPort) =>
        return unless rawPort.name == 'tabRequestInfo'
        return unless @_monitorWebRequests
        tabId = null
        port = new ChromePort(rawPort)
        port.onMessage.addListener (msg) =>
          tabId = msg.tabId
          @_tabRequestInfoPorts[tabId] = port
          info = @_requestMonitor.tabInfo[tabId]
          if info
            port.postMessage({
              errorCount: info.errorCount
              summary: info.summary
            })
        port.onDisconnect.addListener =>
          delete @_tabRequestInfoPorts[tabId] if tabId?

  _alarms: null
  schedule: (name, periodInMinutes, callback) ->
    name = 'omega.' + name
    if not _alarms?
      @_alarms = {}
      chrome.alarms.onAlarm.addListener (alarm) =>
        @_alarms[alarm.name]?()
    if periodInMinutes < 0
      delete @_alarms[name]
      chrome.alarms.clear(name)
    else
      @_alarms[name] = callback
      chrome.alarms.create(name, {
        periodInMinutes: periodInMinutes
      })
    Promise.resolve()

  printFixedProfile: (profile) ->
    return unless profile.profileType == 'FixedProfile'
    result = ''
    for scheme in OmegaPac.Profiles.schemes when profile[scheme.prop]
      pacResult = OmegaPac.Profiles.pacResult(profile[scheme.prop])
      if scheme.scheme
        result += "#{scheme.scheme}: #{pacResult}\n"
      else
        result += "#{pacResult}\n"
    result ||= chrome.i18n.getMessage(
      'browserAction_profileDetails_DirectProfile')
    return result

  printProfile: (profile) ->
    type = profile.profileType
    if type.indexOf('RuleListProfile') >= 0
      type = 'RuleListProfile'

    if type == 'FixedProfile'
      @printFixedProfile(profile)
    else if type == 'PacProfile' and profile.pacUrl
      profile.pacUrl
    else
      chrome.i18n.getMessage('browserAction_profileDetails_' + type) || null

  upgrade: (options, changes) ->
    super(options).catch (err) =>
      return Promise.reject err if options?['schemaVersion']
      getOldOptions = if @switchySharp
        @switchySharp.getOptions().timeout(1000)
      else
        Promise.reject()

      getOldOptions = getOldOptions.catch ->
        if options?['config']
          Promise.resolve options
        else if localStorage['config']
          Promise.resolve localStorage
        else
          Promise.reject new OmegaTarget.Options.NoOptionsError()

      getOldOptions.then (oldOptions) =>
        i18n = {
          upgrade_profile_auto: chrome.i18n.getMessage('upgrade_profile_auto')
        }
        try
          # Upgrade from SwitchySharp.
          upgraded = require('./upgrade')(oldOptions, i18n)
        catch ex
          @log.error(ex)
          return Promise.reject ex
        if localStorage['config']
          Object.getPrototypeOf(localStorage).clear.call(localStorage)
        @_state.set({'firstRun': 'upgrade'})
        return this && super(upgraded, upgraded)

  onFirstRun: (reason) ->
    chrome.tabs.create url: chrome.extension.getURL('options.html')

  getPageInfo: ({tabId, url}) ->
    errorCount = @_requestMonitor?.tabInfo[tabId]?.errorCount
    result = if errorCount then {errorCount: errorCount} else null
    getBadge = new Promise (resolve, reject) ->
      if not chrome.browserAction.getBadgeText?
        resolve('')
        return
      chrome.browserAction.getBadgeText {tabId: tabId}, (result) ->
        resolve(result)

    getInspectUrl = @_state.get({inspectUrl: ''})
    Promise.join getBadge, getInspectUrl, (badge, {inspectUrl}) =>
      if badge == '#' and inspectUrl
        url = inspectUrl
      else
        @clearBadge()
      return result if not url
      if url.substr(0, 6) == 'chrome'
        errorPagePrefix = 'chrome://errorpage/'
        if url.substr(0, errorPagePrefix.length) == errorPagePrefix
          url = querystring.parse(url.substr(url.indexOf('?') + 1)).lasturl
          return result if not url
        else
          return result
      return result if url.substr(0, 6) == 'about:'
      return result if url.substr(0, 4) == 'moz-'
      domain = OmegaPac.getBaseDomain(Url.parse(url).hostname)

      return {
        url: url
        domain: domain
        tempRuleProfileName: @queryTempRule(domain)
        errorCount: errorCount
      }

module.exports = ChromeOptions

