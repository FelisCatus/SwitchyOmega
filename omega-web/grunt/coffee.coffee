module.exports =
  web:
    expand: true
    cwd: 'src/coffee'
    src: ['**/*.coffee']
    dest: 'build/js/'
    ext: '.js'
  web_omega:
    files:
      'build/js/omega.js': 'src/omega/**/*.coffee'
