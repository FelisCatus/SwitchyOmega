class ChromeTabs
  _defaultAction: null
  _badgeTab: null

  constructor: (@actionForUrl) ->
    @_dirtyTabs = {}
    return

  ignoreError: ->
    chrome.runtime.lastError
    return

  watch: ->
    chrome.tabs.onUpdated.addListener @onUpdated.bind(this)
    chrome.tabs.onActivated.addListener (info) =>
      chrome.tabs.get info.tabId, (tab) =>
        return if chrome.runtime.lastError
        if @_dirtyTabs.hasOwnProperty(info.tabId)
          @onUpdated tab.id, {}, tab

  resetAll: (action) ->
    @_defaultAction = action
    chrome.tabs.query {}, (tabs) =>
      @_dirtyTabs = {}
      tabs.forEach (tab) =>
        @_dirtyTabs[tab.id] = tab.id
        @onUpdated tab.id, {}, tab if tab.active
    chrome.browserAction.setTitle({title: action.title})
    @setIcon(action.icon)

  onUpdated: (tabId, changeInfo, tab) ->
    if @_dirtyTabs.hasOwnProperty(tab.id)
      delete @_dirtyTabs[tab.id]
    else if not changeInfo.url?
      if changeInfo.status? and changeInfo.status != 'loading'
        return
    @processTab(tab, changeInfo)

  processTab: (tab, changeInfo) ->
    if @_badgeTab
      for own id of @_badgeTab
        try chrome.browserAction.setBadgeText(text: '', tabId: id)
        @_badgeTab = null
    if not tab.url? or tab.url.indexOf("chrome") == 0
      if @_defaultAction
        chrome.browserAction.setTitle({
          title: @_defaultAction.title
          tabId: tab.id
        })
        @clearIcon tab.id
      return
    @actionForUrl(tab.url).then (action) =>
      @setIcon(action.icon, tab.id)
      chrome.browserAction.setTitle(title: action.title, tabId: tab.id)

  setTabBadge: (tab, badge) ->
    @_badgeTab ?= {}
    @_badgeTab[tab.id] = true
    chrome.browserAction.setBadgeText(text: badge.text, tabId: tab.id)
    chrome.browserAction.setBadgeBackgroundColor(
      color: badge.color
      tabId: tab.id
    )

  setIcon: (icon, tabId) ->
    if tabId?
      chrome.browserAction.setIcon({
        imageData: icon
        tabId: tabId
      }, @ignoreError)
    else
      chrome.browserAction.setIcon({imageData: icon}, @ignoreError)

  clearIcon: (tabId) ->
    chrome.browserAction.setIcon({
      imageData: @_defaultAction.icon
      tabId: tabId
    }, @ignoreError)

module.exports = ChromeTabs
