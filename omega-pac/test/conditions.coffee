chai = require 'chai'
should = chai.should()
lolex = require 'lolex'

describe 'Conditions', ->
  Conditions = require '../src/conditions'
  U2 = require 'uglify-js'
  testCond = (condition, request, should_match) ->
    o_request = request
    should_match = !!should_match
    if typeof request == 'string'
      request = Conditions.requestFromUrl(request)

    matchResult = Conditions.match(condition, request)
    condExpr = Conditions.compile(condition)
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
    it 'should correctly support IPv6 canonicalization 2', ->
      cond =
        conditionType: 'BypassCondition'
        pattern: '[::1]'
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

    it 'should match 127.0.0.1 when <local> is used', ->
      cond =
        conditionType: 'BypassCondition'
        pattern: '<local>'
      testCond(cond, 'http://127.0.0.1:8080/', 'match')

    it 'should match [::1] when <local> is used', ->
      cond =
        conditionType: 'BypassCondition'
        pattern: '<local>'
      testCond(cond, 'http://[::1]:8080/', 'match')

    it 'should match any host without dots when <local> is used', ->
      cond =
        conditionType: 'BypassCondition'
        pattern: '<local>'
      testCond(cond, 'http://localhost:8080/', 'match')
      testCond(cond, 'http://intranet:8080/', 'match')
      testCond(cond, 'http://foobar/', 'match')
      testCond(cond, 'http://example.com/', not 'match')

      # Intended, see the corresponding code and comments for the reasoning.
      testCond(cond, 'http://[::ffff:eeee]/', 'match')
      testCond(cond, 'http://[::1.2.3.4]/', not 'match')

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
      compiled.should.contain('isInNet(host,"fefe:13::abc","ffff:ffff:8000::")')
      compiled.should.contain('isInNetEx(host,"fefe:13::abc/33")')
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

  describe 'WeekdayCondition', ->
    clock = null
    before ->
      clock = lolex.install 0, ['Date']
    after ->
      clock.uninstall()

    testCondDay = (cond, day, match) ->
      # Feb 2016 Calendar for testing:
      # Su Mo Tu We Th Fr Sa
      # .. 01 02 03 04 05 06
      # 07 08 09 10 11 12 13
      # (...)
      date = if day > 0 then day else 7
      clock.setSystemTime(new Date("2016-02-0#{date}T00:00:00Z").getTime())
      testCond(cond, "http://weekday-#{day}/", match)

    it 'should match requests based on date range', ->
      cond =
        conditionType: 'WeekdayCondition'
        startDay: 3
        endDay: 5

      testCondDay(cond, 0, not 'match')
      testCondDay(cond, 1, not 'match')
      testCondDay(cond, 2, not 'match')
      testCondDay(cond, 3, 'match')
      testCondDay(cond, 4, 'match')
      testCondDay(cond, 5, 'match')
      testCondDay(cond, 6, not 'match')

    it 'should match the day if startDay == endDay', ->
      cond =
        conditionType: 'WeekdayCondition'
        startDay: 3
        endDay: 3

      testCondDay(cond, 0, not 'match')
      testCondDay(cond, 1, not 'match')
      testCondDay(cond, 2, not 'match')
      testCondDay(cond, 3, 'match')
      testCondDay(cond, 4, not 'match')
      testCondDay(cond, 5, not 'match')
      testCondDay(cond, 6, not 'match')

    it 'should not match anything if startDay > endDay', ->
      cond =
        conditionType: 'WeekdayCondition'
        startDay: 4
        endDay: 3

      testCondDay(cond, 0, not 'match')
      testCondDay(cond, 1, not 'match')
      testCondDay(cond, 2, not 'match')
      testCondDay(cond, 3, not 'match')
      testCondDay(cond, 4, not 'match')
      testCondDay(cond, 5, not 'match')
      testCondDay(cond, 6, not 'match')

    it 'should match according to .days', ->
      cond =
        conditionType: 'WeekdayCondition'
        days: 'SMTWtFs'

      testCondDay(cond, 0, 'match')
      testCondDay(cond, 1, 'match')
      testCondDay(cond, 2, 'match')
      testCondDay(cond, 3, 'match')
      testCondDay(cond, 4, 'match')
      testCondDay(cond, 5, 'match')
      testCondDay(cond, 6, 'match')

      cond =
        conditionType: 'WeekdayCondition'
        days: 'S-TW-F-'

      testCondDay(cond, 0, 'match')
      testCondDay(cond, 1, not 'match')
      testCondDay(cond, 2, 'match')
      testCondDay(cond, 3, 'match')
      testCondDay(cond, 4, not 'match')
      testCondDay(cond, 5, 'match')
      testCondDay(cond, 6, not 'match')

    it 'should prefer .days to .startDay and .endDay', ->
      cond =
        conditionType: 'WeekdayCondition'
        days: '--TW---'
        startDay: 0
        endDay: 0

      testCondDay(cond, 0, not 'match')
      testCondDay(cond, 1, not 'match')
      testCondDay(cond, 2, 'match')
      testCondDay(cond, 3, 'match')
      testCondDay(cond, 4, not 'match')
      testCondDay(cond, 5, not 'match')
      testCondDay(cond, 6, not 'match')

  describe 'TimeCondition', ->
    clock = null
    before ->
      clock = lolex.install 0, ['Date']
    after ->
      clock.uninstall()

    testCondTime = (cond, time, match) ->
      # This uses RFC2822 format to make it in local time zone.
      # ISO-8601 should be avoided because ES5 says it assumes UTC.
      clock.setSystemTime(new Date("01 Feb 2016 #{time}").getTime())
      testCond(cond, "http://time-#{time}/", match)

    it 'should match requests based on hour range', ->
      cond =
        conditionType: 'TimeCondition'
        startHour: 7
        endHour: 9

      testCondTime(cond, '00:00:00', not 'match')
      testCondTime(cond, '06:00:00', not 'match')
      testCondTime(cond, '07:00:00', 'match')
      testCondTime(cond, '08:00:00', 'match')
      testCondTime(cond, '09:00:00', 'match')
      testCondTime(cond, '09:59:59', 'match')
      testCondTime(cond, '10:00:00', not 'match')
      testCondTime(cond, '19:00:00', not 'match')
      testCondTime(cond, '23:00:00', not 'match')

    it 'should match the hour if startHour == endHour', ->
      cond =
        conditionType: 'TimeCondition'
        startHour: 7
        endHour: 7

      testCondTime(cond, '00:00:00', not 'match')
      testCondTime(cond, '06:00:00', not 'match')
      testCondTime(cond, '07:00:00', 'match')
      testCondTime(cond, '07:00:01', 'match')
      testCondTime(cond, '07:59:59', 'match')
      testCondTime(cond, '08:00:00', not 'match')
      testCondTime(cond, '19:00:00', not 'match')

    it 'should not match anything if startHour > endHour', ->
      cond =
        conditionType: 'TimeCondition'
        startHour: 7
        endHour: 6

      testCondTime(cond, '00:00:00', not 'match')
      testCondTime(cond, '06:00:00', not 'match')
      testCondTime(cond, '06:59:59', not 'match')
      testCondTime(cond, '07:00:00', not 'match')
      testCondTime(cond, '08:00:00', not 'match')
      testCondTime(cond, '09:00:00', not 'match')
      testCondTime(cond, '10:00:00', not 'match')
      testCondTime(cond, '19:00:00', not 'match')
      testCondTime(cond, '23:00:00', not 'match')

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
    it 'should encode & decode BypassCondition correctly', ->
      condition =
        conditionType: 'BypassCondition'
        pattern: '127.0.0.1/16'
      result = Conditions.str(condition)
      result.should.equal('Bypass: 127.0.0.1/16')
      cond = Conditions.fromStr(result)
      cond.should.eql(condition)
    it 'should add brackets for IPv6 hosts in BypassCondition', ->
      condition =
        conditionType: 'BypassCondition'
        pattern: '::1'
      result = Conditions.str(condition)
      result.should.equal('Bypass: [::1]')
      cond = Conditions.fromStr(result)
      cond.conditionType.should.equal('BypassCondition')
      cond.pattern.should.equal('[::1]')
    it 'should add brackets for IPv6 hosts with scheme in BypassCondition', ->
      condition =
        conditionType: 'BypassCondition'
        pattern: 'http://::1'
      result = Conditions.str(condition)
      result.should.equal('Bypass: http://[::1]')
      cond = Conditions.fromStr(result)
      cond.conditionType.should.equal('BypassCondition')
      cond.pattern.should.equal('http://[::1]')
    it 'should encode & decode IpCondition correctly', ->
      condition =
        conditionType: 'IpCondition'
        ip: '127.0.0.1'
        prefixLength: 16
      result = Conditions.str(condition)
      result.should.equal('Ip: 127.0.0.1/16')
      cond = Conditions.fromStr(result)
      cond.should.eql(condition)
    it 'should provide sensible fallbacks for invalid IpCondition', ->
      cond = Conditions.fromStr('Ip: foo/-233')
      cond.should.eql(
        conditionType: 'IpCondition'
        ip: '0.0.0.0'
        prefixLength: 0
      )

      cond = Conditions.fromStr('Ip: nonsense stuff')
      cond.should.eql(
        conditionType: 'IpCondition'
        ip: '0.0.0.0'
        prefixLength: 0
      )
    it 'should assume full match for IpCondition without prefixLength', ->
      cond = Conditions.fromStr('Ip: 127.0.0.1')
      cond.should.eql(
        conditionType: 'IpCondition'
        ip: '127.0.0.1'
        prefixLength: 32
      )

      cond = Conditions.fromStr('Ip: ::1')
      cond.should.eql(
        conditionType: 'IpCondition'
        ip: '::1'
        prefixLength: 128
      )
    it 'should provide sensible fallbacks for invalid IpCondition', ->
      cond = Conditions.fromStr('Ip: 0.0.0.0/-233')
      cond.should.eql(
        conditionType: 'IpCondition'
        ip: '0.0.0.0'
        prefixLength: 0
      )
    it 'should encode & decode HostLevelsCondition correctly', ->
      condition =
        conditionType: 'HostLevelsCondition'
        minValue: 4
        maxValue: 7
      result = Conditions.str(condition)
      result.should.equal('HostLevels: 4~7')
      cond = Conditions.fromStr(result)
      cond.should.eql(condition)
    it 'should provide sensible fallbacks for HostLevels out of range', ->
      cond = Conditions.fromStr('HostLevels: A~-1')
      cond.should.eql(
        conditionType: 'HostLevelsCondition'
        minValue: 1
        maxValue: 1
      )

      cond = Conditions.fromStr('HostLevels: nonsense')
      cond.should.eql(
        conditionType: 'HostLevelsCondition'
        minValue: 1
        maxValue: 1
      )
    it 'should encode & decode WeekdayCondition correctly', ->
      condition =
        conditionType: 'WeekdayCondition'
        startDay: 3
        endDay: 6
      result = Conditions.str(condition)
      result.should.equal('Weekday: 3~6')
      cond = Conditions.fromStr(result)
      cond.should.eql(condition)
    it 'should provide sensible fallbacks for Weekday out of range', ->
      cond = Conditions.fromStr('Weekday: -1~100')
      cond.should.eql(
        conditionType: 'WeekdayCondition'
        startDay: 0
        endDay: 0
      )

      cond = Conditions.fromStr('Weekday: nonsense')
      cond.should.eql(
        conditionType: 'WeekdayCondition'
        startDay: 0
        endDay: 0
      )
    it 'should encode & decode WeekdayCondition with days', ->
      condition =
        conditionType: 'WeekdayCondition'
        days: 'SMTWtFs'
      result = Conditions.str(condition)
      result.should.equal('Weekday: SMTWtFs')
      cond = Conditions.fromStr(result)
      cond.should.eql(condition)

      condition =
        conditionType: 'WeekdayCondition'
        days: 'SM-W-Fs'
      result = Conditions.str(condition)
      result.should.equal('Weekday: SM-W-Fs')
      cond = Conditions.fromStr(result)
      cond.should.eql(condition)
    it 'should encode & decode TimeCondition correctly', ->
      condition =
        conditionType: 'TimeCondition'
        startHour: 7
        endHour: 23
      result = Conditions.str(condition)
      result.should.equal('Hour: 7~23')
      cond = Conditions.fromStr(result)
      cond.should.eql(condition)
    it 'should provide sensible fallbacks for Hour out of range', ->
      cond = Conditions.fromStr('Hour: -1~100')
      cond.should.eql(
        conditionType: 'TimeCondition'
        startHour: 0
        endHour: 0
      )

      cond = Conditions.fromStr('Hour: nonsense')
      cond.should.eql(
        conditionType: 'TimeCondition'
        startHour: 0
        endHour: 0
      )
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
