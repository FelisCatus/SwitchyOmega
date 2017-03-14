module.exports =
  grunt:
    options:
      reload: true
    files:
      'grunt/*'
    tasks: ['coffeelint:tasks', 'default']
  copy_pac:
    files:
      'node_modules/omega-pac/omega_pac.min.js'
    tasks: 'copy:pac'
  copy_lib:
    files:
      'lib/**/*'
    tasks: 'copy:lib'
  copy_img:
    files:
      'img/**/*'
    tasks: 'copy:img'
  copy_popup:
    files:
      'src/popup/**/*'
    tasks: 'copy:popup'
  jade:
    files: ['src/**/*.jade']
    tasks: 'jade'
  less:
    files:
      'src/less/**/*.less'
    tasks: ['less', 'autoprefixer']
  coffeelint:
    files: 'src/**/*.coffee'
    tasks: ['coffeelint']
  coffee:
    files: [
      'src/coffee/**/*.coffee'
      'src/omega/**/*.coffee'
    ]
    tasks: ['coffee']
