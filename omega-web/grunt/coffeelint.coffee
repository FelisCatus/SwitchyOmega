module.exports =
  options:
    arrow_spacing: level: 'error'
    colon_assignment_spacing:
      level: 'error'
      spacing:
        left: 0
        right: 1
    line_endings: level: 'error'
    missing_fat_arrows: level: 'warn'
    newlines_after_classes: level: 'error'
    no_empty_functions: level: 'error'
    no_empty_param_list: level: 'error'
    no_interpolation_in_single_quotes: level: 'error'
    no_stand_alone_at: level: 'error'
    space_operators: level: 'error'

  gruntfile: ['Gruntfile.coffee']
  tasks: ['grunt/**/*.coffee']
  src: ['src/**/*.coffee']
