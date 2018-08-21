chai = require 'chai'
should = chai.should()

describe 'Profiles', ->
  Profiles = require '../src/profiles'
  Conditions = require '../src/conditions'
  U2 = require 'uglify-js'
  ruleListResult = (profileName, source) ->
    profileName: profileName
    source: source
  testProfile = (profile, request, expected, expectedCompiled) ->
    o_request = request
    if typeof request == 'string'
      request = Conditions.requestFromUrl(request)
    expectedCompiled ?= expected[0] ? Profiles.nameAsKey(expected.profileName)

    compiled = Profiles.compile(profile)
    compileResult = eval '(' + compiled.print_to_string() + ')'
    if typeof compileResult == 'function'
      compileResult = compileResult(request.url, request.host, request.scheme)

    if expected?
      matchResult = Profiles.match(profile, request)
      try
        if expected.source?
          chai.assert.equal(matchResult.profileName, expected.profileName)
          chai.assert.equal(matchResult.source, expected.source)
        else
          chai.assert.deepEqual(matchResult, expected)
      catch _
        printResult = JSON.stringify(matchResult)
        msg = ("expect profile to return #{JSON.stringify(expected)} " +
                "instead of #{printResult} for request #{o_request}")
        chai.assert(false, msg)

    if compileResult != expectedCompiled
      msg = ("expect COMPILED profile to return #{expectedCompiled} " +
              "instead of #{compileResult} for request #{o_request}")
      chai.assert(false, msg)

    return expected

  describe '#pacResult', ->
    it 'should return DIRECT for no proxy', ->
      Profiles.pacResult().should.equal("DIRECT")
    it 'should return a valid PAC result for a proxy', ->
      proxy = {scheme: "http", host: "127.0.0.1", port: 8888}
      Profiles.pacResult(proxy).should.equal("PROXY 127.0.0.1:8888")
    it 'should return special compatible result for SOCKS5', ->
      proxy = {scheme: "socks5", host: "127.0.0.1", port: 8888}
      compatibleResult = "SOCKS5 127.0.0.1:8888; SOCKS 127.0.0.1:8888"
      Profiles.pacResult(proxy).should.equal(compatibleResult)
  describe '#byName', ->
    it 'should get profiles from builtin profiles', ->
      profile = Profiles.byName('direct')
      profile.should.be.an('object')
      profile.profileType.should.equal('DirectProfile')
    it 'should get profiles from given options', ->
      profile = {}
      profile = Profiles.byName('profile', {"+profile": profile})
      profile.should.equal(profile)
  describe '#allReferenceSet', ->
    profile = Profiles.create('test', 'VirtualProfile')
    profile.defaultProfileName = 'bogus'
    it 'should throw if referenced profile does not exist', ->
      getAllReferenceSet = ->
        Profiles.allReferenceSet(profile, {})
      getAllReferenceSet.should.throw(Error)
    it 'should process a dumb profile for each missing profile if requested', ->
      profile.defaultProfileName = 'bogus'
      refs = Profiles.allReferenceSet profile, {}, profileNotFound: 'dumb'
      refs['+bogus'].should.equal('bogus')

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
      testProfile(profile, {}, null, 'DIRECT')
  describe 'FixedProfile', ->
    profile =
      profileType: 'FixedProfile'
      bypassList: [{
        conditionType: 'BypassCondition'
        pattern: '<local>'
      }]
      proxyForHttp:
        scheme: 'socks4'
        host: '127.0.0.1'
        port: 1234
      proxyForHttps:
        scheme: 'http'
        host: '127.0.0.1'
        port: 2345
      fallbackProxy:
        scheme: 'socks4'
        host: '127.0.0.1'
        port: 3456
      auth:
        proxyForHttps:
          username: 'test'
          password: 'cheesecake'
    it 'should use protocol-specific proxies if suitable', ->
      testProfile(profile, 'https://www.example.com/', ['PROXY 127.0.0.1:2345',
        'https', profile.proxyForHttps, profile.auth.proxyForHttps])
    it 'should use fallback proxies for other protocols', ->
      testProfile(profile, 'ftp://www.example.com/',
        ['SOCKS 127.0.0.1:3456', '', profile.fallbackProxy, undefined])
    it 'should not return authentication if not provided for protocol', ->
      testProfile(profile, 'http://www.example.com/',
        ['SOCKS 127.0.0.1:1234', 'http', profile.proxyForHttp, undefined])
    it 'should not use any proxy for requests matching the bypassList', ->
      testProfile profile, 'ftp://localhost/',
        ['DIRECT', profile.bypassList[0], {scheme: 'direct'}, undefined]
  describe 'PacProfile', ->
    profile = Profiles.create('test', 'PacProfile')
    profile.pacScript = '''
      function FindProxyForURL(url, host) {
        return "PROXY " + host + ":8080";
      }
    '''
    it 'should return the result of the pac script', ->
      testProfile(profile, 'ftp://www.example.com:9999/abc', null,
        'PROXY www.example.com:8080')
    it 'should not fail for PAC with trailing comments', ->
      p = Profiles.create('test', 'PacProfile')
      p.pacScript = profile.pacScript + '''
        // This is a trailing line comment.
      '''
      testProfile(p, 'ftp://www.example.com:9999/abc', null,
        'PROXY www.example.com:8080')
      p = Profiles.create('test', 'PacProfile')
      p.pacScript = profile.pacScript + '''
        /* This is a multiline comment which is not properly closed.
      '''
      testProfile(p, 'ftp://www.example.com:9999/abc', null,
        'PROXY www.example.com:8080')
    it 'should return includable for non-file pacUrl', ->
      Profiles.isIncludable(profile).should.be.true
    it 'should return not includable for file: pacUrl', ->
      p = Profiles.create('test', 'PacProfile')
      p.pacUrl = 'file:///proxy.pac'
      Profiles.isIncludable(p).should.be.false
  describe 'SwitchProfile', ->
    profile = Profiles.create('test', 'SwitchProfile')
    profile.rules = [
      {
        condition:
          conditionType: 'HostWildcardCondition'
          pattern: 'company.abc.example.com'
        profileName: 'company'
      },
      {
        condition:
          conditionType: 'HostWildcardCondition'
          pattern: '*.example.com'
        profileName: 'example'
      },
      {
        condition:
          conditionType: 'HostWildcardCondition'
          pattern: '*.abc.example.com'
        profileName: 'abc'
      }
    ]
    profile.defaultProfileName = 'default'
    it 'should match requests based on rules', ->
      testProfile(profile, 'http://company.abc.example.com:998/abc',
        profile.rules[0])
    it 'should respect the order of rules', ->
      testProfile(profile, 'http://abc.example.com:9999/abc',
        profile.rules[1])
      testProfile(profile, 'http://www.example.com:9999/abc',
        profile.rules[1])
    it 'should return defaultProfileName when no rules match', ->
      testProfile(profile, 'http://www.example.org:9999/abc',
        ['+default', null])
    it 'should calulate directly referenced profiles correctly', ->
      set = Profiles.directReferenceSet(profile)
      set.should.eql(
        '+company': 'company'
        '+example': 'example'
        '+abc': 'abc'
        '+default': 'default'
      )
    it 'should clear the reference cache on profile revision change', ->
      profile.revision = 'a'
      set = Profiles.directReferenceSet(profile)
      # Remove 'default' from references.
      profile.defaultProfileName = 'abc'
      profile.revision = 'b'
      newSet = Profiles.directReferenceSet(profile)
      newSet.should.eql(
        '+company': 'company'
        '+example': 'example'
        '+abc': 'abc'
      )
    it 'should clear the reference cache if explicitly requested', ->
      profile.revision = 'a'
      set = Profiles.directReferenceSet(profile)
      # Remove 'default' from references.
      profile.defaultProfileName = 'abc'
      Profiles.dropCache(profile)
      newSet = Profiles.directReferenceSet(profile)
      newSet.should.eql(
        '+company': 'company'
        '+example': 'example'
        '+abc': 'abc'
      )
  describe 'VirtualProfile', ->
    profile = Profiles.create('test', 'VirtualProfile')
    profile.defaultProfileName = 'default'
    it 'should always return defaultProfileName', ->
      testProfile(profile, 'http://www.example.com/abc',
        ['+default', null])
  describe 'RulelistProfile', ->
    profile = Profiles.create('test', 'AutoProxyRuleListProfile')
    profile.defaultProfileName = 'default'
    profile.matchProfileName = 'example'
    profile.ruleList = 'example.com'
    profile.revision = 'a'
    it 'should calulate directly referenced profiles correctly', ->
      set = Profiles.directReferenceSet(profile)
      set.should.eql(
        '+example': 'example'
        '+default': 'default'
      )
    it 'should calulate referenced profiles for rule list with results', ->
      set = Profiles.directReferenceSet({
        profileType: 'RuleListProfile'
        format: 'Switchy'
        matchProfileName: 'ignored'
        defaultProfileName: 'alsoIgnored'
        ruleList: '''
          [SwitchyOmega Conditions]
          @with result
          !*.example.org
          *.example.com +ABC
          * +DEF
        '''
      })
      set.should.eql(
        '+ABC': 'ABC'
        '+DEF': 'DEF'
      )
    it 'should match requests based on the rule list', ->
      testProfile(profile, 'http://localhost/example.com',
        ruleListResult('example', 'example.com'))
      testProfile(profile, 'http://localhost/example.org', ['+default', null])
    it 'should update rule list on update', ->
      Profiles.update(profile, 'example.org')
      profile.revision = 'b'
      testProfile(profile, 'http://localhost/example.com', ['+default', null])
      testProfile(profile, 'http://localhost/example.org',
        ruleListResult('example', 'example.org'))
    it 'should not fail when ruleList is not provided', ->
      p =
        profileType: 'RuleListProfile'
        format: 'Switchy'
        matchProfileName: 'match'
        defaultProfileName: 'default'
      Profiles.directReferenceSet(p).should.be.an 'object'
      testProfile(p, 'http://localhost/example.com', ['+default', null])
    it 'should switch to AutoProxy format on update if detected', ->
      profile = Profiles.create('test2', 'RuleListProfile')
      profile.format = 'Switchy'
      profile.defaultProfileName = 'default'
      profile.matchProfileName = 'example'

      profile.format.should.equal 'Switchy'
      Profiles.update(profile, '[AutoProxy]\nexample.org')
      profile.format.should.equal 'AutoProxy'

      testProfile(profile, 'http://localhost/example.com',
        ['+default', null])
      testProfile(profile, 'http://localhost/example.org',
        ruleListResult('example', 'example.org'))
