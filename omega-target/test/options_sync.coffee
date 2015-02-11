chai = require 'chai'
should = chai.should()
sinon = require 'sinon'
chai.use require('sinon-chai')

describe 'OptionsSync', ->
  OptionsSync = require '../src/options_sync'
  Storage = require '../src/storage'
  Log = require '../src/log'
  Promise = require 'bluebird'

  before ->
    # Silence storage and sync logging.
    sinon.stub(Log, 'log')

  after ->
    Log.log.restore()

  # coffeelint: disable=missing_fat_arrows
  hookPostBasic = (func, hook) -> ->
    result = func.apply(this, arguments)
    hook.apply(this, arguments)
    return result
  # coffeelint: enable=missing_fat_arrows

  hookPost = (args...) ->
    if args.length == 2
      [func, hook] = args
      hostPostBasic(func, hook)
    else
      [obj, method, hook] = args
      obj[method] = hookPostBasic(obj[method], hook)

  describe '#merge', ->
    sync = new OptionsSync()
    it 'should choose the one with newer revision', ->
      newVal = {revision: '2'}
      oldVal = {revision: '1'}
      sync.merge('example', newVal, oldVal).should.equal(newVal)
    it 'should use oldVal when sync is disabled in newVal', ->
      newVal = {revision: '2', is: 'newVal', syncOptions: 'disabled'}
      oldVal = {revision: '1', is: 'oldVal'}
      sync.merge('example', newVal, oldVal).should.equal(oldVal)
    it 'should use oldVal when sync is disabled in oldVal', ->
      newVal = {revision: '2', is: 'newVal'}
      oldVal = {revision: '1', is: 'oldVal', syncOptions: 'disabled'}
      sync.merge('example', newVal, oldVal).should.equal(oldVal)
    it 'should favor oldVal when revisions are equal', ->
      newVal = {revision: '1', is: 'newVal'}
      oldVal = {revision: '1', is: 'oldVal'}
      sync.merge('example', newVal, oldVal).should.equal(oldVal)
    it 'should favor oldVal when newVal deeply equals oldVal', ->
      newVal = {they: 'are', the: 'same'}
      oldVal = {they: 'are', the: 'same'}
      sync.merge('example', newVal, oldVal).should.equal(oldVal)
    it 'should choose newVal when newVal is different', ->
      newVal = {they: 'are', not: 'equal'}
      oldVal = {they: 'are', not: 'identical'}
      sync.merge('example', newVal, oldVal).should.equal(newVal)

  describe '#requestPush', ->
    unlimited = new OptionsSync.TokenBucket()

    it 'should store pendingChanges', ->
      sync = new OptionsSync()
      sync.enabled = false
      sync.requestPush({a: 1})
      sync.pendingChanges().should.eql({a: 1})
    it 'should schedule storage write', (done) ->
      check = ->
        return if storage.set.callCount == 0 or storage.remove.callCount == 0
        storage.set.should.have.been.calledOnce.and.calledWith({b: 1})
        storage.remove.should.have.been.calledOnce.and.calledWith(['a'])
        done()

      storage = new Storage()
      storage.set({a: 1})
      hookPost storage, 'set', check
      hookPost storage, 'remove', check

      sinon.spy(storage, 'set')
      sinon.spy(storage, 'remove')

      sync = new OptionsSync(storage, unlimited)
      sync.debounce = 0
      sync.requestPush({a: undefined, b: 1})

    it 'should combine multiple write operations', (done) ->
      check = ->
        return if storage.set.callCount == 0 or storage.remove.callCount == 0
        storage.set.should.have.been.calledOnce.and.calledWith({c: 1, d: 1})
        storage.remove.should.have.been.calledOnce.and.calledWith(['a', 'b'])
        done()

      storage = new Storage()
      storage.set({a: 1, b: 1})
      hookPost storage, 'set', check
      hookPost storage, 'remove', check

      sinon.spy(storage, 'set')
      sinon.spy(storage, 'remove')

      sync = new OptionsSync(storage, unlimited)
      sync.debounce = 0
      sync.requestPush({a: undefined})
      sync.requestPush({b: 2})
      sync.requestPush({b: undefined})
      sync.requestPush({c: 1})
      sync.requestPush({d: 1})
      sync.requestPush({e: 1})
      sync.requestPush({e: undefined})

    it 'should disable syncing for the profiles if quota is exceeded', (done) ->
      options = {'+a': {is: 'a', oversized: true}, b: {is: 'b'}}

      storage = new Storage()
      storage.set = (changes) ->
        for key, value of changes
          if value.oversized
            err = new Storage.QuotaExceededError()
            err.perItem = true
            return Promise.reject(err)
        storage.set.should.have.been.calledTwice
        storage.set.should.have.been.calledWith(options)
        storage.set.should.have.been.calledWith({b: {is: 'b'}})
        options['+a'].syncOptions.should.equal('disabled')
        options['+a'].syncError.reason.should.equal('quotaPerItem')
        done()
        Promise.resolve()

      sinon.spy(storage, 'set')

      sync = new OptionsSync(storage, unlimited)
      sync.debounce = 0
      sync.requestPush(options)

  describe '#copyTo', ->
    it 'should fetch all items from remote storage', (done) ->
      remote = new Storage()
      remote.set({a: 1, b: 2, c: 3})

      storage = new Storage()
      hookPost storage, 'set', ->
        storage.set.should.have.been.calledOnce.and.calledWith(
          {a: 1, b: 2, c: 3}
        )
        done()

      sinon.spy(storage, 'set')

      sync = new OptionsSync(remote)
      sync.copyTo(storage)

    it 'should merge with local as base', (done) ->
      check = ->
        return if storage.set.callCount == 0 or storage.remove.callCount == 0
        storage.set.should.have.been.calledOnce.and.calledWith({b: 2, c: 3})
        storage.remove.should.have.been.calledOnce.and.calledWith(['d'])
        done()

      remote = new Storage()
      remote.set({a: 1, b: 2, c: 3, d: undefined})

      storage = new Storage()
      storage.set({a: 1, b: 0, d: 4})

      hookPost storage, 'set', check
      hookPost storage, 'remove', check

      sinon.spy(storage, 'set')
      sinon.spy(storage, 'remove')

      sync = new OptionsSync(remote)
      sync.copyTo(storage)

  describe '#watchAndPull', ->
    it 'should pull changes into local when remote changes', (done) ->
      check = ->
        return if storage.set.callCount == 0 or storage.remove.callCount == 0
        remote.watch.should.have.been.calledOnce
        storage.set.should.have.been.calledOnce.and.calledWith({b: 2, c: 3})
        storage.remove.should.have.been.calledOnce.and.calledWith(['d'])
        done()

      remote = new Storage()
      hookPost remote, 'watch', (_, callback) ->
        setTimeout (->
          callback({a: 1})
          callback({b: 2})
          callback({c: 3})
          callback({d: undefined})
        ), 10

      sinon.spy(remote, 'watch')

      storage = new Storage()
      storage.set({a: 1, b: 0, d: 4})

      hookPost storage, 'set', check
      hookPost storage, 'remove', check

      sinon.spy(storage, 'set')
      sinon.spy(storage, 'remove')

      sync = new OptionsSync(remote)
      sync.pullThrottle = 0
      sync.watchAndPull(storage)
