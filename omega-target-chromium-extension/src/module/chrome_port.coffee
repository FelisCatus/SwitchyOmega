# A wrapper around type Port in Chromium Extension API.
# https://developer.chrome.com/extensions/runtime#type-Port
#
# Please wrap any Port object in this class BEFORE adding listeners. Adding
# listeners to events of raw Port objects should be avoided to minimize the risk
# of memory leaks. See the comments of the TrackedEvent class for more details.
module.exports = class ChromePort
  constructor: (@port) ->
    @name = @port.name
    @sender = @port.sender

    @disconnect = @port.disconnect.bind(@port)
    @postMessage = @port.postMessage.bind(@port)

    @onMessage = new TrackedEvent(@port.onMessage)
    @onDisconnect = new TrackedEvent(@port.onDisconnect)
    @onDisconnect.addListener @dispose.bind(this)

  dispose: ->
    @onMessage.dispose()
    @onDisconnect.dispose()

# A wrapper around chrome.Event.
# https://developer.chrome.com/extensions/events#type-Event
#
# ALL event listeners MUST be manually removed before disposing any Event or
# object containing Event, such as Port. Otherwise, a memory leak will happen.
# https://code.google.com/p/chromium/issues/detail?id=320723
#
# TrackedEvent helps to solve this problem by keeping track of all listeners
# installed and removes them when the #dispose method is called.
# Don't forget to call #dispose when this TrackedEvent is not needed any more.
class TrackedEvent
  constructor: (@event) ->
    @callbacks = []
    mes = ['hasListener', 'hasListeners', 'addRules', 'getRules', 'removeRules']
    for methodName in mes
      method = @event[methodName]
      if method?
        this[methodName] = method.bind(@event)

  addListener: (callback) ->
    @event.addListener(callback)
    @callbacks.push(callback)
    return this

  removeListener: (callback) ->
    @event.removeListener(callback)
    i = @callbacks.indexOf(callback)
    @callbacks.splice(i, 1) if i >= 0
    return this

  ###*
  # Removes all listeners added via this TrackedEvent instance.
  # Note: Won't remove listeners added via other TrackedEvent or raw Event.
  ###
  removeAllListeners: ->
    for callback in @callbacks
      @event.removeListener(callback)
    @callbacks = []
    return this
  
  ###*
  # Removes all listeners added via this TrackedEvent instance and prevent any
  # further listeners from being added. It is considered safe to nullify any
  # references to this instance and the underlying Event without causing leaks.
  # This should be the last method called in the lifetime of TrackedEvent.
  #
  # Throws if the underlying raw Event object still has listeners. This can
  # happen when listeners have been added via other TrackedEvents or raw Event.
  ###
  dispose: ->
    @removeAllListeners()
    if @event.hasListeners?()
      throw new Error("Underlying Event still has listeners!")
    @event = null
    @callbacks = null
