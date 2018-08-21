U2 = require 'uglify-js'
IP = require 'ip-address'
Url = require 'url'
{shExp2RegExp, escapeSlash} = require './shexp_utils'
{AttachedCache} = require './utils'

module.exports = exports =
  requestFromUrl: (url) ->
    if typeof url == 'string'
      url = Url.parse url
    req =
      url: Url.format(url)
      host: url.hostname
      scheme: url.protocol.replace(':', '')

  urlWildcard2HostWildcard: (pattern) ->
    result = pattern.match ///
      ^\*:\/\/ # Begins with *://
      ((?:\w|[?*._\-])+) # The host part follows.
      \/\*$ # And ends with /*
    ///
    result?[1]
  tag: (condition) -> exports._condCache.tag(condition)
  analyze: (condition) -> exports._condCache.get condition, -> {
    analyzed: exports._handler(condition.conditionType).analyze.call(
      exports, condition)
  }
  match: (condition, request) ->
    cache = exports.analyze(condition)
    exports._handler(condition.conditionType).match.call(exports, condition,
      request, cache)
  compile: (condition) ->
    cache = exports.analyze(condition)
    return cache.compiled if cache.compiled
    handler = exports._handler(condition.conditionType)
    cache.compiled = handler.compile.call(exports, condition, cache)
  str: (condition, {abbr} = {abbr: -1}) ->
    handler = exports._handler(condition.conditionType)
    if handler.abbrs[0].length == 0
      endCode = condition.pattern.charCodeAt(condition.pattern.length - 1)
      if endCode != exports.colonCharCode and condition.pattern.indexOf(' ') < 0
        return condition.pattern
    str = handler.str
    typeStr =
      if typeof abbr == 'number'
        handler.abbrs[(handler.abbrs.length + abbr) % handler.abbrs.length]
      else
        condition.conditionType
    result = typeStr + ':'
    part = if str then str.call(exports, condition) else condition.pattern
    result += ' ' + part if part
    return result

  colonCharCode: ':'.charCodeAt(0)
  fromStr: (str) ->
    str = str.trim()
    i = str.indexOf(' ')
    i = str.length if i < 0
    if str.charCodeAt(i - 1) == exports.colonCharCode
      conditionType = str.substr(0, i - 1)
      str = str.substr(i + 1).trim()
    else
      conditionType = ''

    conditionType = exports.typeFromAbbr(conditionType)
    return null unless conditionType
    condition = {conditionType: conditionType}
    fromStr = exports._handler(condition.conditionType).fromStr
    if fromStr
      return fromStr.call(exports, str, condition)
    else
      condition.pattern = str
      return condition

  _abbrs: null
  typeFromAbbr: (abbr) ->
    if not exports._abbrs
      exports._abbrs = {}
      for own type, {abbrs} of exports._conditionTypes
        exports._abbrs[type.toUpperCase()] = type
        for ab in abbrs
          exports._abbrs[ab.toUpperCase()] = type

    return exports._abbrs[abbr.toUpperCase()]

  comment: (comment, node) ->
    return node unless comment
    node.start ?= {}
    # This hack is needed to allow dumping comments in repeated print call.
    Object.defineProperty node.start, '_comments_dumped',
      get: -> false
      set: -> false
    node.start.comments_before ?= []
    node.start.comments_before.push {type: 'comment2', value: comment}
    node

  safeRegex: (expr) ->
    try
      new RegExp(expr)
    catch _
      # Invalid regexp! Fall back to a regexp that does not match anything.
      /(?!)/

  regTest: (expr, regexp) ->
    if typeof regexp == 'string'
      # Escape (unescaped) forward slash for use in regex literals.
      regexp = regexSafe escapeSlash regexp
    if typeof expr == 'string'
      expr = new U2.AST_SymbolRef name: expr
    new U2.AST_Call
      args: [expr]
      expression: new U2.AST_Dot(
        property: 'test'
        expression: new U2.AST_RegExp value: regexp
      )
  isInt: (num) ->
    (typeof num == 'number' and !isNaN(num) and
      parseFloat(num) == parseInt(num, 10))
  between: (val, min, max, comment) ->
    if min == max
      if typeof min == 'number'
        min = new U2.AST_Number value: min
      return exports.comment comment, new U2.AST_Binary(
        left: val
        operator: '==='
        right: min
      )
    if min > max
      return exports.comment comment, new U2.AST_False
    if exports.isInt(min) and exports.isInt(max) and max - min < 32
      comment ||= "#{min} <= value && value <= #{max}"
      tmpl = "0123456789abcdefghijklmnopqrstuvwxyz"
      str =
        if max < tmpl.length
          tmpl.substr(min, max - min + 1)
        else
          tmpl.substr(0, max - min + 1)
      pos = if min == 0 then val else
        new U2.AST_Binary(
          left: val
          operator: '-'
          right: new U2.AST_Number value: min
        )
      return exports.comment comment, new U2.AST_Binary(
        left: new U2.AST_Call(
          expression: new U2.AST_Dot(
            expression: new U2.AST_String value: str
            property: 'charCodeAt'
          )
          args: [pos]
        )
        operator: '>'
        right: new U2.AST_Number value: 0
      )
    if typeof min == 'number'
      min = new U2.AST_Number value: min
    if typeof max == 'number'
      max = new U2.AST_Number value: max
    exports.comment comment, new U2.AST_Call(
      args: [val, min, max]
      expression: new U2.AST_Function (
        argnames: [
          new U2.AST_SymbolFunarg name: 'value'
          new U2.AST_SymbolFunarg name: 'min'
          new U2.AST_SymbolFunarg name: 'max'
        ]
        body: [
          new U2.AST_Return value: new U2.AST_Binary(
            left: new U2.AST_Binary(
              left: new U2.AST_SymbolRef name: 'min'
              operator: '<='
              right: new U2.AST_SymbolRef name: 'value'
            )
            operator: '&&'
            right: new U2.AST_Binary(
              left: new U2.AST_SymbolRef name: 'value'
              operator: '<='
              right: new U2.AST_SymbolRef name: 'max'
            )
          )
        ]
      )
    )

  parseIp: (ip) ->
    if ip.charCodeAt(0) == '['.charCodeAt(0)
      ip = ip.substr 1, ip.length - 2
    addr = new IP.v4.Address(ip)
    if not addr.isValid()
      addr = new IP.v6.Address(ip)
      if not addr.isValid()
        return null
    return addr
  normalizeIp: (addr) ->
    return (addr.correctForm ? addr.canonicalForm).call(addr)
  ipv6Max: new IP.v6.Address('::/0').endAddress().canonicalForm()

  localHosts: ["127.0.0.1", "[::1]", "localhost"]

  getWeekdayList: (condition) ->
    if condition.days
      condition.days.charCodeAt(i) > 64 for i in [0...7]
    else
      condition.startDay <= i <= condition.endDay for i in [0...7]

  _condCache: new AttachedCache (condition) ->
    tag = exports._handler(condition.conditionType).tag
    result =
      if tag then tag.apply(exports, arguments) else exports.str(condition)

    condition.conditionType + '$' + result

  _setProp: (obj, prop, value) ->
    if not Object::hasOwnProperty.call obj, prop
      Object.defineProperty obj, prop, writable: true
    obj[prop] = value

  _handler: (conditionType) ->
    if typeof conditionType != 'string'
      conditionType = conditionType.conditionType
    handler = exports._conditionTypes[conditionType]

    if not handler?
      throw new Error "Unknown condition type: #{conditionType}"
    return handler

  _conditionTypes:
    # These functions are .call()-ed with `this` set to module.exports.
    # coffeelint: disable=missing_fat_arrows
    'TrueCondition':
      abbrs: ['True']
      analyze: (condition) -> null
      match: -> true
      compile: (condition) -> new U2.AST_True
      str: (condition) -> ''
      fromStr: (str, condition) -> condition

    'FalseCondition':
      abbrs: ['False', 'Disabled']
      analyze: (condition) -> null
      match: -> false
      compile: (condition) -> new U2.AST_False
      fromStr: (str, condition) ->
        if str.length > 0
          condition.pattern = str
        condition

    'UrlRegexCondition':
      abbrs: ['UR', 'URegex', 'UrlR', 'UrlRegex']
      analyze: (condition) -> @safeRegex escapeSlash condition.pattern
      match: (condition, request, cache) ->
        return cache.analyzed.test(request.url)
      compile: (condition, cache) ->
        @regTest 'url', cache.analyzed

    'UrlWildcardCondition':
      abbrs: ['U', 'UW', 'Url', 'UrlW', 'UWild', 'UWildcard', 'UrlWild',
              'UrlWildcard']
      analyze: (condition) ->
        parts = for pattern in condition.pattern.split('|') when pattern
          shExp2RegExp pattern, trimAsterisk: true
        @safeRegex parts.join('|')
      match: (condition, request, cache) ->
        return cache.analyzed.test(request.url)
      compile: (condition, cache) ->
        @regTest 'url', cache.analyzed

    'HostRegexCondition':
      abbrs: ['R', 'HR', 'Regex', 'HostR', 'HRegex', 'HostRegex']
      analyze: (condition) -> @safeRegex escapeSlash condition.pattern
      match: (condition, request, cache) ->
        return cache.analyzed.test(request.host)
      compile: (condition, cache) ->
        @regTest 'host', cache.analyzed

    'HostWildcardCondition':
      abbrs: ['', 'H', 'W', 'HW', 'Wild', 'Wildcard', 'Host', 'HostW', 'HWild',
              'HWildcard', 'HostWild', 'HostWildcard']
      analyze: (condition) ->
        parts = for pattern in condition.pattern.split('|') when pattern
          # Get the magical regex of this pattern. See
          # https://github.com/FelisCatus/SwitchyOmega/wiki/Host-wildcard-condition
          # for the magic.
          if pattern.charCodeAt(0) == '.'.charCodeAt(0)
            pattern = '*' + pattern

          if pattern.indexOf('**.') == 0
            shExp2RegExp pattern.substring(1), trimAsterisk: true
          else if pattern.indexOf('*.') == 0
            shExp2RegExp(pattern.substring(2), trimAsterisk: false)
              .replace(/./, '(?:^|\\.)').replace(/\.\*\$$/, '')
          else
            shExp2RegExp pattern, trimAsterisk: true
        @safeRegex parts.join('|')
      match: (condition, request, cache) ->
        return cache.analyzed.test(request.host)
      compile: (condition, cache) ->
        @regTest 'host', cache.analyzed

    'BypassCondition':
      abbrs: ['B', 'Bypass']
      analyze: (condition) ->
        # See https://developer.chrome.com/extensions/proxy#bypass_list
        cache =
          host: null
          ip: null
          scheme: null
          url: null
          normalizedPattern: ''
        server = condition.pattern
        if server == '<local>'
          cache.host = server
          return cache
        parts = server.split '://'
        if parts.length > 1
          cache.scheme = parts[0]
          cache.normalizedPattern = cache.scheme + '://'
          server = parts[1]

        parts = server.split '/'
        if parts.length > 1
          addr = @parseIp parts[0]
          prefixLen = parseInt(parts[1])
          if addr and not isNaN(prefixLen)
            cache.ip =
              conditionType: 'IpCondition'
              ip: @normalizeIp addr
              prefixLength: prefixLen
            cache.normalizedPattern += cache.ip.ip + '/' + cache.ip.prefixLength
            return cache
        # The server can be an IP address with or without brackets.
        serverIp = @parseIp(server)
        if not serverIp?
          pos = server.lastIndexOf(':')
          if pos >= 0
            matchPort = server.substring(pos + 1)
            server = server.substring(0, pos)
          serverIp = @parseIp server
        if serverIp?
          server = @normalizeIp serverIp
          if serverIp.v4
            cache.normalizedPattern += server
          else
            cache.normalizedPattern += '[' + server + ']'
        else
          if server.charCodeAt(0) == '.'.charCodeAt(0)
            server = '*' + server
          cache.normalizedPattern = server

        if matchPort
          cache.port = matchPort
          cache.normalizedPattern += ':' + cache.port
          # In URL, IPv6 server addresses need to be bracketed.
          if serverIp? and not serverIp.v4
            server = '[' + server + ']'
          serverRegex = shExp2RegExp(server)
          serverRegex = serverRegex.substring(1, serverRegex.length - 1)
          scheme = cache.scheme ? '[^:]+'
          cache.url = @safeRegex('^' + scheme + ':\\/\\/' + serverRegex +
            ':' + matchPort + '\\/')
        else if server != '*'
          # In host, IPv6 server addresses are never bracketed.
          serverRegex = shExp2RegExp server, trimAsterisk: true
          cache.host = @safeRegex(serverRegex)
        return cache
      match: (condition, request, cache) ->
        cache = cache.analyzed
        return false if cache.scheme? and cache.scheme != request.scheme
        return false if cache.ip? and not @match cache.ip, request
        if cache.host?
          if cache.host == '<local>'
            # https://code.google.com/p/chromium/codesearch#chromium/src/net/proxy/proxy_bypass_rules.cc&sq=package:chromium&l=67
            # We align with Chromium's behavior of bypassing 127.0.0.1, ::1 as
            # well as any host without dots.
            #
            # This, however, will match IPv6 literals who also don't have dots.
            return (
              request.host == '127.0.0.1' or
              request.host == '::1' or
              request.host.indexOf('.') < 0
            )
          else
            return false if not cache.host.test(request.host)
        return false if cache.url? and !cache.url.test(request.url)
        return true
      str: (condition) ->
        analyze = @_handler(condition).analyze
        cache = analyze.call(exports, condition)
        if cache.normalizedPattern
          return cache.normalizedPattern
        else
          return condition.pattern
      compile: (condition, cache) ->
        cache = cache.analyzed
        if cache.url?
          return @regTest 'url', cache.url
        conditions = []
        if cache.host == '<local>'
          hostEquals = (host) -> new U2.AST_Binary(
            left: new U2.AST_SymbolRef name: 'host'
            operator: '==='
            right: new U2.AST_String value: host
          )
          return new U2.AST_Binary(
            left: new U2.AST_Binary(
              left: hostEquals '127.0.0.1'
              operator: '||'
              right: hostEquals '::1'
            )
            operator: '||'
            right: new U2.AST_Binary(
              left: new U2.AST_Call(
                expression: new U2.AST_Dot(
                  expression: new U2.AST_SymbolRef name: 'host'
                  property: 'indexOf'
                )
                args: [new U2.AST_String value: '.']
              )
              operator: '<'
              right: new U2.AST_Number value: 0
            )
          )
        if cache.scheme?
          conditions.push new U2.AST_Binary(
            left: new U2.AST_SymbolRef name: 'scheme'
            operator: '==='
            right: new U2.AST_String value: cache.scheme
          )
        if cache.host?
          conditions.push @regTest 'host', cache.host
        else if cache.ip?
          conditions.push @compile cache.ip
        switch conditions.length
          when 0 then new U2.AST_True
          when 1 then conditions[0]
          when 2 then new U2.AST_Binary(
            left: conditions[0]
            operator: '&&'
            right: conditions[1]
          )
    'KeywordCondition':
      abbrs: ['K', 'KW', 'Keyword']
      analyze: (condition) -> null
      match: (condition, request) ->
        request.scheme == 'http' and request.url.indexOf(condition.pattern) >= 0
      compile: (condition) ->
        new U2.AST_Binary(
          left: new U2.AST_Binary(
            left: new U2.AST_SymbolRef name: 'scheme'
            operator: '==='
            right: new U2.AST_String value: 'http'
          )
          operator: '&&'
          right: new U2.AST_Binary(
            left: new U2.AST_Call(
              expression: new U2.AST_Dot(
                expression: new U2.AST_SymbolRef name: 'url'
                property: 'indexOf'
              )
              args: [new U2.AST_String value: condition.pattern]
            )
            operator: '>='
            right: new U2.AST_Number value: 0
          )
        )

    'IpCondition':
      abbrs: ['Ip']
      analyze: (condition) ->
        cache =
          addr: null
          normalized: null
        ip = condition.ip
        if ip.charCodeAt(0) == '['.charCodeAt(0)
          ip = ip.substr 1, ip.length - 2
        addr = ip + '/' + condition.prefixLength
        cache.addr = @parseIp addr
        if not cache.addr?
          throw new Error "Invalid IP address #{addr}"
        cache.normalized = @normalizeIp cache.addr
        mask = if cache.addr.v4
          new IP.v4.Address('255.255.255.255/' + cache.addr.subnetMask)
        else
          new IP.v6.Address(@ipv6Max + '/' + cache.addr.subnetMask)
        cache.mask = @normalizeIp mask.startAddress()
        cache
      match: (condition, request, cache) ->
        addr = @parseIp request.host
        return false if not addr?
        cache = cache.analyzed
        return false if addr.v4 != cache.addr.v4
        return addr.isInSubnet cache.addr
      compile: (condition, cache) ->
        cache = cache.analyzed
        # We want to make sure that host is not a domain name before we pass it
        # to isInNet. Otherwise an expensive dns lookup might be triggered.
        hostLooksLikeIp =
          if cache.addr.v4
            # For performance reasons, we just check the last character of host.
            # If it's a digit, we assume that host is valid IPv4 address.
            new U2.AST_Binary
              left: new U2.AST_Sub
                expression: new U2.AST_SymbolRef name: 'host'
                property: new U2.AST_Binary
                  left: new U2.AST_Dot(
                    expression: new U2.AST_SymbolRef name: 'host'
                    property: 'length'
                  )
                  operator: '-'
                  right: new U2.AST_Number value: 1
              operator: '>='
              right: new U2.AST_Number value: 0
          else
            # Likewise, we assume that host is valid IPv6 if it contains colons.
            new U2.AST_Binary(
              left: new U2.AST_Call(
                expression: new U2.AST_Dot(
                  expression: new U2.AST_SymbolRef name: 'host'
                  property: 'indexOf'
                )
                args: [new U2.AST_String value: ':']
              )
              operator: '>='
              right: new U2.AST_Number value: 0
            )
        if cache.addr.subnetMask == 0
          # 0.0.0.0/0 (matches all IPv4 literals), or ::/0 (all IPv6 literals).
          # Use hostLooksLikeIp instead of isInNet for better efficiency and
          # browser support.
          return hostLooksLikeIp
        hostIsInNet = new U2.AST_Call(
          expression: new U2.AST_SymbolRef name: 'isInNet'
          args: [
            new U2.AST_SymbolRef name: 'host'
            new U2.AST_String value: cache.normalized
            new U2.AST_String value: cache.mask
          ]
        )
        if not cache.addr.v4
          # Example: isInNetEx(host,"fefe:13::abc/33")
          # For documentation on the isInNetEx function, see:
          # https://msdn.microsoft.com/en-us/library/windows/desktop/gg308479(v=vs.85).aspx
          hostIsInNetEx = new U2.AST_Call(
            expression: new U2.AST_SymbolRef name: 'isInNetEx'
            args: [
              new U2.AST_SymbolRef name: 'host'
              new U2.AST_String value: cache.normalized + cache.addr.subnet
            ]
          )
          # Use isInNetEx if possible.
          hostIsInNet = new U2.AST_Conditional(
            condition: new U2.AST_Binary(
              left: new U2.AST_UnaryPrefix(
                operator: 'typeof'
                expression: new U2.AST_SymbolRef name: 'isInNetEx'
              )
              operator: '==='
              right: new U2.AST_String value: 'function'
            )
            consequent: hostIsInNetEx
            alternative: hostIsInNet
          )
        return new U2.AST_Binary(
          left: hostLooksLikeIp
          operator: '&&'
          right: hostIsInNet
        )
      str: (condition) -> condition.ip + '/' + condition.prefixLength
      fromStr: (str, condition) ->
        addr = @parseIp str
        if addr?
          condition.ip = addr.addressMinusSuffix
          condition.prefixLength = addr.subnetMask
        else
          condition.ip = '0.0.0.0'
          condition.prefixLength = 0
        condition

    'HostLevelsCondition':
      abbrs: ['Lv', 'Level', 'Levels', 'HL', 'HLv', 'HLevel', 'HLevels',
              'HostL', 'HostLv', 'HostLevel', 'HostLevels']
      analyze: (condition) -> '.'.charCodeAt 0
      match: (condition, request, cache) ->
        dotCharCode = cache.analyzed
        dotCount = 0
        for i in [0...request.host.length]
          if request.host.charCodeAt(i) == dotCharCode
            dotCount++
            return false if dotCount > condition.maxValue
        return dotCount >= condition.minValue
      compile: (condition) ->
        val = new U2.AST_Dot(
          property: 'length'
          expression: new U2.AST_Call(
            args: [new U2.AST_String value: '.']
            expression: new U2.AST_Dot(
              expression: new U2.AST_SymbolRef name: 'host'
              property: 'split'
            )
          )
        )
        @between(val, condition.minValue + 1, condition.maxValue + 1,
          "#{condition.minValue} <= hostLevels <= #{condition.maxValue}")
      str: (condition) -> condition.minValue + '~' + condition.maxValue
      fromStr: (str, condition) ->
        [minValue, maxValue] = str.split('~')
        condition.minValue = parseInt(minValue, 10)
        condition.maxValue = parseInt(maxValue, 10)
        condition.minValue = 1 unless condition.minValue > 0
        condition.maxValue = 1 unless condition.maxValue > 0
        condition

    'WeekdayCondition':
      abbrs: ['WD', 'Week', 'Day', 'Weekday']
      analyze: (condition) -> null
      match: (condition, request) ->
        day = new Date().getDay()
        return condition.days.charCodeAt(day) > 64 if condition.days
        return condition.startDay <= day and day <= condition.endDay
      compile: (condition) ->
        getDay = new U2.AST_Call(
          args: []
          expression: new U2.AST_Dot(
            property: 'getDay'
            expression: new U2.AST_New(
              args: []
              expression: new U2.AST_SymbolRef name: 'Date'
            )
          )
        )
        if condition.days
          new U2.AST_Binary(
            left: new U2.AST_Call(
              expression: new U2.AST_Dot(
                expression: new U2.AST_String value: condition.days
                property: 'charCodeAt'
              )
              args: [getDay]
            )
            operator: '>'
            right: new U2.AST_Number value: 64
          )
        else
          @between getDay, condition.startDay, condition.endDay
      str: (condition) ->
        if condition.days
          condition.days
        else
          condition.startDay + '~' + condition.endDay
      fromStr: (str, condition) ->
        if str.indexOf('~') < 0 and str.length == 7
          condition.days = str
        else
          [startDay, endDay] = str.split('~')
          condition.startDay = parseInt(startDay, 10)
          condition.endDay = parseInt(endDay, 10)
          condition.startDay = 0 unless 0 <= condition.startDay <= 6
          condition.endDay = 0 unless 0 <= condition.endDay <= 6
        condition

    'TimeCondition':
      abbrs: ['T', 'Time', 'Hour']
      analyze: (condition) -> null
      match: (condition, request) ->
        hour = new Date().getHours()
        return condition.startHour <= hour and hour <= condition.endHour
      compile: (condition) ->
        val = new U2.AST_Call(
          args: []
          expression: new U2.AST_Dot(
            property: 'getHours'
            expression: new U2.AST_New(
              args: []
              expression: new U2.AST_SymbolRef name: 'Date'
            )
          )
        )
        @between val, condition.startHour, condition.endHour
      str: (condition) -> condition.startHour + '~' + condition.endHour
      fromStr: (str, condition) ->
        [startHour, endHour] = str.split('~')
        condition.startHour = parseInt(startHour, 10)
        condition.endHour = parseInt(endHour, 10)
        condition.startHour = 0 unless 0 <= condition.startHour < 24
        condition.endHour = 0 unless 0 <= condition.endHour < 24
        condition
    # coffeelint: enable=missing_fat_arrows
