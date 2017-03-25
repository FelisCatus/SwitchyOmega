window.OmegaDebug =
  getProjectVersion: ->
    chrome.runtime.getManifest().version
  getExtensionVersion: ->
    chrome.runtime.getManifest().version
  downloadLog: ->
    blob = new Blob [localStorage['log']], {type: "text/plain;charset=utf-8"}
    filename = "OmegaLog_#{Date.now()}.txt"

    if browser?.downloads?.download?
      url = URL.createObjectURL(blob)
      browser.downloads.download({url: url, filename: filename})
    else
      saveAs(blob, filename)
  resetOptions: ->
    localStorage.clear()
    # Prevent options loading from sync storage after reload.
    localStorage['omega.local.syncOptions'] = '"conflict"'
    chrome.storage.local.clear()
    chrome.runtime.reload()
  reportIssue: ->
    url = 'https://github.com/FelisCatus/SwitchyOmega/issues/new?title=&body='
    finalUrl = url
    try
      projectVersion = OmegaDebug.getProjectVersion()
      extensionVersion = OmegaDebug.getExtensionVersion()
      env =
        extensionVersion: extensionVersion
        projectVersion: extensionVersion
        userAgent: navigator.userAgent
      body = chrome.i18n.getMessage('popup_issueTemplate', [
        env.projectVersion, env.userAgent
      ])
      body ||= """
        \n\n
        <!-- Please write your comment ABOVE this line. -->
        SwitchyOmega #{env.projectVersion}
        #{env.userAgent}
      """
      finalUrl = url + encodeURIComponent(body)
      err = localStorage['logLastError']
      if err
        body += "\n```\n#{err}\n```"
        finalUrl = (url + encodeURIComponent(body)).substr(0, 2000)

    chrome.tabs.create(url: finalUrl)
