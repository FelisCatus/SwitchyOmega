### @module omega-target/storage ###
Promise = require 'bluebird'
Log = require './log'

class Storage
  ###*
  # Get the requested values by keys from the storage.
  # @param {(string|string[]|null|Object.<string,{}>)} keys The keys to retrive,
  # or null for all.
  # @returns {Promise<(Object.<string, {}>)>} A map from keys to values
  ###
  get: (keys) ->
    Log.method('Storage#get', this, arguments)
    if not keys?
      keys = ['a', 'b', 'c']
    map = {}
    if typeof keys == 'string'
      map[keys] = 42
    else if Array.isArray(keys)
      for key in keys
        map[key] = 42
    else if typeof keys == 'object'
      map = keys
    Promise.resolve(map)

  ###*
  # Set multiple values by keys in the storage.
  # @param {(string|Object.<string,{}>)} items A map from key to value to set.
  # @returns {Promise<(Object.<string, {}>)>} A map of key-value pairs just set.
  ###
  set: (items) ->
    Log.method('Storage#set', this, arguments)
    Promise.resolve(items)
  
  ###*
  # Remove items by keys from the storage.
  # @param {(string|string[]|null)} keys The keys to remove, or null for all.
  # @returns {Promise} A promise that fulfills on successful removal.
  ###
  remove: (keys) ->
    Log.method('Storage#remove', this, arguments)
    Promise.resolve()
  
  ###*
  # @callback watchCallback
  # @param {Object.<string, {}>} map A map of key-value pairs just changed.
  ###

  ###*
  # Watch for any changes to the storage.
  # @param {(string|string[]|null)} keys The keys to watch, or null for all.
  # @param {watchCallback} callback Called everytime something changes.
  # @returns {function} Calling the returned function will stop watching.
  ###
  watch: (keys, callback) ->
    Log.method('Storage#watch', this, arguments)
    return (-> null)

module.exports = Storage
