module.exports =
  Storage: require('./storage')
  Options: require('./options')
  ChromeTabs: require('./tabs')
  SwitchySharp: require('./switchysharp')
  ExternalApi: require('./external_api')
  WebRequestMonitor: require('./web_request_monitor')
  Inspect: require('./inspect')
  Url: require('url')

for name, value of require('omega-target')
  module.exports[name] ?= value
