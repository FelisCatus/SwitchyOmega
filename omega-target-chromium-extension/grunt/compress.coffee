module.exports =
  options:
    archive: './release.zip'
    mode: 'zip'
  build:
    files: [
      {
        cwd: 'build'
        src: ['**', '!manifest.json']
        expand: true
        filter: 'isFile'
      }
      {
        cwd: 'tmp/'
        src: 'manifest.json'
        expand: true
      }
    ]
