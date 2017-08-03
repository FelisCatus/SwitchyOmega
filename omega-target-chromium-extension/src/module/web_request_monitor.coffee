Heap = require('heap')
Url = require('url')

module.exports = class WebRequestMonitor
  constructor: (@getSummaryId) ->
    @_requests = {}
    @_recentRequests = new Heap((a, b) -> a._startTime - b._startTime)
    @_callbacks = []
    @_tabCallbacks = []
    @tabInfo = {}

  _callbacks: null
  watching: false
  timer: null
  watch: (callback) ->
    @_callbacks.push(callback)
    return if @watching
    if not chrome.webRequest
      console.log('Request monitor disabled! No webRequest permission.')
      return
    chrome.webRequest.onBeforeRequest.addListener(
      @_requestStart.bind(this)
      {urls: ['<all_urls>']}
    )
    chrome.webRequest.onHeadersReceived.addListener(
      @_requestHeadersReceived.bind(this)
      {urls: ['<all_urls>']}
    )
    chrome.webRequest.onBeforeRedirect.addListener(
      @_requestRedirected.bind(this)
      {urls: ['<all_urls>']}
    )
    chrome.webRequest.onCompleted.addListener(
      @_requestDone.bind(this)
      {urls: ['<all_urls>']}
    )
    chrome.webRequest.onErrorOccurred.addListener(
      @_requestError.bind(this)
      {urls: ['<all_urls>']}
    )
    @watching = true

  _requests: null
  _recentRequests: null

  _requestStart: (req) ->
    return if req.tabId < 0
    req._startTime = Date.now()
    @_requests[req.requestId] = req
    @_recentRequests.push(req)
    @timer ?= setInterval(@_tick.bind(this), 1000)
    for callback in @_callbacks
      callback('start', req)

  _tick: ->
    now = Date.now()
    while (req = @_recentRequests.peek())
      reqInfo = @_requests[req.requestId]
      if reqInfo and not reqInfo.noTimeout
        if now - req._startTime < 5000
          break
        else
          reqInfo.timeoutCalled = true
          for callback in @_callbacks
            callback('timeout', reqInfo)
      @_recentRequests.pop()

  _requestHeadersReceived: (req) ->
    reqInfo = @_requests[req.requestId]
    return unless reqInfo
    reqInfo.noTimeout = true
    if reqInfo.timeoutCalled
      for callback in @_callbacks
        callback('ongoing', req)

  _requestRedirected: (req) ->
    url = req.redirectUrl
    return unless url
    if url.indexOf('data:') == 0 || url.indexOf('about:') == 0
      @_requestDone(req)

  _requestError: (req) ->
    reqInfo = @_requests[req.requestId]
    delete @_requests[req.requestId]

    return if req.tabId < 0
    return if req.error == 'net::ERR_INCOMPLETE_CHUNKED_ENCODING'
    return if req.error.indexOf('BLOCKED') >= 0
    return if req.error.indexOf('net::ERR_FILE_') == 0
    return if req.url.indexOf('file:') == 0
    return if req.url.indexOf('chrome') == 0
    return if req.url.indexOf('about:') == 0
    return if req.url.indexOf('moz-') == 0
    # Some ad-blocking extensions may redirect requests to 127.0.0.1.
    return if req.url.indexOf('://127.0.0.1') > 0
    return unless reqInfo
    if req.error == 'net::ERR_ABORTED'
      if reqInfo.timeoutCalled and not reqInfo.noTimeout
        for callback in @_callbacks
          callback('timeoutAbort', req)
      return
    for callback in @_callbacks
      callback('error', req)

  _requestDone: (req) ->
    for callback in @_callbacks
      callback('done', req)
    delete @_requests[req.requestId]

  eventCategory:
    start: 'ongoing'
    ongoing: 'ongoing'
    timeout: 'error'
    error: 'error'
    timeoutAbort: 'error'
    done: 'done'

  tabsWatching: false
  _tabCallbacks: null

  watchTabs: (callback) ->
    @_tabCallbacks.push(callback)
    return if @tabsWatching
    @watch(@setTabRequestInfo.bind(this))
    @tabsWatching = true
    chrome.tabs.onCreated.addListener (tab) =>
      return unless tab.id
      @tabInfo[tab.id] = @_newTabInfo()
    chrome.tabs.onRemoved.addListener (tab) =>
      delete @tabInfo[tab.id]
    chrome.tabs.onReplaced?.addListener (added, removed) =>
      @tabInfo[added] ?= @_newTabInfo()
      delete @tabInfo[removed]
    chrome.tabs.onUpdated.addListener (tabId, changeInfo, tab) =>
      info = @tabInfo[tab.id] ?= @_newTabInfo()
      return unless info
      for callback in @_tabCallbacks
        callback(tab.id, info, null, 'updated')
    chrome.tabs.query {}, (tabs) =>
      for tab in tabs
        @tabInfo[tab.id] ?= @_newTabInfo()

  _newTabInfo: -> {
    requests: {}
    requestCount: 0
    requestStatus: {}

    ongoingCount: 0
    errorCount: 0
    doneCount: 0

    summary: {}
  }

  setTabRequestInfo: (status, req) ->
    info = @tabInfo[req.tabId]
    if info
      if status == 'start' and req.type == 'main_frame'
        if req.url.indexOf('chrome://errorpage/') != 0
          for own key, value of @_newTabInfo()
            info[key] = value
      return if info.requestCount > 1000
      info.requests[req.requestId] = req
      if (oldStatus = info.requestStatus[req.requestId])
        info[@eventCategory[oldStatus] + 'Count']--
      else
        return if status == 'timeoutAbort'
        info.requestCount++
      info.requestStatus[req.requestId] = status
      info[@eventCategory[status] + 'Count']++
      id = @getSummaryId?(req)
      if id?
        if @eventCategory[status] == 'error'
          if @eventCategory[oldStatus] != 'error'
            summaryItem = info.summary[id]
            if not summaryItem?
              summaryItem = info.summary[id] = {errorCount: 0}
            summaryItem.errorCount++
        else if @eventCategory[oldStatus] == 'error'
          summaryItem = info.summary[id]
          summaryItem.errorCount-- if summaryItem?
      for callback in @_tabCallbacks
        callback(req.tabId, info, req, status)
