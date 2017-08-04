OmegaTarget = require('omega-target')
OmegaPac = OmegaTarget.OmegaPac
Promise = OmegaTarget.Promise
ChromePort = require('./chrome_port')

module.exports = class ExternalApi
  constructor: (options) ->
    @options = options
  knownExts:
    'padekgcemlokbadohgkifijomclgjgif': 32
  disabled: false
  listen: ->
    return unless chrome.runtime.onConnectExternal
    chrome.runtime.onConnectExternal.addListener (rawPort) =>
      port = new ChromePort(rawPort)
      port.onMessage.addListener (msg) => @onMessage(msg, port)
      port.onDisconnect.addListener @reenable.bind(this)

  _previousProfileName: null

  reenable: ->
    return unless @disabled

    @options.setProxyNotControllable(null)
    chrome.browserAction.setPopup?({popup: 'popup/index.html'})
    @options.reloadQuickSwitch()
    @disabled = false
    @options.clearBadge()
    @options.applyProfile(@_previousProfileName)

  checkPerm: (port, level) ->
    perm = @knownExts[port.sender.id] || 0
    if perm < level
      port.postMessage({action: 'error', error: 'permission'})
      false
    else
      true

  onMessage: (msg, port) ->
    @options.log.log("#{port.sender.id} -> #{msg.action}", msg)
    switch msg.action
      when 'disable'
        return unless @checkPerm(port, 16)
        return if @disabled
        @disabled = true
        @_previousProfileName = @options.currentProfile()?.name || 'system'
        @options.applyProfile('system').then =>
          reason = 'disabled'
          if @knownExts[port.sender.id] >= 32
            reason = 'upgrade'
          @options.setProxyNotControllable reason, {text: 'X', color: '#5ab432'}
        chrome.browserAction.setPopup?({popup: 'popup/index.html'})
        port.postMessage({action: 'state', state: 'disabled'})
      when 'enable'
        @reenable()
        port.postMessage({action: 'state', state: 'enabled'})
      when 'getOptions'
        return unless @checkPerm(port, 8)
        port.postMessage({action: 'options', options: @options.getAll()})
      else
        port.postMessage(
          action: 'error'
          error: 'noSuchAction'
          action_name: msg.action
        )
