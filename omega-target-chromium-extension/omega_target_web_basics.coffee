window.OmegaTargetWebBasics =
  getLog: (callback) ->
    callback(localStorage['log'] || '')
  getEnv: (callback) ->
    extensionVersion = chrome.runtime.getManifest().version
    callback({
      extensionVersion: extensionVersion
      projectVersion: extensionVersion
      userAgent: navigator.userAgent
    })
  getMessage: chrome.i18n.getMessage.bind(chrome.i18n)
