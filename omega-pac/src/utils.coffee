Revision =
  fromTime: (time) ->
    time = if time then new Date(time) else new Date()
    return time.getTime().toString(16)
  compare: (a, b) ->
    return 0 if not a and not b
    return -1 if not a
    return 1 if not b
    return 1 if a.length > b.length
    return -1 if a.length < b.length
    return 1 if a > b
    return -1 if a < b
    return 0

exports.Revision = Revision

class AttachedCache
  constructor: (opt_prop, @tag) ->
    @prop = opt_prop
    if typeof @tag == 'undefined'
      @tag = opt_prop
      @prop = '_cache'
  get: (obj, otherwise) ->
    tag = @tag(obj)
    cache = @_getCache(obj)
    if cache? and cache.tag == tag
      return cache.value
    value = if typeof otherwise == 'function' then otherwise() else otherwise
    @_setCache(obj, {tag: tag, value: value})
    return value
  drop: (obj) ->
    if obj[@prop]?
      obj[@prop] = undefined
  _getCache: (obj) -> obj[@prop]
  _setCache: (obj, value) ->
    if not Object::hasOwnProperty.call obj, @prop
      Object.defineProperty obj, @prop, writable: true
    obj[@prop] = value

exports.AttachedCache = AttachedCache

tld = require('tldjs')

exports.isIp = (domain) ->
  return true if domain.indexOf(':') > 0 # IPv6
  lastCharCode = domain.charCodeAt(domain.length - 1)
  return true if 48 <= lastCharCode <= 57 # IP address ending with number.
  return false

exports.getBaseDomain = (domain) ->
  return domain if exports.isIp(domain)
  return tld.getDomain(domain) ? domain

exports.wildcardForDomain = (domain) ->
  return domain if exports.isIp(domain)
  return '*.' + exports.getBaseDomain(domain)

Url = require('url')
exports.wildcardForUrl = (url) ->
  domain = Url.parse(url).hostname
  return exports.wildcardForDomain(domain)
