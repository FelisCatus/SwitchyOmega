window.UglifyJS_NoUnsafeEval = true
localStorage['log'] = ''
localStorage['logLastError'] = ''

window.OmegaContextMenuQuickSwitchHandler = -> null

if chrome.contextMenus?
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
    onclick: OmegaDebug.reportIssue
  })

  chrome.contextMenus.create({
    title: chrome.i18n.getMessage('popup_errorLog')
    contexts: ["browser_action"]
    onclick: OmegaDebug.downloadLog
  })
