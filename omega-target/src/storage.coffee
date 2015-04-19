### @module omega-target/storage ###
Promise = require 'bluebird'
Log = require './log'

class Storage
  ###*
  # Any operation that fails due to rate limiting should reject with an instance
  # of RateLimitExceededError, when implemented in derived classes of Storage.
  ###
  @RateLimitExceededError:
    class RateLimitExceededError extends Error
      constructor: -> super

  ###*
  # Any operation that fails due to storage quota should reject with an instance
  # of QuotaExceededError, when implemented in derived classes of Storage.
  ###
  @QuotaExceededError:
    class QuotaExceededError extends Error
      constructor: -> super

  ###*
  # If this storage is not available for some reason, all operations should
  # reject with an instance of StorageUnavailableError, when implemented in
  # derived classes of Storage.
  # This error is considered fatal and unrecoverable in the current environment.
  # Further access to this storage should be avoided until restart.
  ###
  @StorageUnavailableError:
    class StorageUnavailableError extends Error
      constructor: -> super

  ###*
  # A set of operations to be performed on a Storage.
  # @typedef WriteOperations
  # @type {object}
  # @property {Object.<string, {}>} set - A map from keys to new values of the
  # items to set
  # @property {{}[]} remove - An array of keys to remove
  ###

  ###*
  # Calculate the actual operations against storage that should be performed to
  # replay the changes on a storage.
  # @param {Object.<string, {}>} changes The changes to apply
  # @param {?{}} args Extra arguments
  # @param {Object.<string, {}>?} args.base The original items in the storage.
  # @param {function(key, newVal, oldVal)} args.merge A function that merges
  # the newVal and oldVal. oldVal is provided only if args.base is present.
  # Otherwise it will be equal to newVal (i.e. merge(key, newVal, newVal)).
  # @returns {WriteOperations} The operations that should be performed.
  ###
  @operationsForChanges: (changes, {base, merge} = {}) ->
    set = {}
    remove = []
    for key, newVal of changes
      oldVal = if base? then base[key] else newVal
      if merge
        newVal = merge(key, newVal, oldVal)
      continue if base? and newVal == oldVal
      if typeof newVal == 'undefined'
        if typeof oldVal != 'undefined' or not base?
          remove.push(key)
      else
        set[key] = newVal
    return {set: set, remove: remove}

  ###*
  # Get the requested values by keys from the storage.
  # @param {(string|string[]|null|Object.<string,{}>)} keys The keys to retrive,
  # or null for all.
  # @returns {Promise<(Object.<string, {}>)>} A map from keys to values
  ###
  get: (keys) ->
    Log.method('Storage#get', this, arguments)
    return Promise.resolve({}) unless @_items
    if not keys?
      keys = @_items
    map = {}
    if typeof keys == 'string'
      map[keys] = @_items[keys]
    else if Array.isArray(keys)
      for key in keys
        map[key] = @_items[key]
    else if typeof keys == 'object'
      for key, value of keys
        map[key] = @_items[key] ? value
    Promise.resolve(map)

  ###*
  # Set multiple values by keys in the storage.
  # @param {(string|Object.<string,{}>)} items A map from key to value to set.
  # @returns {Promise<(Object.<string, {}>)>} A map of key-value pairs just set.
  ###
  set: (items) ->
    Log.method('Storage#set', this, arguments)
    @_items ?= {}
    for key, value of items
      @_items[key] = value
    Promise.resolve(items)
  
  ###*
  # Remove items by keys from the storage.
  # @param {(string|string[]|null)} keys The keys to remove, or null for all.
  # @returns {Promise} A promise that fulfills on successful removal.
  ###
  remove: (keys) ->
    Log.method('Storage#remove', this, arguments)
    if @_items?
      if not keys?
        @_items = {}
      else if Array.isArray(keys)
        for key in keys
          delete @_items[key]
      else
        delete @_items[keys]
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
  
  ###*
  # Apply WriteOperations to the storage.
  # @param {WriteOperations|{changes: Object.<string,{}>}} operations The
  # operations to apply, or the changes to be applied. If changes is provided,
  # the operations are calculated by Storage.operationsForChanges, with extra
  # fields passed through as the second argument.
  # @returns {Promise} A promise that fulfills on operation success.
  ###
  apply: (operations) ->
    if 'changes' of operations
      operations = Storage.operationsForChanges(operations.changes, operations)
    @set(operations.set).then(=> @remove(operations.remove)).return(operations)

module.exports = Storage
