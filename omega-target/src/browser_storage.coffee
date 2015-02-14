Storage = require('./storage')
Promise = require('bluebird')

class BrowserStorage extends Storage
  constructor: (@storage, @prefix = '') ->
    @proto = Object.getPrototypeOf(@storage)

  get: (keys) ->
    map = {}
    if typeof keys == 'string'
      map[keys] = undefined
    else if Array.isArray(keys)
      for key in keys
        map[key] = undefined
    else if typeof keys == 'object'
      map = keys
    for own key of map
      try
        value = JSON.parse(@proto.getItem.call(@storage, @prefix + key))
      map[key] = value if value?
      if typeof map[key] == 'undefined'
        delete map[key]
    Promise.resolve map

  set: (items) ->
    for own key, value of items
      value = JSON.stringify(value)
      @proto.setItem.call(@storage, @prefix + key, value)
    Promise.resolve items

  remove: (keys) ->
    if not keys?
      if not @prefix
        @proto.clear.call(@storage)
      else
        index = 0
        while true
          key = @proto.key.call(index)
          break if key == null
          if @key.substr(0, @prefix.length) == @prefix
            @proto.removeItem.call(@storage, @prefix + keys)
          else
            index++
    if typeof keys == 'string'
      @proto.removeItem.call(@storage, @prefix + keys)
    for key in keys
      @proto.removeItem.call(@storage, @prefix + key)

    Promise.resolve()

module.exports = BrowserStorage
