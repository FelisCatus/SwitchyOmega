module.exports =
  options:
    arrow_spacing: level: 'error'
    colon_assignment_spacing:
      level: 'error'
      spacing:
        left: 0
        right: 1
    missing_fat_arrows: level: 'warn'
    no_empty_functions: level: 'error'
    no_empty_param_list: level: 'error'
    no_interpolation_in_single_quotes: level: 'error'
    no_stand_alone_at: level: 'error'
    space_operators: level: 'error'
    # https://github.com/clutchski/coffeelint/issues/525
    indentation: level: 'ignore'

  gruntfile: ['Gruntfile.coffee']
  tasks: ['grunt/**/*.coffee']
  src: ['*.coffee', 'src/**/*.coffee', 'test/**/*.coffee']
