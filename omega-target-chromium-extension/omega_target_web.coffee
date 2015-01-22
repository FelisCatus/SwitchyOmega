angular.module('omegaTarget', []).factory 'omegaTarget', ($q) ->
  decodeError = (obj) ->
    if obj._error == 'error'
      err = new Error(obj.message)
      err.name = obj.name
      err.stack = obj.stack
      err.original = obj.original
      err
    else
      obj
  callBackground = (method, args...) ->
    d = $q['defer']()
    chrome.runtime.sendMessage({
      method: method
      args: args
    }, (response) ->
      if chrome.runtime.lastError?
        d.reject(chrome.runtime.lastError)
        return
      if response.error
        d.reject(decodeError(response.error))
      else
        d.resolve(response.result)
    )
    return d.promise

  isChromeUrl = (url) -> url.substr(0, 6) == 'chrome'

  optionsChangeCallback = []
  prefix = 'omega.local.'
  urlParser = document.createElement('a')
  omegaTarget =
    options: null
    state: (name, value) ->
      if arguments.length == 1
        getValue = (key) -> try JSON.parse(localStorage[prefix + key])
        if Array.isArray(name)
          return $q.when(name.map(getValue))
        else
          value = getValue(name)
      else
        localStorage[prefix + name] = JSON.stringify(value)
      return $q.when(value)
    lastUrl: (url) ->
      name = 'web.last_url'
      if url
        omegaTarget.state(name, url)
        url
      else
        try JSON.parse(localStorage[prefix + name])
    addOptionsChangeCallback: (callback) ->
      optionsChangeCallback.push(callback)
    refresh: (args) ->
      return callBackground('getAll').then (opt) ->
        omegaTarget.options = opt
        for callback in optionsChangeCallback
          callback(omegaTarget.options)
        return args
    renameProfile: (fromName, toName) ->
      callBackground('renameProfile', fromName, toName).then omegaTarget.refresh
    replaceRef: (fromName, toName) ->
      callBackground('replaceRef', fromName, toName).then omegaTarget.refresh
    optionsPatch: (patch) ->
      callBackground('patch', patch).then omegaTarget.refresh
    resetOptions: (opt) ->
      callBackground('reset', opt).then omegaTarget.refresh
    updateProfile: (name) ->
      callBackground('updateProfile', name).then((results) ->
        for own key, value of results
          results[key] = decodeError(value)
        results
      ).then omegaTarget.refresh
    getMessage: chrome.i18n.getMessage.bind(chrome.i18n)
    openOptions: (hash) ->
      d = $q['defer']()
      options_url = chrome.extension.getURL('options.html')
      chrome.tabs.query url: options_url, (tabs) ->
        url = if hash
          urlParser.href = tabs[0]?.url || options_url
          urlParser.hash = hash
          urlParser.href
        else
          options_url
        if tabs.length > 0
          props = {active: true}
          if hash
            props.url = url
          chrome.tabs.update(tabs[0].id, props)
        else
          chrome.tabs.create({url: url})
        d.resolve()
      return d.promise
    applyProfile: (name) ->
      callBackground('applyProfile', name)
    addTempRule: (domain, profileName) ->
      callBackground('addTempRule', domain, profileName)
    addCondition: (condition, profileName) ->
      callBackground('addCondition', condition, profileName)
    addProfile: (profile) ->
      callBackground('addProfile', profile).then omegaTarget.refresh
    setDefaultProfile: (profileName, defaultProfileName) ->
      callBackground('setDefaultProfile', profileName, defaultProfileName)
    getActivePageInfo: ->
      clearBadge = true
      d = $q['defer']()
      chrome.tabs.query {active: true, lastFocusedWindow: true}, (tabs) ->
        if not tabs[0]?.url
          d.resolve(undefined)
          return
        getBadge = $q['defer']()
        chrome.browserAction.getBadgeText {tabId: tabs[0]?.id}, (result) ->
          getBadge.resolve(result)
        $q.all([getBadge.promise, omegaTarget.state('inspectUrl')
        ]).then ([badge, url]) ->
          if badge != '#' || not url
            d.resolve(tabs[0]?.url)
          else
            clearBadge = false
            d.resolve(url)
      return d.promise.then (url) ->
        # First, try to clear badges on opening the popup.
        callBackground('clearBadge') if clearBadge
        return null if not url or isChromeUrl(url)
        urlParser.href = url
        domain = urlParser.hostname
        callBackground('queryTempRule', domain).then (profileName) ->
          url: url
          domain: domain
          tempRuleProfileName: profileName
    refreshActivePage: ->
      d = $q['defer']()
      chrome.tabs.query {active: true, lastFocusedWindow: true}, (tabs) ->
        if tabs[0].url and not isChromeUrl(tabs[0].url)
          chrome.tabs.reload(tabs[0].id)
        d.resolve()
      return d.promise
    openManage: ->
      chrome.tabs.create url: 'chrome://extensions/?id=' + chrome.runtime.id
    setOptionsSync: (enabled, args) ->
      callBackground('setOptionsSync', enabled, args)

  return omegaTarget
