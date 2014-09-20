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
        '*://example.com/*'
      ]
      result = parse(list, 'match', 'notmatch')
      result.should.have.length(1)
      result[0].should.eql(
        source: '*://example.com/*'
        profileName: 'match'
        condition:
          conditionType: 'UrlWildcardCondition'
          pattern: '*://example.com/*'
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
