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
  it 'should ignore the leading www with domains with two or more levels', ->
    getBaseDomain('www.example.com').should.equal('example.com')
    getBaseDomain('www.e.test').should.equal('e.test')
    getBaseDomain('www.a.b').should.equal('a.b')
  it 'should assume two-segment TLD if len(second segment from last) <= 2', ->
    getBaseDomain('images.google.co.uk').should.equal('google.co.uk')
    getBaseDomain('images.google.co.jp').should.equal('google.co.jp')
    getBaseDomain('ab.de.ef.test').should.equal('de.ef.test')
  it 'should assume one-segment TLD and keep two segments as base otherwise', ->
    getBaseDomain('subdomain.example.com').should.equal('example.com')
    getBaseDomain('some.site.example.net').should.equal('example.net')
    getBaseDomain('some.site.abc.test').should.equal('abc.test')
    getBaseDomain('ab.de.efg.test').should.equal('efg.test')
  it 'should not try to modify IP address literals', ->
    getBaseDomain('127.0.0.1').should.equal('127.0.0.1')
    getBaseDomain('[::1]').should.equal('[::1]')
    getBaseDomain('::f').should.equal('::f')
