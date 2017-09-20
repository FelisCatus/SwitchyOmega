U2 = require 'uglify-js'
ShexpUtils = require './shexp_utils'
Conditions = require './conditions'
RuleList = require './rule_list'
{AttachedCache, Revision} = require './utils'

# coffeelint: disable=camel_case_classes
class AST_Raw extends U2.AST_SymbolRef
  # coffeelint: enable=camel_case_classes
  constructor: (raw) ->
    U2.AST_SymbolRef.call(this, name: raw)
    @aborts = -> false

module.exports = exports =
  builtinProfiles:
    '+direct':
      name: 'direct'
      profileType: 'DirectProfile'
      color: '#aaaaaa'
      builtin: true
    '+system':
      name: 'system'
      profileType: 'SystemProfile'
      color: '#000000'
      builtin: true

  schemes: [
    {scheme: 'http', prop: 'proxyForHttp'}
    {scheme: 'https', prop: 'proxyForHttps'}
    {scheme: 'ftp', prop: 'proxyForFtp'}
    {scheme: '', prop: 'fallbackProxy'}
  ]

  pacProtocols: {
    'http': 'PROXY'
    'https': 'HTTPS'
    'socks4': 'SOCKS'
    'socks5': 'SOCKS5'
  }

  formatByType: {
    'SwitchyRuleListProfile': 'Switchy'
    'AutoProxyRuleListProfile': 'AutoProxy'
  }

  ruleListFormats: [
    'Switchy'
    'AutoProxy'
  ]

  parseHostPort: (str, scheme) ->
    sep = str.lastIndexOf(':')
    return if sep < 0
    port = parseInt(str.substr(sep + 1)) || 80
    host = str.substr(0, sep)
    return unless host
    return {
      scheme: scheme
      host: host
      port: port
    }

  pacResult: (proxy) ->
    if proxy
      if proxy.scheme == 'socks5'
        "SOCKS5 #{proxy.host}:#{proxy.port}; SOCKS #{proxy.host}:#{proxy.port}"
      else
        "#{exports.pacProtocols[proxy.scheme]} #{proxy.host}:#{proxy.port}"
    else
      'DIRECT'

  isFileUrl: (url) -> !!(url?.substr(0, 5).toUpperCase() == 'FILE:')

  nameAsKey: (profileName) ->
    if typeof profileName != 'string'
      profileName = profileName.name
    '+' + profileName
  byName: (profileName, options) ->
    if typeof profileName == 'string'
      key = exports.nameAsKey(profileName)
      profileName = exports.builtinProfiles[key] ? options[key]
    profileName
  byKey: (key, options) ->
    if typeof key == 'string'
      key = exports.builtinProfiles[key] ? options[key]
    key

  each: (options, callback) ->
    charCodePlus = '+'.charCodeAt(0)
    for key, profile of options when key.charCodeAt(0) == charCodePlus
      callback(key, profile)
    for key, profile of exports.builtinProfiles
      if key.charCodeAt(0) == charCodePlus
        callback(key, profile)

  profileResult: (profileName) ->
    key = exports.nameAsKey(profileName)
    if key == '+direct'
      key = exports.pacResult()
    new U2.AST_String value: key

  isIncludable: (profile) ->
    includable = exports._handler(profile).includable
    if typeof includable == 'function'
      includable = includable.call(exports, profile)
    !!includable
  isInclusive: (profile) -> !!exports._handler(profile).inclusive

  updateUrl: (profile) ->
    exports._handler(profile).updateUrl?.call(exports, profile)
  updateContentTypeHints: (profile) ->
    exports._handler(profile).updateContentTypeHints?.call(exports, profile)
  update: (profile, data) ->
    exports._handler(profile).update.call(exports, profile, data)

  tag: (profile) -> exports._profileCache.tag(profile)
  create: (profile, opt_profileType) ->
    if typeof profile == 'string'
      profile =
        name: profile
        profileType: opt_profileType
    else if opt_profileType
      profile.profileType = opt_profileType
    create = exports._handler(profile).create
    return profile unless create
    create.call(exports, profile)
    profile
  updateRevision: (profile, revision) ->
    revision ?= Revision.fromTime()
    profile.revision = revision
  replaceRef: (profile, fromName, toName) ->
    return false if not exports.isInclusive(profile)
    handler = exports._handler(profile)
    handler.replaceRef.call(exports, profile, fromName, toName)
  analyze: (profile) ->
    cache = exports._profileCache.get profile, {}
    if not Object::hasOwnProperty.call(cache, 'analyzed')
      analyze = exports._handler(profile).analyze
      result = analyze?.call(exports, profile)
      cache.analyzed = result
    return cache
  dropCache: (profile) ->
    exports._profileCache.drop profile
  directReferenceSet: (profile) ->
    return {} if not exports.isInclusive(profile)
    cache = exports._profileCache.get profile, {}
    return cache.directReferenceSet if cache.directReferenceSet
    handler = exports._handler(profile)
    cache.directReferenceSet = handler.directReferenceSet.call(exports, profile)
  
  profileNotFound: (name, action) ->
    if not action?
      throw new Error("Profile #{name} does not exist!")
    if typeof action == 'function'
      action = action(name)
    if typeof action == 'object' and action.profileType
      return action
    switch action
      when 'ignore'
        return null
      when 'dumb'
        return exports.create({
          name: name
          profileType: 'VirtualProfile'
          defaultProfileName: 'direct'
        })
    throw action

  allReferenceSet: (profile, options, opt_args) ->
    o_profile = profile
    profile = exports.byName(profile, options)
    profile ?= exports.profileNotFound?(o_profile, opt_args.profileNotFound)
    opt_args ?= {}
    has_out = opt_args.out?
    result = opt_args.out ?= {}
    if profile
      result[exports.nameAsKey(profile.name)] = profile.name
      for key, name of exports.directReferenceSet(profile)
        exports.allReferenceSet(name, options, opt_args)
    delete opt_args.out if not has_out
    result
  referencedBySet: (profile, options, opt_args) ->
    profileKey = exports.nameAsKey(profile)
    opt_args ?= {}
    has_out = opt_args.out?
    result = opt_args.out ?= {}
    exports.each options, (key, prof) ->
      if exports.directReferenceSet(prof)[profileKey]
        result[key] = prof.name
        exports.referencedBySet(prof, options, opt_args)
    delete opt_args.out if not has_out
    result
  validResultProfilesFor: (profile, options) ->
    profile = exports.byName(profile, options)
    return [] if not exports.isInclusive(profile)
    profileKey = exports.nameAsKey(profile)
    ref = exports.referencedBySet(profile, options)
    ref[profileKey] = profileKey
    result = []
    exports.each options, (key, prof) ->
      if not ref[key] and exports.isIncludable(prof)
        result.push(prof)
    result
  match: (profile, request, opt_profileType) ->
    opt_profileType ?= profile.profileType
    cache = exports.analyze(profile)
    match = exports._handler(opt_profileType).match
    match?.call(exports, profile, request, cache)
  compile: (profile, opt_profileType) ->
    opt_profileType ?= profile.profileType
    cache = exports.analyze(profile)
    return cache.compiled if cache.compiled
    handler = exports._handler(opt_profileType)
    cache.compiled = handler.compile.call(exports, profile, cache)

  _profileCache: new AttachedCache (profile) -> profile.revision

  _handler: (profileType) ->
    if typeof profileType != 'string'
      profileType = profileType.profileType

    handler = profileType
    while typeof handler == 'string'
      handler = exports._profileTypes[handler]
    if not handler?
      throw new Error "Unknown profile type: #{profileType}"
    return handler

  _profileTypes:
    # These functions are .call()-ed with `this` set to module.exports.
    # coffeelint: disable=missing_fat_arrows
    'SystemProfile':
      compile: (profile) ->
        throw new Error "SystemProfile cannot be used in PAC scripts"
    'DirectProfile':
      includable: true
      compile: (profile) ->
        return new U2.AST_String(value: @pacResult())
    'FixedProfile':
      includable: true
      create: (profile) ->
        profile.bypassList ?= [
          {
            conditionType: 'BypassCondition'
            pattern: '127.0.0.1'
          }
          {
            conditionType: 'BypassCondition'
            pattern: '[::1]'
          }
          {
            conditionType: 'BypassCondition'
            pattern: 'localhost'
          }
        ]
      match: (profile, request) ->
        if profile.bypassList
          for cond in profile.bypassList
            if Conditions.match(cond, request)
              return [@pacResult(), cond, {scheme: 'direct'}, undefined]
        for s in @schemes when s.scheme == request.scheme and profile[s.prop]
          return [
            @pacResult(profile[s.prop]),
            s.scheme,
            profile[s.prop],
            profile.auth?[s.prop] ? profile.auth?['all']
          ]
        return [
          @pacResult(profile.fallbackProxy),
          '',
          profile.fallbackProxy,
          profile.auth?.fallbackProxy ? profile.auth?['all']
        ]
      compile: (profile) ->
        if ((not profile.bypassList or not profile.fallbackProxy) and
            not profile.proxyForHttp and not profile.proxyForHttps and
            not profile.proxyForFtp)
          return new U2.AST_String value:
            @pacResult profile.fallbackProxy
        body = [
          new U2.AST_Directive value: 'use strict'
        ]
        if profile.bypassList and profile.bypassList.length
          conditions = null
          for cond in profile.bypassList
            condition = Conditions.compile cond
            if conditions?
              conditions = new U2.AST_Binary(
                left: conditions
                operator: '||'
                right: condition
              )
            else
              conditions = condition
          body.push new U2.AST_If(
            condition: conditions
            body: new U2.AST_Return value: new U2.AST_String value: @pacResult()
          )
        if (not profile.proxyForHttp and not profile.proxyForHttps and
            not profile.proxyForFtp)
          body.push new U2.AST_Return value:
            new U2.AST_String value: @pacResult profile.fallbackProxy
        else
          body.push new U2.AST_Switch(
            expression: new U2.AST_SymbolRef name: 'scheme'
            body: for s in @schemes when not s.scheme or profile[s.prop]
              ret = [new U2.AST_Return value:
                new U2.AST_String value: @pacResult profile[s.prop]
              ]
              if s.scheme
                new U2.AST_Case(
                  expression: new U2.AST_String value: s.scheme
                  body: ret
                )
              else
                new U2.AST_Default body: ret
          )
        new U2.AST_Function(
          argnames: [
            new U2.AST_SymbolFunarg name: 'url'
            new U2.AST_SymbolFunarg name: 'host'
            new U2.AST_SymbolFunarg name: 'scheme'
          ]
          body: body
        )
    'PacProfile':
      includable: (profile) -> !@isFileUrl(profile.pacUrl)
      create: (profile) ->
        profile.pacScript ?= '''
          function FindProxyForURL(url, host) {
            return "DIRECT";
          }
        '''
      compile: (profile) ->
        new U2.AST_Call args: [new U2.AST_This], expression:
          new U2.AST_Dot property: 'call', expression: new U2.AST_Function(
            argnames: []
            body: [
              # https://github.com/FelisCatus/SwitchyOmega/issues/390
              # 1. Add \n after PAC to terminate line comment in PAC (// ...)
              # 2. Add another \n with knowledge that the first can be escaped
              #    by trailing backslash in PAC. (// ... \)
              # 3. Add a multiline-comment block /* ... */ to terminate any
              #    potential unclosed multiline-comment block. (/* ...)
              # 4. And finally, a semicolon to terminate the final statement.
              # Wait a moment. Do we really need to go this far? I don't know.

              # TODO(catus): Remove the hack needed to insert raw code.
              new AST_Raw ';\n' + profile.pacScript + '\n\n/* End of PAC */;'
              new U2.AST_Return value:
                new U2.AST_SymbolRef name: 'FindProxyForURL'
            ]
          )
      updateUrl: (profile) ->
        if @isFileUrl(profile.pacUrl)
          undefined
        else
          profile.pacUrl
      updateContentTypeHints: -> [
        '!text/html'
        '!application/xhtml+xml'
        'application/x-ns-proxy-autoconfig'
        'application/x-javascript-config'
      ]
      update: (profile, data) ->
        return false if profile.pacScript == data
        profile.pacScript = data
        return true
    'AutoDetectProfile': 'PacProfile'
    'SwitchProfile':
      includable: true
      inclusive: true
      create: (profile) ->
        profile.defaultProfileName ?= 'direct'
        profile.rules ?= []
      directReferenceSet: (profile) ->
        refs = {}
        refs[exports.nameAsKey(profile.defaultProfileName)] =
          profile.defaultProfileName
        for rule in profile.rules
          refs[exports.nameAsKey(rule.profileName)] = rule.profileName
        refs
      analyze: (profile) -> profile.rules
      replaceRef: (profile, fromName, toName) ->
        changed = false
        if profile.defaultProfileName == fromName
          profile.defaultProfileName = toName
          changed = true
        for rule in profile.rules
          if rule.profileName == fromName
            rule.profileName = toName
            changed = true
        return changed
      match: (profile, request, cache) ->
        for rule in cache.analyzed
          if Conditions.match(rule.condition, request)
            return rule
        return [exports.nameAsKey(profile.defaultProfileName), null]
      compile: (profile, cache) ->
        rules = cache.analyzed
        if rules.length == 0
          return @profileResult profile.defaultProfileName
        body = [
          new U2.AST_Directive value: 'use strict'
        ]
        for rule in rules
          body.push new U2.AST_If
            condition: Conditions.compile rule.condition
            body: new U2.AST_Return value:
              @profileResult(rule.profileName)
        body.push new U2.AST_Return value:
          @profileResult profile.defaultProfileName
        new U2.AST_Function(
          argnames: [
            new U2.AST_SymbolFunarg name: 'url'
            new U2.AST_SymbolFunarg name: 'host'
            new U2.AST_SymbolFunarg name: 'scheme'
          ]
          body: body
        )
    'VirtualProfile': 'SwitchProfile'
    'RuleListProfile':
      includable: true
      inclusive: true
      create: (profile) ->
        profile.profileType ?= 'RuleListProfile'
        profile.format ?= exports.formatByType[profile.profileType] ?  'Switchy'
        profile.defaultProfileName ?= 'direct'
        profile.matchProfileName ?= 'direct'
        profile.ruleList ?= ''
      directReferenceSet: (profile) ->
        if profile.ruleList?
          refs = RuleList[profile.format]?.directReferenceSet?(profile)
          return refs if refs
        refs = {}
        for name in [profile.matchProfileName, profile.defaultProfileName]
          refs[exports.nameAsKey(name)] = name
        refs
      replaceRef: (profile, fromName, toName) ->
        changed = false
        if profile.defaultProfileName == fromName
          profile.defaultProfileName = toName
          changed = true
        if profile.matchProfileName == fromName
          profile.matchProfileName = toName
          changed = true
        return changed
      analyze: (profile) ->
        format = profile.format ? exports.formatByType[profile.profileType]
        formatHandler = RuleList[format]
        if not formatHandler
          throw new Error "Unsupported rule list format #{format}!"
        ruleList = profile.ruleList?.trim() || ''
        if formatHandler.preprocess?
          ruleList = formatHandler.preprocess(ruleList)
        return formatHandler.parse(ruleList, profile.matchProfileName,
          profile.defaultProfileName)
      match: (profile, request) ->
        result = exports.match(profile, request, 'SwitchProfile')
      compile: (profile) ->
        exports.compile(profile, 'SwitchProfile')
      updateUrl: (profile) -> profile.sourceUrl
      updateContentTypeHints: -> [
        '!text/html'
        '!application/xhtml+xml'
        'text/plain'
        '*'
      ]
      update: (profile, data) ->
        data = data.trim()
        original = profile.format ? exports.formatByType[profile.profileType]
        profile.profileType = 'RuleListProfile'
        format = original
        if RuleList[format].detect?(data) == false
          # Wrong data for the current format.
          format = null
        for own formatName of RuleList
          result = RuleList[formatName].detect?(data)
          if result == true or (result != false and not format?)
            profile.format = format = formatName
        format ?= original
        formatHandler = RuleList[format]
        if formatHandler.preprocess?
          data = formatHandler.preprocess(data)
        return false if profile.ruleList == data
        profile.ruleList = data
        return true
    'SwitchyRuleListProfile': 'RuleListProfile'
    'AutoProxyRuleListProfile': 'RuleListProfile'
    # coffeelint: enable=missing_fat_arrows
