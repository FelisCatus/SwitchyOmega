OmegaTarget = require('omega-target')
Promise = OmegaTarget.Promise

chromeApiPromisifer = (originalMethod) ->
  return (args...) ->
    new Promise (resolve, reject) =>
      callback = (callbackArgs...) ->
        if chrome.runtime.lastError?
          error = new Error(chrome.runtime.lastError.message)
          error.original = chrome.runtime.lastError
          return reject(error)
        if callbackArgs.length <= 1
          resolve(callbackArgs[0])
        else
          resolve(callbackArgs)

      args.push(callback)
      originalMethod.apply(this, args)

module.exports = (obj) ->
  Promise.promisifyAll(Object.create(obj), {promisifier: chromeApiPromisifer})
