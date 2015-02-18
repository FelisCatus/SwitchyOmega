module.exports =
  Storage: require('./src/storage')
  Options: require('./src/options')
  ChromeTabs: require('./src/tabs')
  SwitchySharp: require('./src/switchysharp')
  ExternalApi: require('./src/external_api.coffee')
  WebRequestMonitor: require('./src/web_request_monitor')
  Inspect: require('./src/inspect')
  Url: require('url')

for name, value of require('omega-target')
  module.exports[name] ?= value
