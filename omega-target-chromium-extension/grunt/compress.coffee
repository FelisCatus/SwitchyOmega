module.exports =
  options:
    archive: './release.zip'
    mode: 'zip'
  build:
    cwd: 'build'
    src: ['**']
    expand: true
    filter: 'isFile'
