chai = require 'chai'
should = chai.should()

describe 'ShexpUtils', ->
  ShexpUtils = require '../src/shexp_utils'
  describe '#escapeSlash', ->
    it 'should escape all forward slashes', ->
      regex = ShexpUtils.escapeSlash '/test/'
      regex.should.equal '\\/test\\/'
    it 'should not escape slashes that are already escaped', ->
      regex = ShexpUtils.escapeSlash '\\/test\\/'
      regex.should.equal '\\/test\\/'
    it 'should know the difference between escaped and unescaped slashes', ->
      regex = ShexpUtils.escapeSlash '\\\\/\\/test\\/'
      regex.should.equal '\\\\\\/\\/test\\/'
  describe '#shExp2RegExp', ->
    it 'should escape regex meta chars and back slashes', ->
      regex = ShexpUtils.shExp2RegExp 'this.is|a\\test+'
      regex.should.equal '^this\\.is\\|a\\\\test\\+$'
