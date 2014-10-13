module.exports =
  grunt:
    options:
      reload: true
    files:
      'grunt/*'
    tasks: ['coffeelint:tasks', 'default']
  copy_web:
    files: ['node_modules/omega-web/build/**/*']
    tasks: ['copy:web']
  copy_i18n:
    files: ['../omega-i18n/**/*']
    tasks: ['copy:i18n', 'copy:i18n_zh']
  copy_target:
    files: ['node_modules/omega-target/omega_target.min.js']
    tasks: ['copy:target']
  copy_overlay:
    files: ['overlay/**/*']
    tasks: ['copy:overlay']
  src:
    files: ['src/**/*.coffee']
    tasks: ['coffeelint:src', 'browserify', 'copy:target_self']
  coffee:
    files: ['src/**/*.coffee', '*.coffee']
    tasks: ['coffeelint:src', 'coffee', 'copy:target_self']
