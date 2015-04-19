chai = require 'chai'
should = chai.should()

describe 'Conditions', ->
  Conditions = require '../src/conditions'
  U2 = require 'uglify-js'
  testCond = (condition, request, should_match) ->
    o_request = request
    should_match = !!should_match
    if typeof request == 'string'
      request = Conditions.requestFromUrl(request)

    matchResult = Conditions.match(condition, request)
    condExpr = Conditions.compile(condition, request)
    testFunc = new U2.AST_Function(
      argnames: [
        new U2.AST_SymbolFunarg name: 'url'
        new U2.AST_SymbolFunarg name: 'host'
        new U2.AST_SymbolFunarg name: 'scheme'
      ]
      body: [
        new U2.AST_Return value: condExpr
      ]
    )
    testFunc = eval '(' + testFunc.print_to_string() + ')'
    compileResult = testFunc(request.url, request.host, request.scheme)

    friendlyError = (compiled) ->
      # Try to give friendly assert messages instead of something like
      # "expect true to be false".
      printCond = JSON.stringify(condition)
      printCompiled = if compiled then 'COMPILED ' else ''
      printMatch = if should_match then 'to match' else 'not to match'
      msg = ("expect #{printCompiled}condition #{printCond} " +
             "#{printMatch} request #{o_request}")
      chai.assert(false, msg)

    if matchResult != should_match
      friendlyError()

    if compileResult != should_match
      friendlyError('compiled')

    return matchResult

  describe 'TrueCondition', ->
    it 'should always return true', ->
      testCond({conditionType: 'TrueCondition'}, {}, 'match')
  describe 'FalseCondition', ->
    it 'should always return false', ->
      testCond({conditionType: 'FalseCondition'}, {}, not 'match')
  describe 'UrlRegexCondition', ->
    cond =
      conditionType: 'UrlRegexCondition'
      pattern: 'example\\.com'
    it 'should match requests based on regex pattern', ->
      testCond(cond, 'http://www.example.com/', 'match')
    it 'should not match requests not matching the pattern', ->
      testCond(cond, 'http://www.example.net/', not 'match')
    it 'should support regex meta chars', ->
      con =
        conditionType: 'UrlRegexCondition'
        pattern: 'exam.*\\.com'
      testCond(con, 'http://www.example.com/', 'match')
    it 'should fallback to not match if pattern is invalid', ->
      con =
        conditionType: 'UrlRegexCondition'
        pattern: ')Invalid('
      testCond(con, 'http://www.example.com/', not 'match')
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
    it 'should process patterns like *.*example.com correctly', ->
      # https://github.com/FelisCatus/SwitchyOmega/issues/158
      con =
        conditionType: 'HostWildcardCondition'
        pattern: '*.*example.com'
      testCond(con, 'http://example.com/', 'match')
      testCond(con, 'http://www.example.com/', 'match')
      testCond(con, 'http://www.some-example.com/', 'match')
      testCond(con, 'http://xample.com/', not 'match')
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
    it 'should correctly support IPv6 canonicalization', ->
      cond =
        conditionType: 'BypassCondition'
        pattern: 'http://[0:0::1]:8080'
      result = Conditions.analyze(cond)
      testCond(cond, 'http://[::1]:8080/', 'match')
      testCond(cond, 'http://[1::1]:8080/', not 'match')

    it 'should parse IPv4 CIDR notation', ->
      cond =
        conditionType: 'BypassCondition'
        pattern: '192.168.0.0/16'
      result = Conditions.analyze(cond).analyzed
      should.exist(result.ip)
      result.ip.should.eql({
        conditionType: 'IpCondition'
        ip: '192.168.0.0'
        prefixLength: 16
      })

    it 'should parse IPv6 CIDR notation', ->
      cond =
        conditionType: 'BypassCondition'
        pattern: 'fefe:13::abc/33'
      result = Conditions.analyze(cond).analyzed
      should.exist(result.ip)
      result.ip.should.eql({
        conditionType: 'IpCondition'
        ip: 'fefe:13::abc'
        prefixLength: 33
      })

    it 'should parse IPv6 CIDR notation with zero prefixLength', ->
      cond =
        conditionType: 'BypassCondition'
        pattern: '::/0'
      result = Conditions.analyze(cond).analyzed
      should.exist(result.ip)
      result.ip.should.eql({
        conditionType: 'IpCondition'
        ip: '::'
        prefixLength: 0
      })

  describe 'IpCondition', ->
    # IpCondition requires isInNetEx or isInNet function provided by the PAC
    # runner, which is not available in the unit test. So We can't use testCond
    # here.
    it 'should support IPv4 subnet', ->
      cond =
        conditionType: "IpCondition"
        ip: '192.168.1.1'
        prefixLength: 16
      request = Conditions.requestFromUrl('http://192.168.4.4/')
      Conditions.match(cond, request).should.be.true
      compiled = Conditions.compile(cond).print_to_string()
      compiled.should.contain('isInNet(host,"192.168.1.1","255.255.0.0")')
    it 'should support IPv6 subnet', ->
      cond =
        conditionType: "IpCondition"
        ip: 'fefe:13::abc'
        prefixLength: 33

      request = Conditions.requestFromUrl('http://[fefe:13::def]/')
      Conditions.match(cond, request).should.be.true

      compiled = Conditions.compile(cond).print_to_string()
      compiled_args = compiled.substr(compiled.lastIndexOf('('))
      compiled_args.should.eql('(host,"fefe:13::abc","ffff:ffff:8000::")')
    it 'should support IPv6 subnet with zero prefixLength', ->
      cond =
        conditionType: "IpCondition"
        ip: '::'
        prefixLength: 0

      request = Conditions.requestFromUrl('http://[fefe:13::def]/')
      Conditions.match(cond, request).should.be.true

      compiled = Conditions.compile(cond).print_to_string()
      compiled.indexOf('indexOf(').should.be.above(0)
    it 'should not match domain name to IP subnet', ->
      cond =
        conditionType: "IpCondition"
        ip: '::'
        prefixLength: 0

      request = Conditions.requestFromUrl('http://www.example.com/')
      Conditions.match(cond, request).should.be.false
    it 'should not pass domain name to isInNet function', ->
      ipToCompiledFunc = (ip, prefixLen) ->
        cond =
          conditionType: "IpCondition"
          ip: ip
          prefixLength: prefixLen

        # In this test case, a dummy isInNet function that always returns true
        # is used. We only care about whether it is called or not here.
        dummyIsInNet = new U2.AST_Function(
          argnames: []
          body: [
            new U2.AST_Return value: new U2.AST_True
          ]
        )
        testFunc = new U2.AST_Function(
          argnames: [
            new U2.AST_SymbolFunarg name: 'url'
            new U2.AST_SymbolFunarg name: 'host'
            new U2.AST_SymbolFunarg name: 'scheme'
          ]
          body: [
            new U2.AST_Var definitions: [
              new U2.AST_VarDef(
                name: new U2.AST_SymbolVar(name: 'isInNet')
                value: dummyIsInNet
              )
            ]
            new U2.AST_Return value: Conditions.compile(cond)
          ]
        )
        console.log(Conditions.compile(cond).print_to_string())
        eval('(' + testFunc.print_to_string() + ')')

      compiledFunc = ipToCompiledFunc('0.0.0.0', 0)
      compiledFunc(null, 'www.example.com').should.equal(false)
      compiledFunc(null, '127.0.0.1').should.equal(true)

      compiledFunc = ipToCompiledFunc('0.0.0.0', 1)
      compiledFunc(null, 'www.example.com').should.equal(false)
      compiledFunc(null, '127.0.0.1').should.equal(true)

      compiledFunc = ipToCompiledFunc('::', 0)
      compiledFunc(null, 'www.example.com').should.equal(false)
      compiledFunc(null, '::1').should.equal(true)

      compiledFunc = ipToCompiledFunc('::', 1)
      compiledFunc(null, 'www.example.com').should.equal(false)
      compiledFunc(null, '::1').should.equal(true)

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

  describe '#typeFromAbbr', ->
    it 'should get condition types by abbrs', ->
      Conditions.typeFromAbbr('True').should.equal('TrueCondition')
      Conditions.typeFromAbbr('HR').should.equal('HostRegexCondition')

  describe '#str and #fromStr', ->
    it 'should encode & decode TrueCondition correctly', ->
      condition =
        conditionType: 'TrueCondition'
      result = Conditions.str(condition)
      result.should.equal('True:')
      cond = Conditions.fromStr(result)
      cond.should.eql(condition)
    it 'should encode & decode conditions with pattern correctly', ->
      condition =
        conditionType: 'UrlWildcardCondition'
        pattern: '*://*.example.com/*'
      result = Conditions.str(condition)
      result.should.equal('UrlWildcard: ' + condition.pattern)
      cond = Conditions.fromStr(result)
      cond.should.eql(condition)
    it 'should encode & decode False while preserving pattern', ->
      condition =
        conditionType: 'FalseCondition'
        pattern: 'a b c'
      result = Conditions.str(condition)
      result.should.equal('Disabled: a b c')
      cond = Conditions.fromStr(result)
      cond.should.eql(condition)
    it 'should encode & decode FalseCondition without any pattern', ->
      condition =
        conditionType: 'FalseCondition'
      result = Conditions.str(condition)
      result.should.equal('Disabled:')
      cond = Conditions.fromStr(result)
      cond.should.eql(condition)
    it 'should encode & decode HostWildcardCondition using shorthand syntax', ->
      condition =
        conditionType: 'HostWildcardCondition'
        pattern: '*.example.com'
      result = Conditions.str(condition)
      result.should.equal(condition.pattern)
      cond = Conditions.fromStr(result)
      cond.should.eql(condition)
    it 'should encode & decode HostWildcardCondition ending with colon', ->
      condition =
        conditionType: 'HostWildcardCondition'
        pattern: 'bogus:'
      result = Conditions.str(condition)
      result.should.equal('HostWildcard: ' + condition.pattern)
      cond = Conditions.fromStr(result)
      cond.should.eql(condition)
    it 'should encode & decode IpCondition correctly', ->
      condition =
        conditionType: 'IpCondition'
        ip: '127.0.0.1'
        prefixLength: 16
      result = Conditions.str(condition)
      result.should.equal('Ip: 127.0.0.1/16')
      cond = Conditions.fromStr(result)
      cond.should.eql(condition)
    it 'should parse conditions with extra spaces correctly', ->
      Conditions.fromStr('url:    *abcde*   ').should.eql({
        conditionType: 'UrlWildcardCondition'
        pattern: '*abcde*'
      })
    it 'should parse abbreviated condition types correctly', ->
      Conditions.fromStr('url: *://*.example.com/*').should.eql({
        conditionType: 'UrlWildcardCondition'
        pattern: '*://*.example.com/*'
      })
    it 'should parse escaped HostWildcardCondition starting with colon', ->
      Conditions.fromStr(': :bogus:').should.eql({
        conditionType: 'HostWildcardCondition'
        pattern: ':bogus:'
      })
