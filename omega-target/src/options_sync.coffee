### @module omega-target/options_sync ###
Promise = require 'bluebird'
Storage = require './storage'
Log = require './log'
{Revision} = require 'omega-pac'
jsondiffpatch = require 'jsondiffpatch'
TokenBucket = require('limiter').TokenBucket

class OptionsSync
  @TokenBucket: TokenBucket

  _timeout: null
  _bucket: null
  _waiting: false

  ###*
  # The debounce timeout (ms) for requestPush scheduling. See requestPush.
  # @type number
  ###
  debounce: 1000

  ###*
  # The throttling timeout (ms) for watchAndPull. See watchAndPull.
  # @type number
  ###
  pullThrottle: 1000

  ###*
  # The remote storage of syncing.
  # @type Storage
  ###
  storage: null

  constructor: (@storage, @_bucket) ->
    @_pending = {}
    @_bucket ?= new TokenBucket(10, 10, 'minute', null)
    @_bucket.clear ?= =>
      @_bucket.tryRemoveTokens(@_bucket.content)

  ###*
  # Transform storage values for syncing. The default implementation applies no
  # transformation, but the behavior can be altered by assigning to this field.
  # Note: Transformation is applied before merging.
  # @param {{}} value The value to transform
  # @param {{}} key The key of the item
  # @returns {{}} The transformed value
  ###
  transformValue: (v) -> v

  ###*
  # Merge newVal and oldVal of a given key. The default implementation choose
  # between newVal and oldVal based on the following rules:
  # 1. Choose oldVal if syncOptions is 'disabled' in either oldVal or newVal.
  # 2. Choose oldVal if it has a revision newer than or equal to that of newVal.
  # 3. Choose oldVal if it deeply equals newVal.
  # 4. Otherwise, choose newVal.
  #
  # @param {string} key The key of the item
  # @param {} newVal The new value
  # @param {} oldVal The old value
  # @returns {} The merged result
  ###
  merge: do ->
    diff = jsondiffpatch.create(
      objectHash: (obj) -> JSON.stringify(obj)
      textDiff: minLength: 1 / 0
    )
    return (key, newVal, oldVal) ->
      return oldVal if newVal == oldVal
      if oldVal?.syncOptions == 'disabled' or newVal?.syncOptions == 'disabled'
        return oldVal
      if oldVal?.revision? and newVal?.revision?
        result = Revision.compare(oldVal.revision, newVal.revision)
        return oldVal if result >= 0
      return oldVal unless diff.diff(oldVal, newVal)?
      return newVal

  ###*
  # Whether syncing is enabled or not. See requestPush for the effect.
  # @type boolean
  ###
  enabled: true

  ###*
  # Request pushing the changes to remote storage. The changes are cached first,
  # and then the actual write operations are scheduled if enabled is true.
  # The actual operation is delayed and debounced, combining continuous writes
  # in a short period into a single write operation.
  # @param {Object.<string, {}>} changes A map from keys to values.
  ###
  requestPush: (changes) ->
    clearTimeout(@_timeout) if @_timeout?
    for own key, value of changes
      if typeof value != 'undefined'
        value = @transformValue(value, key)
        continue if typeof value == 'undefined'
      @_pending[key] = value
    return unless @enabled
    @_timeout = setTimeout(@_doPush.bind(this), @debounce)

  ###*
  # Returning the pending changes not written to the remote storage.
  # @returns {Object.<string, {}>} The pending changes.
  ###
  pendingChanges: -> @_pending

  _doPush: ->
    @_timeout = null
    return if @_waiting
    @_waiting = true
    @_bucket.removeTokens 1, =>
      @storage.get(null).then((base) =>
        changes = @_pending
        @_pending = {}
        @_waiting = false
        Storage.operationsForChanges(changes, base: base, merge: @merge)
      ).then ({set, remove}) =>
        doSet =
          if Object.keys(set).length == 0
            Promise.resolve(0)
          else
            Log.log 'OptionsSync::set', set
            @storage.set(set).return(1)
        doSet.then((cost) =>
          set = {}
          if remove.length > 0
            if @_bucket.tryRemoveTokens(cost)
              Log.log 'OptionsSync::remove', remove
              return @storage.remove(remove)
            else
              return Promise.reject('bucket')
        ).catch (e) =>
          # Re-submit the changes for syncing, but with lower priority.
          for own key, value of set
            if not (key of @_pending)
              @_pending[key] = value
          for key in remove
            if not (key of @_pending)
              @_pending[key] = undefined

          if e == 'bucket'
            @_doPush()
          else if e instanceof Storage.RateLimitExceededError
            Log.log 'OptionsSync::rateLimitExceeded'
            # Try to clear the @_bucket to wait more time before retrying.
            @_bucket.clear()
            @requestPush({})
            return
          else if e instanceof Storage.QuotaExceededError
            # For now, we just disable syncing for all changed profiles.
            # TODO(catus): Remove the largest profile each time and retry.
            valuesAffected = 0
            for own key, value of set
              if key[0] == '+' and value.syncOptions != 'disabled'
                value.syncOptions = 'disabled'
                value.syncError = {reason: 'quotaPerItem'}
                valuesAffected++
            if valuesAffected > 0
              @requestPush({})
            else
              @_pending = {}
            return
          else
            Promise.reject(e)

  _logOperations: (text, operations) ->
    if Object.keys(operations.set).length
      Log.log(text + '::set', operations.set)
    if operations.remove.length
      Log.log(text + '::remove', operations.remove)

  ###*
  # Pull the remote storage for changes, and write them to local.
  # @param {Storage} local The local storage to be written to
  # @returns {function} Calling the returned function will stop watching.
  ###
  copyTo: (local) ->
    Promise.join local.get(null), @storage.get(null), (base, changes) =>
      for own key of base when not (key of changes)
        if key[0] == '+' and not base[key]?.syncOptions == 'disabled'
          changes[key] = undefined
      local.apply(
        changes: changes
        base: base
        merge: @merge
      ).then (operations) =>
        @_logOperations('OptionsSync::copyTo', operations)

  ###*
  # Watch the remote storage for changes, and write them to local.
  # The actual writing is throttled by pullThrottle with initial delay.
  # @param {Storage} local The local storage to be written to
  # @returns {function} Calling the returned function will stop watching.
  ###
  watchAndPull: (local) ->
    pullScheduled = null
    pull = {}
    doPull = =>
      local.get(null).then((base) =>
        changes = pull
        pull = {}
        pullScheduled = null
        Storage.operationsForChanges(changes, base: base, merge: @merge)
      ).then (operations) =>
        @_logOperations('OptionsSync::pull', operations)
        local.apply(operations)

    @storage.watch null, (changes) =>
      for own key, value of changes
        pull[key] = value
      return if pullScheduled?
      pullScheduled = setTimeout(doPull, @pullThrottle)

module.exports = OptionsSync
