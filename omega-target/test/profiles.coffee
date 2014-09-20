chai = require 'chai'
should = chai.should()

describe 'Profiles', ->
  Profiles = require '../src/profiles'
  url = require 'url'

  requestFromUri = (uri) ->
    if typeof uri == 'string'
      uri = url.parse uri
    req =
      url: url.format(uri)
      host: uri.host
      scheme: uri.protocol.replace(':', '')

  U2 = require 'uglify-js'
  testProfile = (profile, request, expected) ->
    o_request = request
    if typeof request == 'string'
      request = requestFromUri(request)

    matchResult = Profiles.match(profile, request)
    compiled = Profiles.compile(profile, request)
    compileResult = eval '(' + compiled.print_to_string() + ')'
    if typeof compileResult == 'function'
      compileResult = compileResult(request.url, request.host, request.scheme)

    friendlyError = (compiled) ->
      # Try to give friendly assert messages.
      printProfile = JSON.stringify(printProfile)
      printCompiled = if compiled then 'COMPILED ' else ''
      printMatch = if should_match then 'to match' else 'not to match'
      msg = ("expect #{printCompiled} #{printProfile} #{printMatch} " +
              "request #{o_request}")
      chai.assert(false, msg)

    if expected[0] == '+' and matchResult != expected
      friendlyError()

    if compileResult != expected #TODO
      friendlyError('compiled')

    return matchResult

  describe '#pacResult', ->
    it 'should return DIRECT for no proxy', ->
      Profiles.pacResult().should.equal("DIRECT")
    it 'should return a valid PAC result for a proxy', ->
      proxy = {scheme: "http", host: "127.0.0.1", port: 8888}
      Profiles.pacResult(proxy).should.equal("PROXY 127.0.0.1:8888")
  describe '#byName', ->
    it 'should get profiles from builtin profiles', ->
      profile = Profiles.byName('direct')
      profile.should.be.an('object')
      profile.profileType.should.equal('DirectProfile')
    it 'should get profiles from given options', ->
      profile = {}
      profile = Profiles.byName('profile', {"+profile": profile})
      profile.should.equal(profile)
  describe 'SystemProfile', ->
    it 'should be builtin with the name "system"', ->
      profile = Profiles.byName('system')
      profile.should.be.an('object')
      profile.profileType.should.equal('SystemProfile')
    it 'should not match request to profiles', ->
      profile = Profiles.byName('system')
      should.not.exist Profiles.match(profile, {})
    it 'should throw when trying to compile', ->
      profile = Profiles.byName('system')
      should.throw(-> Profiles.compile(profile))
  describe 'DirectProfile', ->
    it 'should be builtin with the name "direct"', ->
      profile = Profiles.byName('direct')
      profile.should.be.an('object')
      profile.profileType.should.equal('DirectProfile')
    it 'should return "DIRECT" when compiled', ->
      profile = Profiles.byName('direct')
      testProfile(profile, {}, 'DIRECT')
  return
  describe 'UrlWildcardCondition', ->
    cond =
      conditionType: 'UrlWildcardCondition'
      pattern: '*example.com*'
    it 'should match requests based on wildcard pattern', ->
      testCond(cond, 'http://www.example.com/', 'match')
    it 'should not match requests not matching the pattern', ->
      testCond(cond, 'http://www.example.net/', not 'match')
    it 'should support wildcard question marks', ->
      cond =
        conditionType: 'UrlWildcardCondition'
        pattern: '*exam???.com*'
      testCond(cond, 'http://www.example.com/', 'match')
    it 'should not support regex meta chars', ->
      cond =
        conditionType: 'UrlWildcardCondition'
        pattern: '.*example.com.*'
      testCond(cond, 'http://example.com/', not 'match')
    it 'should support multiple patterns in one condition', ->
      cond =
        conditionType: 'UrlWildcardCondition'
        pattern: '*.example.com/*|*.example.net/*'
      testCond(cond, 'http://a.example.com/abc', 'match')
      testCond(cond, 'http://b.example.net/def', 'match')
      testCond(cond, 'http://c.example.org/ghi', not 'match')
  describe 'HostRegexCondition', ->
    cond =
      conditionType: 'HostRegexCondition'
      pattern: '.*\\.example\\.com'
    it 'should match requests based on regex pattern', ->
      testCond(cond, 'http://www.example.com/', 'match')
    it 'should not match requests not matching the pattern', ->
      testCond(cond, 'http://example.com/', not 'match')
    it 'should not match URL parts other than the host', ->
      testCond(cond, 'http://example.net/www.example.com')
        .should.be.false

  describe 'HostWildcardCondition', ->
    cond =
      conditionType: 'HostWildcardCondition'
      pattern: '*.example.com'
    it 'should match requests based on wildcard pattern', ->
      testCond(cond, 'http://www.example.com/', 'match')
    it 'should also match hostname without the optional level', ->
      # https://github.com/FelisCatus/SwitchyOmega/wiki/Host-wildcard-condition
      testCond(cond, 'http://example.com/', 'match')
    it 'should allow override of the magical behavior', ->
      con =
        conditionType: 'HostWildcardCondition'
        pattern: '**.example.com'
      testCond(con, 'http://www.example.com/', 'match')
      testCond(con, 'http://example.com/', not 'match')
    it 'should not match URL parts other than the host', ->
      testCond(cond, 'http://example.net/www.example.com')
        .should.be.false
    it 'should support multiple patterns in one condition', ->
      cond =
        conditionType: 'HostWildcardCondition'
        pattern: '*.example.com|*.example.net'
      testCond(cond, 'http://a.example.com/abc', 'match')
      testCond(cond, 'http://example.net/def', 'match')
      testCond(cond, 'http://c.example.org/ghi', not 'match')

  describe 'BypassCondition', ->
    # See https://developer.chrome.com/extensions/proxy#bypass_list
    it 'should correctly support patterns containing hosts', ->
      cond =
        conditionType: 'BypassCondition'
        pattern: '.example.com'
      testCond(cond, 'http://www.example.com/', 'match')
      testCond(cond, 'http://example.com/', not 'match')
      cond.pattern = '*.example.com'
      testCond(cond, 'http://www.example.com/', 'match')
      testCond(cond, 'http://example.com/', not 'match')
      cond.pattern = 'example.com'
      testCond(cond, 'http://example.com/', 'match')
      testCond(cond, 'http://www.example.com/', not 'match')
      cond.pattern = '*example.com'
      testCond(cond, 'http://example.com/', 'match')
      testCond(cond, 'http://www.example.com/', 'match')
      testCond(cond, 'http://anotherexample.com/', 'match')
    it 'should match the scheme specified in the pattern', ->
      cond =
        conditionType: 'BypassCondition'
        pattern: 'http://example.com'
      testCond(cond, 'http://example.com/', 'match')
      testCond(cond, 'https://example.com/', not 'match')
    it 'should match the port specified in the pattern', ->
      cond =
        conditionType: 'BypassCondition'
        pattern: 'http://example.com:8080'
      testCond(cond, 'http://example.com:8080/', 'match')
      testCond(cond, 'http://example.com:888/', not 'match')
    it 'should correctly support patterns using IPv4 literals', ->
      cond =
        conditionType: 'BypassCondition'
        pattern: 'http://127.0.0.1:8080'
      testCond(cond, 'http://127.0.0.1:8080/', 'match')
      testCond(cond, 'http://127.0.0.2:8080/', not 'match')
    # TODO(felis): Not yet supported. See the code for BypassCondition.
    it.skip 'should correctly support IPv6 canonicalization', ->
      cond =
        conditionType: 'BypassCondition'
        pattern: 'http://[0:0::1]:8080'
      Conditions.analyze(cond)
      cond._analyzed().url.should.equal '999'
      testCond(cond, 'http://[::1]:8080/', 'match')
      testCond(cond, 'http://[1::1]:8080/', not 'match')

  describe 'KeywordCondition', ->
    cond =
      conditionType: 'KeywordCondition'
      pattern: 'example.com'
    it 'should match requests based on substring', ->
      testCond(cond, 'http://www.example.com/', 'match')
      testCond(cond, 'http://www.example.net/', not 'match')
    it 'should not match HTTPS requests', ->
      testCond(cond, 'https://example.com/', not 'match')
      testCond(cond, 'https://example.net/', not 'match')
