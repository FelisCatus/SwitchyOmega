chai = require 'chai'
should = chai.should()

describe 'RuleList', ->
  RuleList = require '../src/rule_list'
  describe 'AutoProxy', ->
    parse = RuleList['AutoProxy']
    it 'should parse keyword conditions', ->
      result = parse('example.com', 'match', 'notmatch')
      result.should.have.length(1)
      result[0].should.eql(
        profileName: 'match'
        condition:
          conditionType: 'KeywordCondition'
          pattern: 'example.com'
      )
    it 'should parse keyword conditions with asterisks', ->
      result = parse('example*.com', 'match', 'notmatch')
      result.should.have.length(1)
      result[0].should.eql(
        profileName: 'match'
        condition:
          conditionType: 'UrlWildcardCondition'
          pattern: 'http://*example*.com*'
      )
    it 'should parse host conditions', ->
      result = parse('||example.com', 'match', 'notmatch')
      result.should.have.length(1)
      result[0].should.eql(
        profileName: 'match'
        condition:
          conditionType: 'HostWildcardCondition'
          pattern: '*.example.com'
      )
    it 'should parse "starts-with" conditions', ->
      result = parse('|https://ssl.example.com', 'match', 'notmatch')
      result.should.have.length(1)
      result[0].should.eql(
        profileName: 'match'
        condition:
          conditionType: 'UrlWildcardCondition'
          pattern: 'https://ssl.example.com*'
      )
    it 'should parse "starts-with" conditions for the HTTP scheme', ->
      result = parse('|http://example.com', 'match', 'notmatch')
      result.should.have.length(1)
      result[0].should.eql(
        profileName: 'match'
        condition:
          conditionType: 'UrlWildcardCondition'
          pattern: 'http://example.com*'
      )
    it 'should parse url regex conditions', ->
      result = parse('/^https?:\\/\\/[^\\/]+example\.com/', 'match', 'notmatch')
      result.should.have.length(1)
      result[0].should.eql(
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
        profileName: 'match'
        condition:
          conditionType: 'KeywordCondition'
          pattern: 'example.com'
      )
      result[1].should.eql(
        profileName: 'match'
        condition:
          conditionType: 'HostWildcardCondition'
          pattern: '*.example.com'
      )
    it 'should put exclusive rules first', ->
      result = parse 'example.com\n@@||example.com', 'match', 'notmatch'
      result.should.have.length(2)
      result[0].should.eql(
        profileName: 'notmatch'
        condition:
          conditionType: 'HostWildcardCondition'
          pattern: '*.example.com'
      )
      result[1].should.eql(
        profileName: 'match'
        condition:
          conditionType: 'KeywordCondition'
          pattern: 'example.com'
      )

  describe 'Switchy', ->
    parse = RuleList['Switchy']
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
        profileName: 'notmatch'
        condition:
          conditionType: 'UrlRegexCondition'
          pattern: '^http://www\.example\.com/.*'
      )
    it 'should parse multiple rules in multiple sections', ->
      list = compose {
        'Wildcard': [
          'http://www\.example\.com/*'
          'http://example\.com/*'
        ]
        'RegExp': [
          '^http://www\.example\.com/.*'
          '^http://example\.com/.*'
        ]
      }
      result = parse(list, 'match', 'notmatch')
      result.should.have.length(4)
      result[0].should.eql(
        profileName: 'match'
        condition:
          conditionType: 'UrlWildcardCondition'
          pattern: 'http://www.example.com/*'
      )
      result[1].should.eql(
        profileName: 'match'
        condition:
          conditionType: 'UrlWildcardCondition'
          pattern: 'http://example.com/*'
      )
      result[2].should.eql(
        profileName: 'match'
        condition:
          conditionType: 'UrlRegexCondition'
          pattern: '^http://www\.example\.com/.*'
      )
      result[3].should.eql(
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
        profileName: 'notmatch'
        condition:
          conditionType: 'UrlRegexCondition'
          pattern: '^http://www.example\.com/.*'
      )
      result[1].should.eql(
        profileName: 'match'
        condition:
          conditionType: 'UrlWildcardCondition'
          pattern: 'http://www.example.com/*'
      )
