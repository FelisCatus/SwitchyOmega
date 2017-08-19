OmegaTargetCurrent = Object.create(OmegaTargetChromium)
Promise = OmegaTargetCurrent.Promise
Promise.longStackTraces()

OmegaTargetCurrent.Log = Object.create(OmegaTargetCurrent.Log)
Log = OmegaTargetCurrent.Log
Log.log = (args...) ->
  console.log(args...)
  localStorage['log'] += args.map(Log.str.bind(Log)).join(' ') + '\n'
Log.error = (args...) ->
  console.error(args...)
  content = args.map(Log.str.bind(Log)).join(' ')
  localStorage['logLastError'] = content
  localStorage['log'] += 'ERROR: ' + content + '\n'

unhandledPromises = []
unhandledPromisesId = []
unhandledPromisesNextId = 1
Promise.onPossiblyUnhandledRejection (reason, promise) ->
  Log.error("[#{unhandledPromisesNextId}] Unhandled rejection:\n", reason)
  unhandledPromises.push(promise)
  unhandledPromisesId.push(unhandledPromisesNextId)
  unhandledPromisesNextId++
Promise.onUnhandledRejectionHandled (promise) ->
  index = unhandledPromises.indexOf(promise)
  Log.log("[#{unhandledPromisesId[index]}] Rejection handled!", promise)
  unhandledPromises.splice(index, 1)
  unhandledPromisesId.splice(index, 1)

iconCache = {}
drawContext = null
drawError = null
drawIcon = (resultColor, profileColor) ->
  cacheKey = "omega+#{resultColor ? ''}+#{profileColor}"
  icon = iconCache[cacheKey]
  return icon if icon
  try
    if not drawContext?
      drawContext = document.getElementById('canvas-icon').getContext('2d')

    icon = {}
    for size in [16, 19, 24, 32, 38]
      drawContext.scale(size, size)
      drawContext.clearRect(0, 0, 1, 1)
      if resultColor?
        drawOmega drawContext, resultColor, profileColor
      else
        drawOmega drawContext, profileColor
      drawContext.setTransform(1, 0, 0, 1, 0, 0)
      icon[size] = drawContext.getImageData(0, 0, size, size)
  catch e
    if not drawError?
      drawError = e
      Log.error(e)
    icon = null

  return iconCache[cacheKey] = icon

charCodeUnderscore = '_'.charCodeAt(0)
isHidden = (name) -> (name.charCodeAt(0) == charCodeUnderscore and
  name.charCodeAt(1) == charCodeUnderscore)

dispName = (name) -> chrome.i18n.getMessage('profile_' + name) || name

actionForUrl = (url) ->
  options.ready.then(->
    request = OmegaPac.Conditions.requestFromUrl(url)
    options.matchProfile(request)
  ).then(({profile, results}) ->
    current = options.currentProfile()
    currentName = dispName(current.name)
    if current.profileType == 'VirtualProfile'
      realCurrentName = current.defaultProfileName
      currentName += " [#{dispName(realCurrentName)}]"
      current = options.profile(realCurrentName)
    details = ''
    direct = false
    attached = false
    condition2Str = (condition) ->
      condition.pattern || OmegaPac.Conditions.str(condition)
    for result in results
      if Array.isArray(result)
        if not result[1]?
          attached = false
          name = result[0]
          if name[0] == '+'
            name = name.substr(1)
          if isHidden(name)
            attached = true
          else if name != realCurrentName
            details += chrome.i18n.getMessage 'browserAction_defaultRuleDetails'
            details += " => #{dispName(name)}\n"
        else if result[1].length == 0
          if result[0] == 'DIRECT'
            details += chrome.i18n.getMessage('browserAction_directResult')
            details += '\n'
            direct = true
          else
            details += "#{result[0]}\n"
        else if typeof result[1] == 'string'
          details += "#{result[1]} => #{result[0]}\n"
        else
          condition = condition2Str(result[1].condition ? result[1])
          details += "#{condition} => "
          if result[0] == 'DIRECT'
            details += chrome.i18n.getMessage('browserAction_directResult')
            details += '\n'
            direct = true
          else
            details += "#{result[0]}\n"
      else if result.profileName
        if result.isTempRule
          details += chrome.i18n.getMessage('browserAction_tempRulePrefix')
        else if attached
          details += chrome.i18n.getMessage('browserAction_attachedPrefix')
          attached = false
        condition = result.source ? condition2Str(result.condition)
        details += "#{condition} => #{dispName(result.profileName)}\n"

    if not details
      details = options.printProfile(current)

    resultColor = profile.color
    profileColor = current.color

    icon = null
    if direct
      resultColor = options.profile('direct').color
      profileColor = profile.color
    else if profile.name == current.name and options.isCurrentProfileStatic()
      resultColor = profileColor = profile.color
      icon = drawIcon(profile.color)
    else
      resultColor = profile.color
      profileColor = current.color

    icon ?= drawIcon(resultColor, profileColor)

    shortTitle = 'Omega: ' + currentName # TODO: I18n.
    if profile.name != currentName
      shortTitle += ' => ' + profile.name # TODO: I18n.

    return {
      title: chrome.i18n.getMessage('browserAction_titleWithResult', [
        currentName
        dispName(profile.name)
        details
      ])

      shortTitle: shortTitle
      icon: icon
      resultColor: resultColor
      profileColor: profileColor
    }
  ).catch -> return null


storage = new OmegaTargetCurrent.Storage('local')
state = new OmegaTargetCurrent.BrowserStorage(localStorage, 'omega.local.')

if chrome?.storage?.sync or browser?.storage?.sync
  syncStorage = new OmegaTargetCurrent.Storage('sync')
  sync = new OmegaTargetCurrent.OptionsSync(syncStorage)
  if localStorage['omega.local.syncOptions'] != '"sync"'
    sync.enabled = false
  sync.transformValue = OmegaTargetCurrent.Options.transformValueForSync

options = new OmegaTargetCurrent.Options(null, storage, state, Log, sync)
options.externalApi = new OmegaTargetCurrent.ExternalApi(options)
options.externalApi.listen()

if chrome.runtime.id != OmegaTargetCurrent.SwitchySharp.extId
  options.switchySharp = new OmegaTargetCurrent.SwitchySharp()
  options.switchySharp.monitor()

tabs = new OmegaTargetCurrent.ChromeTabs(actionForUrl)
tabs.watch()

options._inspect = new OmegaTargetCurrent.Inspect (url, tab) ->
  if url == tab.url
    options.clearBadge()
    tabs.processTab(tab)
    state.remove('inspectUrl')
    return

  state.set({inspectUrl: url})

  actionForUrl(url).then (action) ->
    return if not action
    parsedUrl = OmegaTargetCurrent.Url.parse(url)
    if parsedUrl.hostname == OmegaTargetCurrent.Url.parse(tab.url).hostname
      urlDisp = parsedUrl.path
    else
      urlDisp = parsedUrl.hostname

    title = chrome.i18n.getMessage('browserAction_titleInspect', urlDisp) + '\n'
    title += action.title
    chrome.browserAction.setTitle(title: title, tabId: tab.id)
    tabs.setTabBadge(tab, {
      text: '#'
      color: action.resultColor
    })

options.setProxyNotControllable(null)
timeout = null

options.watchProxyChange (details) ->
  return if options.externalApi.disabled
  return unless details
  notControllableBefore = options.proxyNotControllable()
  internal = false
  noRevert = false
  switch details['levelOfControl']
    when "controlled_by_other_extensions", "not_controllable"
      reason =
        if details['levelOfControl'] == 'not_controllable'
          'policy'
        else
          'app'
      options.setProxyNotControllable(reason)
      noRevert = true
    else
      options.setProxyNotControllable(null)

  if details['levelOfControl'] == 'controlled_by_this_extension'
    internal = true
    return if not notControllableBefore
  Log.log('external proxy: ', details)

  # Chromium will send chrome.proxy.settings.onChange on extension unload,
  # just after the current extension has lost control of the proxy settings.
  # This is just annoying, and may change the currentProfileName state
  # suprisingly.
  # To workaround this issue, wait for some time before setting the proxy.
  # However this will cause some delay before the settings are processed.
  clearTimeout(timeout) if timeout?
  parsed = null
  timeout = setTimeout (->
    options.setExternalProfile(parsed, {noRevert: noRevert, internal: internal})
  ), 500

  parsed = options.parseExternalProfile(details)
  return

external = false
options.currentProfileChanged = (reason) ->
  iconCache = {}

  if reason == 'external'
    external = true
  else if reason != 'clearBadge'
    external = false

  current = options.currentProfile()
  currentName = ''
  if current
    currentName = dispName(current.name)
    if current.profileType == 'VirtualProfile'
      realCurrentName = current.defaultProfileName
      currentName += " [#{dispName(realCurrentName)}]"
      current = options.profile(realCurrentName)

  details = options.printProfile(current)
  if currentName
    title = chrome.i18n.getMessage('browserAction_titleWithResult', [
      currentName, '', details])
    shortTitle = 'Omega: ' + currentName # TODO: I18n.
  else
    title = details
    shortTitle = 'Omega: ' + details # TODO: I18n.

  if external and current.profileType != 'SystemProfile'
    message = chrome.i18n.getMessage('browserAction_titleExternalProxy')
    title = message + '\n' + title
    shortTitle = 'Omega-Extern: ' + details # TODO: I18n.
    options.setBadge()

  if not current.name or not OmegaPac.Profiles.isInclusive(current)
    icon = drawIcon(current.color)
  else
    icon = drawIcon(options.profile('direct').color, current.color)

  tabs.resetAll(
    icon: icon
    title: title
    shortTitle: shortTitle
  )

encodeError = (obj) ->
  if obj instanceof Error
    {
      _error: 'error'
      name: obj.name
      message: obj.message
      stack: obj.stack
      original: obj
    }
  else
    obj

refreshActivePageIfEnabled = ->
  return if localStorage['omega.local.refreshOnProfileChange'] == 'false'
  chrome.tabs.query {active: true, lastFocusedWindow: true}, (tabs) ->
    url = tabs[0].url
    return if not url
    return if url.substr(0, 6) == 'chrome'
    return if url.substr(0, 6) == 'about:'
    return if url.substr(0, 4) == 'moz-'
    chrome.tabs.reload(tabs[0].id, {bypassCache: true})

chrome.runtime.onMessage.addListener (request, sender, respond) ->
  return unless request and request.method
  options.ready.then ->
    target = options
    method = target[request.method]
    if typeof method != 'function'
      Log.error("No such method #{request.method}!")
      respond(
        error:
          reason: 'noSuchMethod'
      )
      return

    promise = Promise.resolve().then -> method.apply(target, request.args)
    if request.refreshActivePage
      promise.then refreshActivePageIfEnabled
    return if request.noReply

    promise.then (result) ->
      if request.method == 'updateProfile'
        for own key, value of result
          result[key] = encodeError(value)
      respond(result: result)

    promise.catch (error) ->
      Log.error(request.method + ' ==>', error)
      respond(error: encodeError(error))

  # Wait for my response!
  return true unless request.noReply
