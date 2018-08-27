OmegaTarget = require('omega-target')
Promise = OmegaTarget.Promise
ProxyAuth = require('./proxy_auth')

class ProxyImpl
  constructor: (log) ->
    @log = log
  @isSupported: -> false
  applyProfile: (profile, meta) -> Promise.reject()
  watchProxyChange: (callback) -> null
  parseExternalProfile: (details, options) -> null
  _profileNotFound: (name) ->
    @log.error("Profile #{name} not found! Things may go very, very wrong.")
    return OmegaPac.Profiles.create({
      name: name
      profileType: 'VirtualProfile'
      defaultProfileName: 'direct'
    })
  setProxyAuth: (profile, options) ->
    return Promise.try(=>
      @_proxyAuth ?= new ProxyAuth(@log)
      @_proxyAuth.listen()
      referenced_profiles = []
      ref_set = OmegaPac.Profiles.allReferenceSet(profile,
        options, profileNotFound: @_profileNotFound.bind(this))
      for own _, name of ref_set
        profile = OmegaPac.Profiles.byName(name, options)
        if profile
          referenced_profiles.push(profile)
      @_proxyAuth.setProxies(referenced_profiles)
    )
  getProfilePacScript: (profile, meta, options) ->
    meta ?= profile
    ast = OmegaPac.PacGenerator.script(options, profile,
      profileNotFound: @_profileNotFound.bind(this))
    ast = OmegaPac.PacGenerator.compress(ast)
    script = OmegaPac.PacGenerator.ascii(ast.print_to_string())
    profileName = OmegaPac.PacGenerator.ascii(JSON.stringify(meta.name))
    profileName = profileName.replace(/\*/g, '\\u002a')
    profileName = profileName.replace(/\\/g, '\\u002f')
    prefix = "/*OmegaProfile*#{profileName}*#{meta.revision}*/"
    return prefix + script

module.exports = ProxyImpl
