module.exports = (grunt) ->
  taskDesc = 'Convert gettext PO files to Chromium Extension messages format.'
  # coffeelint: disable=missing_fat_arrows
  grunt.registerMultiTask 'po2crx', taskDesc, ->
    for f in this.files
      result = {}
      for src in f.src
        json = require('po2json').parseFileSync(src)
        for own key, value of json when key
          message = value[1]
          refs = []
          matchCount = 0
          message = message.replace /\$(\d+:)?(\w+)\$/g, (_, order, ref) ->
            matchCount++
            if order
              order = parseInt(order)
            else
              order = matchCount
            ### TODO(catus): Shall we enable this warning?
            if matchCount > 1
              grunt.log.writeln("In this message: #{key}=#{message}")
              grunt.log.writeln(
                'Order not specified for two or more refs in same message.')
            ###
            refs[order] = ref
            return '$' + ref + '$'

          if not matchCount
            placeholders = undefined
          else
            placeholders = {}
            for i in [0...refs.length]
              placeholder = refs[i] ? ('_unused_' + i)
              placeholders[placeholder] = {content: '$' + i}
          if message == ' '
            message = ''
          result[key] =
            message: message
            placeholders: placeholders

      grunt.file.write(f.dest, JSON.stringify(result))
      grunt.log.writeln("File \"#{f.dest}\" created.")
      # coffeelint: enable=missing_fat_arrows
