module.exports =
  index:
    files:
      'index.js': 'index.coffee'
    options:
      transform: ['coffeeify']
      exclude: ['uglify-js', 'ip-address']
      browserifyOptions:
        extensions: '.coffee'
        builtins: []
        standalone: 'index.coffee'
        debug: true
  browser:
    files:
      'omega_pac.min.js': './index.coffee'
    options:
      alias: [
        './index.coffee:OmegaPac'
      ]
      transform: ['coffeeify']
      plugin:
        if process.env.BUILD == 'release'
          [['minifyify', {map: false}]]
        else
          []
      browserifyOptions:
        extensions: '.coffee'
        standalone: 'OmegaPac'
