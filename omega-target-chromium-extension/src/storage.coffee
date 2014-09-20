chromeApiPromisifyAll = require('./chrome_api')
OmegaTarget = require('omega-target')
Promise = OmegaTarget.Promise

class ChromeStorage extends OmegaTarget.Storage
  constructor: (storage, @areaName) ->
    @storage = chromeApiPromisifyAll(storage)

  get: (keys) ->
    keys ?= null
    @storage.getAsync(keys)

  set: (items) ->
    if Object.keys(items).length == 0
      return Promise.resolve({})
    @storage.setAsync(items)

  remove: (keys) ->
    if not keys?
      return @storage.clearAsync()
    if Array.isArray(keys) and keys.length == 0
      return Promise.resolve({})
    @storage.removeAsync(keys)

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
