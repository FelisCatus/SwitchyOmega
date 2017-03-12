module.exports =
  target_web:
    files:
      'build/js/omega_target_web.js': 'omega_target_web.coffee'
  background:
    files:
      'build/js/background.js': 'background.coffee'
  background_preload:
    files:
      'build/js/background_preload.js': 'background_preload.coffee'
  omega_debug:
    files:
      'build/js/omega_debug.js': 'omega_debug.coffee'
