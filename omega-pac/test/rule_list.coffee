chai = require 'chai'
should = chai.should()

describe 'RuleList', ->
  RuleList = require '../src/rule_list'
  describe 'AutoProxy', ->
    parse = RuleList['AutoProxy'].parse
    it 'should parse keyword conditions', ->
      line = 'example.com'
      result = parse(line, 'match', 'notmatch')
      result.should.have.length(1)
      result[0].should.eql(
        source: line
        profileName: 'match'
        condition:
          conditionType: 'KeywordCondition'
          pattern: 'example.com'
      )
    it 'should parse keyword conditions with asterisks', ->
      line = 'example*.com'
      result = parse(line, 'match', 'notmatch')
      result.should.have.length(1)
      result[0].should.eql(
        source: line
        profileName: 'match'
        condition:
          conditionType: 'UrlWildcardCondition'
          pattern: 'http://*example*.com*'
      )
    it 'should parse host conditions', ->
      line = '||example.com'
      result = parse(line, 'match', 'notmatch')
      result.should.have.length(1)
      result[0].should.eql(
        source: line
        profileName: 'match'
        condition:
          conditionType: 'HostWildcardCondition'
          pattern: '*.example.com'
      )
    it 'should parse "starts-with" conditions', ->
      line = '|https://ssl.example.com'
      result = parse(line, 'match', 'notmatch')
      result.should.have.length(1)
      result[0].should.eql(
        source: line
        profileName: 'match'
        condition:
          conditionType: 'UrlWildcardCondition'
          pattern: 'https://ssl.example.com*'
      )
    it 'should parse "starts-with" conditions for the HTTP scheme', ->
      line = '|http://example.com'
      result = parse(line, 'match', 'notmatch')
      result.should.have.length(1)
      result[0].should.eql(
        source: line
        profileName: 'match'
        condition:
          conditionType: 'UrlWildcardCondition'
          pattern: 'http://example.com*'
      )
    it 'should parse url regex conditions', ->
      line = '/^https?:\\/\\/[^\\/]+example\.com/'
      result = parse(line, 'match', 'notmatch')
      result.should.have.length(1)
      result[0].should.eql(
        source: line
        profileName: 'match'
        condition:
          conditionType: 'UrlRegexCondition'
          pattern: '^https?:\\/\\/[^\\/]+example\.com'
      )
    it 'should ignore comment lines', ->
      result = parse('!example.com', 'match', 'notmatch')
      result.should.have.length(0)
    it 'should parse multiple lines', ->
      result = parse 'example.com\n!comment\n||example.com', 'match', 'notmatch'
      result.should.have.length(2)
      result[0].should.eql(
        source: 'example.com'
        profileName: 'match'
        condition:
          conditionType: 'KeywordCondition'
          pattern: 'example.com'
      )
      result[1].should.eql(
        source: '||example.com'
        profileName: 'match'
        condition:
          conditionType: 'HostWildcardCondition'
          pattern: '*.example.com'
      )
    it 'should put exclusive rules first', ->
      result = parse 'example.com\n@@||example.com', 'match', 'notmatch'
      result.should.have.length(2)
      result[0].should.eql(
        source: '@@||example.com'
        profileName: 'notmatch'
        condition:
          conditionType: 'HostWildcardCondition'
          pattern: '*.example.com'
      )
      result[1].should.eql(
        source: 'example.com'
        profileName: 'match'
        condition:
          conditionType: 'KeywordCondition'
          pattern: 'example.com'
      )

  describe 'Switchy', ->
    parse = RuleList['Switchy'].parse
    compose = (sections) ->
      list = '#BEGIN\r\n\r\n'
      for sec, rules of sections
        list += "[#{sec}]\r\n"
        for rule in rules
          list += rule
          list += '\r\n'
      list += '\r\n\r\n#END\r\n'
    it 'should parse empty rule lists', ->
      list = compose {}
      result = parse(list, 'match', 'notmatch')
      result.should.have.length(0)
    it 'should ignore stuff before #BEGIN or after #END.', ->
      list = compose {}
      list += '[RegExp]\r\ntest\r\n'
      list = '[Wildcard]\r\ntest\r\n' + list
      result = parse(list, 'match', 'notmatch')
      result.should.have.length(0)
    it 'should parse wildcard rules', ->
      list = compose 'Wildcard': [
        '*://example.com/abc/*'
      ]
      result = parse(list, 'match', 'notmatch')
      result.should.have.length(1)
      result[0].should.eql(
        source: '*://example.com/abc/*'
        profileName: 'match'
        condition:
          conditionType: 'UrlWildcardCondition'
          pattern: '*://example.com/abc/*'
      )
    it 'should parse RegExp rules', ->
      list = compose 'RegExp': [
        '^http://www\.example\.com/.*'
      ]
      result = parse(list, 'match', 'notmatch')
      result.should.have.length(1)
      result[0].should.eql(
        source: '^http://www\.example\.com/.*'
        profileName: 'match'
        condition:
          conditionType: 'UrlRegexCondition'
          pattern: '^http://www\.example\.com/.*'
      )
    it 'should parse exclusive rules', ->
      list = compose 'RegExp': [
        '!^http://www\.example\.com/.*'
      ]
      result = parse(list, 'match', 'notmatch')
      result.should.have.length(1)
      result[0].should.eql(
        source: '!^http://www\.example\.com/.*'
        profileName: 'notmatch'
        condition:
          conditionType: 'UrlRegexCondition'
          pattern: '^http://www\.example\.com/.*'
      )
    it 'should parse multiple rules in multiple sections', ->
      list = compose {
        'Wildcard': [
          'http://www.example.com/*'
          'http://example.com/*'
        ]
        'RegExp': [
          '^http://www\.example\.com/.*'
          '^http://example\.com/.*'
        ]
      }
      result = parse(list, 'match', 'notmatch')
      result.should.have.length(4)
      result[0].should.eql(
        source: 'http://www.example.com/*'
        profileName: 'match'
        condition:
          conditionType: 'UrlWildcardCondition'
          pattern: 'http://www.example.com/*'
      )
      result[1].should.eql(
        source: 'http://example.com/*'
        profileName: 'match'
        condition:
          conditionType: 'UrlWildcardCondition'
          pattern: 'http://example.com/*'
      )
      result[2].should.eql(
        source: '^http://www\.example\.com/.*'
        profileName: 'match'
        condition:
          conditionType: 'UrlRegexCondition'
          pattern: '^http://www\.example\.com/.*'
      )
      result[3].should.eql(
        source: '^http://example\.com/.*'
        profileName: 'match'
        condition:
          conditionType: 'UrlRegexCondition'
          pattern: '^http://example\.com/.*'
      )
    it 'should put exclusive rules first', ->
      list = compose {
        'Wildcard': [
          'http://www\.example\.com/*'
        ]
        'RegExp': [
          '!^http://www\.example\.com/.*'
        ]
      }
      result = parse(list, 'match', 'notmatch')
      result.should.have.length(2)
      result[0].should.eql(
        source: '!^http://www\.example\.com/.*'
        profileName: 'notmatch'
        condition:
          conditionType: 'UrlRegexCondition'
          pattern: '^http://www.example\.com/.*'
      )
      result[1].should.eql(
        source: 'http://www\.example\.com/*'
        profileName: 'match'
        condition:
          conditionType: 'UrlWildcardCondition'
          pattern: 'http://www.example.com/*'
      )

  describe 'Switchy (omega format)', ->
    parse = RuleList['Switchy'].parse
    compose = RuleList['Switchy'].compose
    it 'should parse empty rule lists', ->
      list = compose {rules: []}
      result = parse(list, 'match', 'notmatch')
      result.should.have.length(0)
    it 'should ignore comment lines.', ->
      list = compose {rules: []}
      list += ';*.example.com \r\n'
      result = parse(list, 'match', 'notmatch')
      result.should.have.length(0)
    it 'should compose and parse HostWildcardCondition', ->
      rule =
        source: '*.example.com'
        condition:
          conditionType: 'HostWildcardCondition',
          pattern: '*.example.com'
        profileName: 'match'
      list = compose({rules: [rule], defaultProfileName: 'notmatch'})
      result = parse(list, 'match', 'notmatch')
      result.should.have.length(1)
      result[0].should.eql(rule)
    it 'should compose and parse HostRegexCondition', ->
      rule =
        source: 'HostRegex: ^http://www\.example\.com/.*'
        condition:
          conditionType: 'HostRegexCondition',
          pattern: '^http://www\.example\.com/.*'
        profileName: 'match'
      list = compose({rules: [rule], defaultProfileName: 'notmatch'})
      result = parse(list, 'match', 'notmatch')
      result.should.have.length(1)
      result[0].should.eql(rule)
    it 'should compose and parse disabled rules', ->
      rule =
        source: 'Disabled: *.example.com'
        condition:
          conditionType: 'FalseCondition',
          pattern: '*.example.com'
        profileName: 'match'
      list = compose({rules: [rule], defaultProfileName: 'notmatch'})
      result = parse(list, 'match', 'notmatch')
      result.should.have.length(1)
      result[0].should.eql(rule)
    it 'should compose and parse exclusive rules', ->
      rule =
        source: '!*.example.com'
        condition:
          conditionType: 'HostWildcardCondition',
          pattern: '*.example.com'
        profileName: 'notmatch'
      list = compose({rules: [rule], defaultProfileName: 'notmatch'})
      result = parse(list, 'match', 'notmatch')
      result.should.have.length(1)
      result[0].should.eql(rule)
    it 'should compose and parse conditions starting with special chars', ->
      rule =
        source: ': ;abc'
        condition:
          conditionType: 'HostWildcardCondition',
          pattern: ';abc'
        profileName: 'match'
      list = compose({rules: [rule], defaultProfileName: 'notmatch'})
      result = parse(list, 'match', 'notmatch')
      result.should.have.length(1)
      result[0].should.eql(rule)
    it 'should parse multiple conditions', ->
      rules = [{
        source: '*.example.com'
        condition:
          conditionType: 'HostWildcardCondition',
          pattern: '*.example.com'
        profileName: 'match'
      }, {
        source: '*.example.org'
        condition:
          conditionType: 'HostWildcardCondition',
          pattern: '*.example.org'
        profileName: 'match'
      }]
      list = compose({rules: rules, defaultProfileName: 'notmatch'})
      result = parse(list, 'match', 'notmatch')
      result.should.eql(rules)
    it 'should respect the top-down order of conditions', ->
      rules = [{
        source: 'b.example.com'
        condition:
          conditionType: 'HostWildcardCondition',
          pattern: 'b.example.com'
        profileName: 'match'
      }, {
        source: '!a.example.org'
        condition:
          conditionType: 'HostWildcardCondition',
          pattern: 'a.example.org'
        profileName: 'notmatch'
      }]
      list = compose({rules: rules, defaultProfileName: 'notmatch'})
      result = parse(list, 'match', 'notmatch')
      result.should.eql(rules)
    it 'should add a default rule when results are enabled', ->
      list = compose(
        {rules: [], defaultProfileName: 'notmatch'}
        {withResult: true}
      )
      list.split(/\r|\n/).should.contain('@with result')
      result = parse(list, 'ignored', 'alsoIgnored')
      result.should.have.length(1)
      result[0].should.eql({
        source: '*'
        condition:
          conditionType: 'HostWildcardCondition',
          pattern: '*'
        profileName: 'notmatch',
      })
    it 'should compose and parse conditions with results', ->
      rules = [{
        source: 'b.example.com'
        condition:
          conditionType: 'HostWildcardCondition',
          pattern: 'b.example.com'
        profileName: 'abc'
      }, {
        source: 'a.example.org'
        condition:
          conditionType: 'HostWildcardCondition',
          pattern: 'a.example.org'
        profileName: 'def'
      }]
      list = compose(
        {rules: rules, defaultProfileName: 'ghi'}
        {withResult: true}
      )
      result = parse(list, 'ignored', 'alsoIgnored')
      rules.push({
        source: '*'
        condition:
          conditionType: 'HostWildcardCondition',
          pattern: '*'
        profileName: 'ghi',
      })
      result.should.eql(rules)
    it 'should compose and parse exclusive conditions with results', ->
      rules = [{
        source: '!b.example.com'
        condition:
          conditionType: 'HostWildcardCondition',
          pattern: 'b.example.com'
        profileName: 'default profile'
      }, {
        source: 'a.example.org'
        condition:
          conditionType: 'HostWildcardCondition',
          pattern: 'a.example.org'
        profileName: 'some profile'
      }]
      list = compose(
        {rules: rules, defaultProfileName: 'default profile'}
        {withResult: true, useExclusive: true}
      )
      result = parse(list, 'ignored', 'alsoIgnored')
      rules.push({
        source: '*'
        condition:
          conditionType: 'HostWildcardCondition',
          pattern: '*'
        profileName: 'default profile',
      })
      result.should.eql(rules)
