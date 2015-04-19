chromeApiPromisifyAll = require('./chrome_api')
OmegaTarget = require('omega-target')
Promise = OmegaTarget.Promise

class ChromeStorage extends OmegaTarget.Storage
  @parseStorageErrors: (err) ->
    if err?.message
      sustainedPerMinute = 'MAX_SUSTAINED_WRITE_OPERATIONS_PER_MINUTE'
      if err.message.indexOf('QUOTA_BYTES_PER_ITEM') >= 0
        err = new OmegaTarget.Storage.QuotaExceededError()
        err.perItem = true
      else if err.message.indexOf('QUOTA_BYTES') >= 0
        err = new OmegaTarget.Storage.QuotaExceededError()
      else if err.message.indexOf('MAX_ITEMS') >= 0
        err = new OmegaTarget.Storage.QuotaExceededError()
        err.maxItems = true
      else if err.message.indexOf('MAX_WRITE_OPERATIONS_') >= 0
        err = new OmegaTarget.Storage.RateLimitExceededError()
        if err.message.indexOf('MAX_WRITE_OPERATIONS_PER_HOUR') >= 0
          err.perHour = true
        else if err.message.indexOf('MAX_WRITE_OPERATIONS_PER_MINUTE') >= 0
          err.perMinute = true
      else if err.message.indexOf(sustainedPerMinute) >= 0
        err = new OmegaTarget.Storage.RateLimitExceededError()
        err.perMinute = true
        err.sustained = 10
      else if err.message.indexOf('is not available') >= 0
        # This could happen if the storage area is not available. For example,
        # some Chromium-based browsers disable access to the sync storage.
        err = new OmegaTarget.Storage.StorageUnavailableError()

    return Promise.reject(err)

  constructor: (storage, @areaName) ->
    @storage = chromeApiPromisifyAll(storage)

  get: (keys) ->
    keys ?= null
    @storage.getAsync(keys).catch(ChromeStorage.parseStorageErrors)

  set: (items) ->
    if Object.keys(items).length == 0
      return Promise.resolve({})
    @storage.setAsync(items).catch(ChromeStorage.parseStorageErrors)

  remove: (keys) ->
    if not keys?
      return @storage.clearAsync()
    if Array.isArray(keys) and keys.length == 0
      return Promise.resolve({})
    @storage.removeAsync(keys).catch(ChromeStorage.parseStorageErrors)

  watch: (keys, callback) ->
    ChromeStorage.watchers[@areaName] ?= {}
    area = ChromeStorage.watchers[@areaName]
    watcher = {keys: keys, callback: callback}
    id = Date.now().toString()
    while area[id]
      id = Date.now().toString()

    if Array.isArray(keys)
      keyMap = {}
      for key in keys
        keyMap[key] = true
      keys = keyMap
    area[id] = {keys: keys, callback: callback}
    if not ChromeStorage.onChangedListenerInstalled
      chrome.storage.onChanged.addListener(ChromeStorage.onChangedListener)
      ChromeStorage.onChangedListenerInstalled = true
    return -> delete area[id]

  @onChangedListener: (changes, areaName) ->
    map = null
    for _, watcher of ChromeStorage.watchers[areaName]
      match = watcher.keys == null
      if not match
        for own key of changes
          if watcher.keys[key]
            match = true
            break
      if match
        if not map?
          map = {}
          for own key, change of changes
            map[key] = change.newValue
        watcher.callback(map)

  @onChangedListenerInstalled: false
  @watchers: {}

module.exports = ChromeStorage
