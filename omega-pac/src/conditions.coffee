U2 = require 'uglify-js'
IP = require 'ipv6'
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

  comment: (comment, node) ->
    return unless comment
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
    catch
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
        right: new U2.AST_Number value: min
      )
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

  _condCache: new AttachedCache (condition) ->
    condition.conditionType + '$' +
    exports._handler(condition.conditionType).tag.apply(exports, arguments)

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
      tag: (condition) -> ''
      analyze: (condition) -> null
      match: -> true
      compile: (condition) -> new U2.AST_True
    'FalseCondition':
      tag: (condition) -> ''
      analyze: (condition) -> null
      match: -> false
      compile: (condition) -> new U2.AST_False
    'UrlRegexCondition':
      tag: (condition) -> condition.pattern
      analyze: (condition) -> @safeRegex escapeSlash condition.pattern
      match: (condition, request, cache) ->
        return cache.analyzed.test(request.url)
      compile: (condition, cache) ->
        @regTest 'url', cache.analyzed

    'UrlWildcardCondition':
      tag: (condition) -> condition.pattern
      analyze: (condition) ->
        parts = for pattern in condition.pattern.split('|') when pattern
          shExp2RegExp pattern, trimAsterisk: true
        @safeRegex parts.join('|')
      match: (condition, request, cache) ->
        return cache.analyzed.test(request.url)
      compile: (condition, cache) ->
        @regTest 'url', cache.analyzed

    'HostRegexCondition':
      tag: (condition) -> condition.pattern
      analyze: (condition) -> @safeRegex escapeSlash condition.pattern
      match: (condition, request, cache) ->
        return cache.analyzed.test(request.host)
      compile: (condition, cache) ->
        @regTest 'host', cache.analyzed

    'HostWildcardCondition':
      tag: (condition) -> condition.pattern
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
      tag: (condition) -> condition.pattern
      analyze: (condition) ->
        # See https://developer.chrome.com/extensions/proxy#bypass_list
        cache =
          host: null
          ip: null
          scheme: null
          url: null
        server = condition.pattern
        if server == '<local>'
          cache.host = server
          return cache
        parts = server.split '://'
        if parts.length > 1
          cache.scheme = parts[0]
          server = parts[1]

        parts = server.split '/'
        if parts.length > 1
          addr = @parseIp parts[0]
          prefixLen = parseInt(parts[1])
          if addr and prefixLen
            cache.ip =
              conditionType: 'IpCondition'
              ip: parts[0]
              prefixLength: prefixLen
            return cache
        if server.charCodeAt(server.length - 1) != ']'.charCodeAt(0)
          pos = server.lastIndexOf(':')
          if pos >= 0
            matchPort = server.substring(pos + 1)
            server = server.substring(0, pos)
        serverIp = @parseIp server
        serverRegex = null
        if serverIp?
          if serverIp.regularExpressionString?
            # TODO(felis): IPv6 regex is not fully supported by the ipv6
            # module. Even simple addresses like ::1 will fail. Shall we
            # implement that instead?
            regexStr = serverIp.regularExpressionString(true)
            console.log(regexStr)
            serverRegex = '\\[' + regexStr + '\\]'
          else
            server = @normalizeIp serverIp
        else if server.charCodeAt(0) == '.'.charCodeAt(0)
          server = '*' + server
        if matchPort
          if not serverRegex?
            serverRegex = shExp2RegExp(server)
            serverRegex = serverRegex.substring(1, serverRegex.length - 1)
          scheme = cache.scheme ? '[^:]+'
          cache.url = @safeRegex('^' + scheme + ':\\/\\/' + serverRegex +
            ':' + matchPort + '\\/')
        else if server != '*'
          if serverRegex
            serverRegex = '^' + serverRegex + '$'
          else
            serverRegex = shExp2RegExp server, trimAsterisk: true
          cache.host = @safeRegex(serverRegex)
        return cache
      match: (condition, request, cache) ->
        cache = cache.analyzed
        return false if cache.scheme? and cache.scheme != request.scheme
        return false if cache.ip? and @match cache.ip, request
        if cache.host?
          if cache.host == '<local>'
            return request.host in @localHosts
          else
            return false if not cache.host.test(request.host)
        return false if cache.url? and !cache.url.test(request.url)
        return true
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
              left: hostEquals '[::1]'
              operator: '||'
              right: hostEquals 'localhost'
            )
            operator: '||'
            right: hostEquals '127.0.0.1'
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
      tag: (condition) -> condition.pattern
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
      tag: (condition) -> condition.ip + '/' + condition.prefixLength
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
          new IP.v6.Address(@ipv6Max + cache.addr.subnetMask)
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
        new U2.AST_Call(
          expression: new U2.AST_SymbolRef name: 'isInNet'
          args: [
            new U2.AST_SymbolRef name: 'host'
            new U2.AST_String value: cache.normalized
            new U2.AST_String value: cache.mask
          ]
        )
    'HostLevelsCondition':
      tag: (condition) -> condition.minValue + '~' + condition.maxValue
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
    'WeekdayCondition':
      tag: (condition) -> condition.startDay + '~' + condition.endDay
      analyze: (condition) -> null
      match: (condition, request) ->
        day = new Date().getDay()
        return condition.startDay <= day and day <= condition.endDay
      compile: (condition) ->
        val = new U2.AST_Call(
          args: []
          expression: new U2.AST_Dot(
            property: 'getDay'
            expression: new U2.AST_New(
              args: []
              expression: new U2.AST_SymbolRef name: 'Date'
            )
          )
        )
        @between val, condition.startDay, condition.endDay
    'TimeCondition':
      tag: (condition) -> condition.startHour + '~' + condition.endHour
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
    # coffeelint: enable=missing_fat_arrows
