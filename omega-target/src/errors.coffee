class NetworkError extends Error
  constructor: (err) ->
    super
    this.cause = err
    this.name = 'NetworkError'

class HttpError extends NetworkError
  constructor: ->
    super
    this.statusCode = this.cause?.statusCode
    this.name = 'HttpError'

class HttpNotFoundError extends HttpError
  constructor: ->
    super
    this.name = 'HttpNotFoundError'

class HttpServerError extends HttpError
  constructor: ->
    super
    this.name = 'HttpServerError'

class ContentTypeRejectedError extends Error
  constructor: ->
    super
    this.name = 'ContentTypeRejectedError'

module.exports =
  NetworkError: NetworkError
  HttpError: HttpError
  HttpNotFoundError: HttpNotFoundError
  HttpServerError: HttpServerError
  ContentTypeRejectedError: ContentTypeRejectedError
