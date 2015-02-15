module.exports =
  default: [
    'coffeelint'
    'browserify'
    'coffee'
    'copy'
    'po2crx'
  ]
  test: ['mochaTest']
  release: ['default', 'compress']
