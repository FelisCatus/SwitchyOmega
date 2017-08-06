module.exports =
  options:
    pretty: true
  web:
    files: [
      {
        expand: true
        dest: 'build/'
        cwd: 'src/'
        ext: '.html'
        src: '*.jade'
      }
      {
        expand: true
        dest: 'build/partials/'
        cwd: 'src/partials'
        ext: '.html'
        src: ['*.jade']
      }
    ]
