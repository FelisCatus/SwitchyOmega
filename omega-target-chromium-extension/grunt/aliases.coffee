module.exports =
  default: [
    'coffeelint'
    'browserify'
    'coffee'
    'copy'
  ]
  test: ['mochaTest']
  release: ['default', 'compress']
