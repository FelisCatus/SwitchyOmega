module.exports = exports =
  regExpMetaChars: do ->
    chars = '''\\[\^$.|?*+(){}/'''
    set = {}
    for i in [0...chars.length]
      set[chars.charCodeAt(i)] = true
    set
  escapeSlash: (pattern) ->
    charCodeSlash = 47 # /
    charCodeBackSlash = 92 # \
    escaped = false
    start = 0
    result = ''
    for i in [0...pattern.length]
      code = pattern.charCodeAt(i)
      if code == charCodeSlash and not escaped
        result += pattern.substring start, i
        result += '\\'
        start = i
      escaped = (code == charCodeBackSlash and not escaped)
    result += pattern.substr start
  shExp2RegExp: (pattern, options) ->
    trimAsterisk = options?.trimAsterisk || false
    start = 0
    end = pattern.length
    charCodeAsterisk = 42 # '*'
    charCodeQuestion = 63 # '?'
    if trimAsterisk
      while start < end && pattern.charCodeAt(start) == charCodeAsterisk
        start++
      while start < end && pattern.charCodeAt(end - 1) == charCodeAsterisk
        end--
      if end - start == 1 && pattern.charCodeAt(start) == charCodeAsterisk
        return ''
    regex = ''
    if start == 0
      regex += '^'
    for i in [start...end]
      code = pattern.charCodeAt(i)
      switch code
        when charCodeAsterisk then regex += '.*'
        when charCodeQuestion then regex += '.'
        else
          if exports.regExpMetaChars[code] >= 0
            regex += '\\'
          regex += pattern[i]

    if end == pattern.length
      regex += '$'

    return regex
