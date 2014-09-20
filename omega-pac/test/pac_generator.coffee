chai = require 'chai'
should = chai.should()

describe 'PacGenerator', ->
  PacGenerator = require '../src/pac_generator.coffee'

  options =
    '+auto':
      name: 'auto'
      profileType: 'SwitchProfile'
      revision: 'test'
      defaultProfileName: 'direct'
      rules: [
        {profileName: 'proxy', condition:
          conditionType: 'UrlRegexCondition'
          pattern: '^http://(www|www2)\\.example\\.com/'
        }
        {profileName: 'direct', condition:
          conditionType: 'HostLevelsCondition'
          minValue: 3
          maxValue: 8
        }
        {
          profileName: 'proxy'
          condition: {conditionType: 'KeywordCondition', pattern: 'keyword'}
        }
        {profileName: 'proxy', condition:
          conditionType: 'UrlWildcardCondition'
          pattern: 'https://ssl.example.com/*'
        }
      ]
    '+proxy':
      name: 'proxy'
      profileType: 'FixedProfile'
      revision: 'test'
      fallbackProxy: {scheme: 'http', host: '127.0.0.1', port: 8888}
      bypassList: [
        {conditionType: 'BypassCondition', pattern: '127.0.0.1:8080'}
        {conditionType: 'BypassCondition', pattern: '127.0.0.1'}
        {conditionType: 'BypassCondition', pattern: '<local>'}
      ]

  it 'should generate pac scripts from options', ->
    ast = PacGenerator.script(options, 'auto')
    pac = ast.print_to_string(beautify: true, comments: true)
    pac.should.not.be.empty
    func = eval("(function () { #{pac}\n return FindProxyForURL; })()")
    result = func('http://www.example.com/', 'www.example.com')
    result.should.equal('PROXY 127.0.0.1:8888')
  it 'should be able to compress pac scripts', ->
    ast = PacGenerator.script(options, 'auto')
    pac = PacGenerator.compress(ast).print_to_string()
    pac.should.not.be.empty
    func = eval("(function () { #{pac}\n return FindProxyForURL; })()")
    result = func('http://www.example.com/', 'www.example.com')
    result.should.equal('PROXY 127.0.0.1:8888')
