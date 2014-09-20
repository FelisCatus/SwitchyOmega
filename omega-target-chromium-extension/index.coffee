module.exports =
  Storage: require('./src/storage')
  Options: require('./src/options')
  ChromeTabs: require('./src/tabs.coffee')
  Url: require('url')

for name, value of require('omega-target')
  module.exports[name] ?= value
