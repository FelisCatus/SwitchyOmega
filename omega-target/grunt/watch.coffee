module.exports =
  grunt:
    options:
      reload: true
    files:
      'grunt/*'
    tasks: ['coffeelint:tasks', 'default']
  src:
    files: ['src/**/*.coffee', 'test/**/*.coffee']
    tasks: ['default']
