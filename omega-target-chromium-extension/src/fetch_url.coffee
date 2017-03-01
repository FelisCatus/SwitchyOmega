Promise = OmegaTarget.Promise
xhr = Promise.promisify(require('xhr'))
Url = require('url')
ContentTypeRejectedError = OmegaTarget.ContentTypeRejectedError

xhrWrapper = (args...) ->
  xhr(args...).catch (err) ->
    throw err unless err.isOperational
    if not err.statusCode
      throw new OmegaTarget.NetworkError(err)
    if err.statusCode == 404
      throw new OmegaTarget.HttpNotFoundError(err)
    if err.statusCode >= 500 and err.statusCode < 600
      throw new OmegaTarget.HttpServerError(err)
    throw new OmegaTarget.HttpError(err)

fetchUrl = (dest_url, opt_bypass_cache, opt_type_hints) ->
  getResBody = ([response, body]) ->
    return body unless opt_type_hints
    contentType = response.headers['content-type']?.toLowerCase()
    for hint in opt_type_hints
      handler = hintHandlers[hint] ? defaultHintHandler
      result = handler(response, body, {contentType, hint})
      return result if result?
    throw new ContentTypeRejectedError(
      'Unrecognized Content-Type: ' + contentType)
    return body

  if opt_bypass_cache and dest_url.indexOf('?') < 0
    parsed = Url.parse(dest_url, true)
    parsed.search = undefined
    parsed.query['_'] = Date.now()
    dest_url_nocache = Url.format(parsed)
    # Try first with the dumb parameter to bypass cache.
    xhrWrapper(dest_url_nocache).then(getResBody).catch ->
      # If failed, try again with the original URL.
      xhrWrapper(dest_url).then(getResBody)
  else
    xhrWrapper(dest_url).then(getResBody)

defaultHintHandler = (response, body, {contentType, hint}) ->
  if '!' + contentType == hint
    throw new ContentTypeRejectedError(
      'Response Content-Type blacklisted: ' + contentType)
  if contentType == hint
    return body

hintHandlers =
  '*': (response, body) ->
    # Allow all contents.
    return body

  '!text/html': (response, body, {contentType, hint}) ->
    if contentType == hint
      # Sometimes other content can also be served with the text/html
      # Content-Type header. So we check if the body actually looks like HTML.
      looksLikeHtml = false
      if body.indexOf('<!DOCTYPE') >= 0 || body.indexOf('<!doctype') >= 0
        looksLikeHtml = true
      else if body.indexOf('</html>') >= 0
        looksLikeHtml = true
      else if body.indexOf('</body>') >= 0
        looksLikeHtml = true

      if looksLikeHtml
        throw new ContentTypeRejectedError('Response must not be HTML.')

  '!application/xhtml+xml': (args...) -> hintHandlers['!text/html'](args...)

  'application/x-ns-proxy-autoconfig': (response, body, {contentType, hint}) ->
    if contentType == hint
      return body
    # Sometimes PAC scripts can also be served using with wrong Content-Type.
    if body.indexOf('FindProxyForURL') >= 0
      return body
    else
      # The content is not a PAC script if it does not contain FindProxyForURL.
      return undefined

module.exports = fetchUrl
