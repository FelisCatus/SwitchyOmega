chai = require 'chai'
should = chai.should()
Utils = require '../src/utils'

describe 'getBaseDomain', ->
  {getBaseDomain} = Utils
  it 'should return domains with zero level unchanged', ->
    getBaseDomain('someinternaldomain').should.equal('someinternaldomain')
  it 'should return domains with one level unchanged', ->
    getBaseDomain('example.com').should.equal('example.com')
    getBaseDomain('e.test').should.equal('e.test')
    getBaseDomain('a.b').should.equal('a.b')
  it 'should treat two-segment TLD as one component', ->
    getBaseDomain('images.google.co.uk').should.equal('google.co.uk')
    getBaseDomain('images.google.co.jp').should.equal('google.co.jp')
    getBaseDomain('example.com.cn').should.equal('example.com.cn')
  it 'should not mistake short domains with two-segment TLDs', ->
    getBaseDomain('a.bc.com').should.equal('bc.com')
    getBaseDomain('i.t.co').should.equal('t.co')
  it 'should not try to modify IP address literals', ->
    getBaseDomain('127.0.0.1').should.equal('127.0.0.1')
    getBaseDomain('[::1]').should.equal('[::1]')
    getBaseDomain('::f').should.equal('::f')
