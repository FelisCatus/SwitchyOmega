window.UglifyJS_NoUnsafeEval = true
localStorage['log'] = ''
localStorage['logLastError'] = ''

window.OmegaContextMenuQuickSwitchHandler = -> null
# We don't need this API. However its presence indicates that Chrome >= 35
# which provides info.checked we need in contextMenu callback.
# https://developer.chrome.com/extensions/contextMenus
if chrome.i18n.getUILanguage?
  # We must create the menu item here before others to make it first in menu.
  chrome.contextMenus.create({
    id: 'enableQuickSwitch'
    title: chrome.i18n.getMessage('contextMenu_enableQuickSwitch')
    type: 'checkbox'
    checked: false
    contexts: ["browser_action"]
    onclick: (info) -> window.OmegaContextMenuQuickSwitchHandler(info)
  })

chrome.contextMenus.create({
  title: chrome.i18n.getMessage('popup_reportIssues')
  contexts: ["browser_action"]
  onclick: ->
    url = 'https://github.com/FelisCatus/SwitchyOmega/issues/new?title=&body='
    finalUrl = url
    try
      extensionVersion = chrome.runtime.getManifest().version
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
})

chrome.contextMenus.create({
  title: chrome.i18n.getMessage('popup_errorLog')
  contexts: ["browser_action"]
  onclick: ->
    blob = new Blob [localStorage['log']], {type: "text/plain;charset=utf-8"}
    saveAs(blob, "OmegaLog_#{Date.now()}.txt")
})
