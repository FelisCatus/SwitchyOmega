### @module omega-target/log ###
Log = require './log'

replacer = (key, value) ->
  switch key
    # Hide values for a few keys with privacy concerns.
    when "username", "password", "host", "port"
      return "<secret>"
    else
      value

# Log is used as singleton.
# coffeelint: disable=missing_fat_arrows
module.exports = Log =
  ###*
  # Pretty-print an object and return the result string.
  # @param {{}} obj The object to format
  # @returns {String} the formatted object in string
  ###
  str: (obj) ->
    # TODO(catus): This can be improved to print things more friendly.
    if typeof obj == 'object' and obj != null
      if obj.debugStr?
        if typeof obj.debugStr == 'function'
          obj.debugStr()
        else
          obj.debugStr
      else if obj instanceof Error
        obj.stack || obj.message
      else
        JSON.stringify(obj, replacer, 4)
    else if typeof obj == 'function'
      if obj.name
        "<f: #{obj.name}>"
      else
        obj.toString()
    else
      '' + obj

  ###*
  # Print something to the log.
  # @param {...{}} args The objects to log
  ###
  log: console.log.bind(console)

  ###*
  # Print something to the error log.
  # @param {...{}} args The objects to log
  ###
  error: console.error.bind(console)

  ###*
  # Log a function call with target and arguments
  # @param {string} name The name of the method
  # @param {Array} args The arguments to the method call
  ###
  func: (name, args) ->
    this.log(name, '(', [].slice.call(args), ')')

  ###*
  # Log a method call with target and arguments
  # @param {string} name The name of the method
  # @param {{}} self The target of the method call
  # @param {Array} args The arguments to the method call
  ###
  method: (name, self, args) ->
    this.log(this.str(self), '<<', name, [].slice.call(args))

# coffeelint: enable=missing_fat_arrows
