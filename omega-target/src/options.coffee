### @module omega-target/options ###
Promise = require 'bluebird'
Log = require './log'
Storage = require './storage'
OmegaPac = require 'omega-pac'
jsondiffpatch = require 'jsondiffpatch'

class Options
  ###*
  # The entire set of options including profiles and other settings.
  # @typedef OmegaOptions
  # @type {object}
  ###

  ###*
  # All the options, in a map from key to value.
  # @type OmegaOptions
  ###
  _options: null
  _storage: null
  _state: null
  _currentProfileName: null
  _revertToProfileName: null
  _watchingProfiles: {}
  _tempProfile: null
  _tempProfileActive: false
  fallbackProfileName: 'system'
  _isSystem: false
  debugStr: 'Options'

  ready: null

  @ProfileNotExistError: class ProfileNotExistError extends Error
    constructor: (@profileName) ->
      super.constructor("Profile #{@profileName} does not exist!")

  @NoOptionsError:
    class NoOptionsError extends Error
      constructor: -> super

  ###*
  # Transform options values (especially profiles) for syncing.
  # @param {{}} value The value to transform
  # @param {{}} key The key of the options
  # @returns {{}} The transformed value
  ###
  @transformValueForSync: (value, key) ->
    if key[0] == '+'
      if OmegaPac.Profiles.updateUrl(value)
        profile = {}
        for k, v of value
          continue if k == 'lastUpdate' || k == 'ruleList' || k == 'pacScript'
          profile[k] = v
        value = profile
    return value

  constructor: (options, @_storage, @_state, @log, @sync) ->
    @_options = {}
    @_tempProfileRules = {}
    @_tempProfileRulesByProfile = {}
    @_storage ?= Storage()
    @_state ?= Storage()
    @log ?= Log
    if not options?
      @init()
    else
      @ready = @_storage.remove().then(=>
        @_storage.set(options)
      ).then =>
        @init()

  ###*
  # Attempt to load options from local and remote storage.
  # @param {?{}} args Extra arguments
  # @param {number=3} args.retry Number of retries before giving up.
  # @returns {Promise<OmegaOptions>} The loaded options
  ###
  loadOptions: ({retry} = {}) ->
    retry ?= 3
    @_syncWatchStop?()
    @_syncWatchStop = null
    @_watchStop?()
    @_watchStop = null

    loadRaw = if options? then Promise.resolve(options) else
      if not @sync?.enabled
        if not @sync?
          @_state.set({'syncOptions': 'unsupported'})
        @_storage.get(null)
      else
        @_state.set({'syncOptions': 'sync'})
        @_syncWatchStop = @sync.watchAndPull(@_storage)
        @sync.copyTo(@_storage).catch(Storage.StorageUnavailableError, =>
          console.error('Warning: Sync storage is not available in this ' +
            'browser! Disabling options sync.')
          @_syncWatchStop?()
          @_syncWatchStop = null
          @sync = null
          @_state.set({'syncOptions': 'unsupported'})
        ).then =>
          @_storage.get(null)

    @optionsLoaded = loadRaw.then((options) =>
      @upgrade(options)
    ).then(([options, changes]) =>
      @_storage.apply(changes: changes).return(options)
    ).tap((options) =>
      @_options = options
      @_watchStop = @_watch()
      # Try to set syncOptions to some value if not initialized.
      @_state.get({'syncOptions': ''}).then ({syncOptions}) =>
        return if syncOptions
        @_state.set({'syncOptions': 'conflict'})
        @sync.storage.get('schemaVersion').then ({schemaVersion}) =>
          @_state.set({'syncOptions': 'pristine'}) if not schemaVersion
    ).catch (e) =>
      return Promise.reject(e) unless retry > 0

      getFallbackOptions = Promise.resolve().then =>
        if e instanceof NoOptionsError
          @_state.get({
            'firstRun': 'new'
            'web.switchGuide': 'showOnFirstUse'
          }).then (items) => @_state.set(items)
          return null unless @sync?
          @_state.get({'syncOptions': ''}).then ({syncOptions}) =>
            return if syncOptions == 'conflict'
            # Try to fetch options from sync storage.
            return @sync.storage.get(null).then((options) =>
              if not options['schemaVersion']
                @_state.set({'syncOptions': 'pristine'})
                return null
              else
                @_state.set({'syncOptions': 'sync'})
                @sync.enabled = true
                @log.log('Options#loadOptions::fromSync', options)
                options
            ).catch(-> null)
        else
          @log.error(e.stack)
          # Some serious error happened when loading options. Disable syncing
          # and use fallback options.
          @_state.remove(['syncOptions'])
          return null

      getFallbackOptions.then (options) =>
        options ?= @parseOptions(@getDefaultOptions())
        if @sync?
          prevEnabled = @sync.enabled
          @sync.enabled = false
        @_storage.remove().then(=>
          @_storage.set(options)
        ).then =>
          @sync.enabled = prevEnabled if @sync?
          @loadOptions({retry: retry - 1})

  ###*
  # Attempt to initialize (or reinitialize) options.
  # @returns {Promise<OmegaOptions>} A promise that is fulfilled on ready.
  ###
  init: ->
    @ready = @loadOptions().then(=>
      if @_options['-startupProfileName']
        @applyProfile(@_options['-startupProfileName'])
      else
        @_state.get({
          'currentProfileName': @fallbackProfileName
          'isSystemProfile': false
        }).then (st) =>
          if st['isSystemProfile']
            @applyProfile('system')
          else
            @applyProfile(st['currentProfileName'] || @fallbackProfileName)
    ).catch((err) =>
      if not err instanceof ProfileNotExistError
        @log.error(err)
      @applyProfile(@fallbackProfileName)
    ).catch((err) =>
      @log.error(err)
    ).then => @getAll()

    @ready.then =>
      @sync.requestPush(@_options) if @sync?.enabled

      @_state.get({'firstRun': ''}).then ({firstRun}) =>
        @onFirstRun(firstRun) if firstRun

      if @_options['-downloadInterval'] > 0
        @updateProfile()

    return @ready

  toString: -> "<Options>"

  ###*
  # Return a localized, human-readable description of the given profile.
  # In base class, this method is not implemented and will always return null.
  # @param {?{}} profile The profile to print
  # @returns {string} Description of the profile with details
  ###
  printProfile: (profile) -> null

  ###*
  # Upgrade options from previous versions.
  # For now, this method only supports schemaVersion 1 and 2. If so, it upgrades
  # the options to version 2 (the latest version). Otherwise it rejects.
  # It is recommended for the derived classes to call super() two times in the
  # beginning and in the end of the implementation to check the schemaVersion
  # and to apply future upgrades, respectively.
  # Example: super(options).catch -> super(doCustomUpgrades(options), changes)
  # @param {?OmegaOptions} options The legacy options to upgrade
  # @param {{}={}} changes Previous pending changes to be applied. Default to
  # an empty dictionary. Please provide this argument when calling super().
  # @returns {Promise<[OmegaOptions, {}]>} The new options and the changes.
  ###
  upgrade: (options, changes) ->
    changes ?= {}
    version = options?['schemaVersion']
    if version == 1
      autoDetectUsed = false
      OmegaPac.Profiles.each options, (key, profile) ->
        if not autoDetectUsed
          refs = OmegaPac.Profiles.directReferenceSet(profile)
          if refs['+auto_detect']
            autoDetectUsed = true
      if autoDetectUsed
        options['+auto_detect'] = OmegaPac.Profiles.create(
          name: 'auto_detect'
          profileType: 'PacProfile'
          pacUrl: 'http://wpad/wpad.dat'
          color: '#00cccc'
        )
      version = changes['schemaVersion'] = options['schemaVersion'] = 2
    if version == 2
      # Current schemaVersion.
      Promise.resolve([options, changes])
    else
      Promise.reject new Error("Invalid schemaVerion #{version}!")

  ###*
  # Parse options in various formats (including JSON & base64).
  # @param {OmegaOptions|string} options The options to parse
  # @returns {Promise<OmegaOptions>} The parsed options.
  ###
  parseOptions: (options) ->
    if typeof options == 'string'
      if options[0] != '{'
        try
          Buffer = require('buffer').Buffer
          options = new Buffer(options, 'base64').toString('utf8')
        catch
          options = null
      options = try JSON.parse(options)
    if not options
      return throw new Error('Invalid options!')

    return options

  ###*
  # Reset the options to the given options or initial options.
  # @param {?OmegaOptions} options The options to set. Defaults to initial.
  # @returns {Promise<OmegaOptions>} The options just applied
  ###
  reset: (options) ->
    @log.method('Options#reset', this, arguments)
    options ?= @getDefaultOptions()
    @upgrade(@parseOptions(options)).then ([opt]) =>
      # Disable syncing when resetting to avoid affecting sync storage.
      @sync.enabled = false if @sync?
      @_state.remove(['syncOptions'])
      @_storage.remove().then(=>
        @_storage.set(opt)
      ).then =>
        @init()

  ###*
  # Called on the first initialization of options.
  # @param {reason} reason The value of 'firstRun' in state.
  ###
  onFirstRun: (reason) -> null

  ###*
  # Return the default options used initially and on resets.
  # @returns {?OmegaOptions} The default options.
  ###
  getDefaultOptions: -> require('./default_options')()

  ###*
  # Return all options.
  # @returns {?OmegaOptions} The options.
  ###
  getAll: -> @_options

  ###*
  # Get profile by name.
  # @returns {?{}} The profile, or undefined if no such profile.
  ###
  profile: (name) -> OmegaPac.Profiles.byName(name, @_options)

  ###*
  # Apply the patch to the current options.
  # @param {jsondiffpatch} patch The patch to apply
  # @returns {Promise<OmegaOptions>} The updated options
  ###
  patch: (patch) ->
    return unless patch
    @log.method('Options#patch', this, arguments)
    
    @_options = jsondiffpatch.patch(@_options, patch)
    # Only set the keys whose values have changed.
    changes = {}
    for own key, delta of patch
      if delta.length == 3 and delta[1] == 0 and delta[2] == 0
        # [previousValue, 0, 0] indicates that the key was removed.
        changes[key] = undefined
      else
        changes[key] = @_options[key]

    @_setOptions(changes)

  _setOptions: (changes, args) =>
    removed = []
    checkRev = args?.checkRevision ? false
    profilesChanged = false
    currentProfileAffected = false
    for own key, value of changes
      if typeof value == 'undefined'
        delete @_options[key]
        removed.push(key)
        if key[0] == '+'
          profilesChanged = true
          if key == '+' + @_currentProfileName
            currentProfileAffected = 'removed'
      else
        if key[0] == '+'
          if checkRev and @_options[key]
            result = OmegaPac.Revision.compare(@_options[key].revision,
              value.revision)
            continue if result >= 0
          profilesChanged = true
        @_options[key] = value
      if not currentProfileAffected and @_watchingProfiles[key]
        currentProfileAffected = 'changed'
    switch currentProfileAffected
      when 'removed'
        @applyProfile(@fallbackProfileName)
      when 'changed'
        @applyProfile(@_currentProfileName, update: false)
      else
        @_setAvailableProfiles() if profilesChanged
    if args?.persist ? true
      @sync?.requestPush(changes) if @sync?.enabled
      for key in removed
        delete changes[key]
      @_storage.set(changes).then =>
        @_storage.remove(removed)
        return @_options

  _watch: ->
    handler = (changes) =>
      if changes
        @_setOptions(changes, {checkRevision: true, persist: false})
      else
        # Initial update.
        changes = @_options

      refresh = changes['-refreshOnProfileChange']
      if refresh?
        @_state.set({'refreshOnProfileChange': refresh})

      showExternal = changes['-showExternalProfile']
      if not showExternal?
        showExternal = true
        @_setOptions({'-showExternalProfile': true}, {persist: true})
      @_state.set({'showExternalProfile': showExternal})

      if changes['-enableQuickSwitch']? or changes['-quickSwitchProfiles']?
        @reloadQuickSwitch()
      if changes['-downloadInterval']?
        @schedule 'updateProfile', @_options['-downloadInterval'], =>
          @updateProfile()
      if changes['-showInspectMenu']? or changes == @_options
        showMenu = @_options['-showInspectMenu']
        if not showMenu?
          showMenu = true
          @_setOptions({'-showInspectMenu': true}, {persist: true})
        @setInspect(showMenu: showMenu)
      if changes['-monitorWebRequests']? or changes == @_options
        monitorWebRequests = @_options['-monitorWebRequests']
        if not monitorWebRequests?
          monitorWebRequests = true
          @_setOptions({'-monitorWebRequests': true}, {persist: true})
        @setMonitorWebRequests(monitorWebRequests)

    handler()
    @_storage.watch null, handler

  ###*
  # Reload the quick switch according to settings.
  # @returns {Promise} A promise which is fulfilled when the quick switch is set
  ###
  reloadQuickSwitch: ->
    profiles = @_options['-quickSwitchProfiles']
    profiles = null if profiles.length < 2
    if @_options['-enableQuickSwitch']
      @setQuickSwitch(profiles, !!profiles)
    else
      @setQuickSwitch(null, !!profiles)

  ###*
  # Apply the settings related to element proxy inspection.
  # In base class, this method is not implemented and will not do anything.
  # @param {{}} settings
  # @param {boolean} settings.showMenu Whether to show the menu or not
  # @returns {Promise} A promise which is fulfilled when the settings apply
  ###
  setInspect: -> Promise.resolve()

  ###*
  # Apply the settings related to web request monitoring.
  # In base class, this method is not implemented and will not do anything.
  # @param {boolean} enabled Whether network shall be monitored or not
  # @returns {Promise} A promise which is fulfilled when the settings apply
  ###
  setMonitorWebRequests: -> Promise.resolve()

  ###*
  # @callback watchCallback
  # @param {Object.<string, {}>} changes A map from keys to values.
  ###

  ###*
  # Watch for any changes to the options
  # @param {watchCallback} callback Called everytime the value of a key changes
  # @returns {function} Calling the returned function will stop watching.
  ###
  watch: (callback) -> @_storage.watch null, callback

  _profileNotFound: (name) ->
    @log.error("Profile #{name} not found! Things may go very, very wrong.")
    return OmegaPac.Profiles.create({
      name: name
      profileType: 'VirtualProfile'
      defaultProfileName: 'direct'
    })

  ###*
  # Get PAC script for profile.
  # @param {?string|Object} profile The name of the profile, or the profile.
  # @param {bool=false} compress Compress the script if true.
  # @returns {string} The compiled
  ###
  pacForProfile: (profile, compress = false) ->
    ast = OmegaPac.PacGenerator.script(@_options, profile,
      profileNotFound: @_profileNotFound.bind(this))
    if compress
      ast = OmegaPac.PacGenerator.compress(ast)
    Promise.resolve OmegaPac.PacGenerator.ascii(ast.print_to_string())

  _setAvailableProfiles: ->
    profile = if @_currentProfileName then @currentProfile() else null
    profiles = {}
    currentIncludable = profile && OmegaPac.Profiles.isIncludable(profile)
    allReferenceSet = null
    if not profile or not OmegaPac.Profiles.isInclusive(profile)
      results = []
    OmegaPac.Profiles.each @_options, (key, p) =>
      profiles[key] =
        name: p.name
        profileType: p.profileType
        color: p.color
        desc: @printProfile(p)
        builtin: if p.builtin then true
      if p.profileType == 'VirtualProfile'
        profiles[key].defaultProfileName = p.defaultProfileName
        if not allReferenceSet?
          allReferenceSet =
            if profile
              OmegaPac.Profiles.allReferenceSet(profile, @_options,
                profileNotFound: @_profileNotFound.bind(this))
            else
              {}
        if allReferenceSet[key]
          profiles[key].validResultProfiles =
            OmegaPac.Profiles.validResultProfilesFor(p, @_options)
              .map (result) -> result.name
      if currentIncludable and OmegaPac.Profiles.isIncludable(p)
        results?.push(p.name)
    if profile and OmegaPac.Profiles.isInclusive(profile)
      results = OmegaPac.Profiles.validResultProfilesFor(profile, @_options)
      results = results.map (profile) -> profile.name
    @_state.set({
      'availableProfiles': profiles
      'validResultProfiles': results
    })

  ###*
  # Apply the profile by name.
  # @param {?string} name The name of the profile, or null for default.
  # @param {?{}} options Some options
  # @param {bool=true} options.proxy Set proxy for the applied profile if true
  # @param {bool=true} options.update Try to update this profile and referenced
  # profiles after the proxy is set.
  # @param {bool=false} options.system Whether options is in system mode.
  # @param {{}=undefined} options.reason will be passed to currentProfileChanged
  # @returns {Promise} A promise which is fulfilled when the profile is applied.
  ###
  applyProfile: (name, options) ->
    @log.method('Options#applyProfile', this, arguments)
    profile = OmegaPac.Profiles.byName(name, @_options)
    if not profile
      return Promise.reject new ProfileNotExistError(name)

    @_currentProfileName = profile.name
    @_isSystem = options?.system || (profile.profileType == 'SystemProfile')
    @_watchingProfiles = OmegaPac.Profiles.allReferenceSet(profile, @_options,
      profileNotFound: @_profileNotFound.bind(this))

    @_state.set({
      'currentProfileName': @_currentProfileName
      'isSystemProfile': @_isSystem
      'currentProfileCanAddRule':
        profile.rules? and profile.profileType != 'VirtualProfile'
    })
    @_setAvailableProfiles()

    @currentProfileChanged(options?.reason)
    if options? and options.proxy == false
      return Promise.resolve()
    @_tempProfileActive = false
    if @_tempProfile? and OmegaPac.Profiles.isIncludable(profile)
      @_tempProfileActive = true
      if @_tempProfile.defaultProfileName != profile.name
        @_tempProfile.defaultProfileName = profile.name
        @_tempProfile.color = profile.color
        OmegaPac.Profiles.updateRevision(@_tempProfile)

      removedKeys = []
      for own key, list of @_tempProfileRulesByProfile
        if not OmegaPac.Profiles.byKey(key, @_options)
          removedKeys.push(key)
          for rule in list
            rule.profileName = null
            @_tempProfile.rules.splice(@_tempProfile.rules.indexOf(rule), 1)
      if removedKeys.length > 0
        for key in removedKeys
          delete @_tempProfileRulesByProfile[key]
        OmegaPac.Profiles.updateRevision(@_tempProfile)

      @_watchingProfiles = OmegaPac.Profiles.allReferenceSet(@_tempProfile,
        @_options, profileNotFound: @_profileNotFound.bind(this))
      applyProxy = @applyProfileProxy(@_tempProfile, profile)
    else
      applyProxy = @applyProfileProxy(profile)

    return applyProxy if options? and options.update == false

    applyProxy.then =>
      return unless @_options['-downloadInterval'] > 0
      return unless @_currentProfileName == profile.name
      updateProfiles = []
      for key, name of @_watchingProfiles
        updateProfiles.push(name)
      if updateProfiles.length > 0
        @updateProfile(updateProfiles)
    return applyProxy

  ###*
  # Get the current applied profile.
  # @returns {{}} The current profile
  ###
  currentProfile: ->
    if @_currentProfileName
      OmegaPac.Profiles.byName(@_currentProfileName, @_options)
    else
      @_externalProfile

  ###*
  # Return true if in system mode.
  # @returns {boolean} True if system mode is activated
  ###
  isSystem: -> @_isSystem

  ###*
  # Set proxy settings based on the given profile.
  # In base class, this method is not implemented and will always reject.
  # @param {{}} profile The profile to apply
  # @param {{}=profile} meta The metadata of the profile, like name and revision
  # @returns {Promise} A promise which is fulfilled when the proxy is set.
  ###
  applyProfileProxy: (profile, meta) ->
    Promise.reject new Error('not implemented')

  ###*
  # Called when current profile has changed.
  # In base class, this method is not implemented and will not do anything.
  ###
  currentProfileChanged: -> null

  ###*
  # Set or disable the quick switch profiles.
  # In base class, this method is not implemented and will not do anything.
  # @param {string[]|null} quickSwitch The profile names, or null to disable
  # @param {boolean} canEnable Whether user can enable quick switch or not.
  # @returns {Promise} A promise which is fulfilled when the quick switch is set
  ###
  setQuickSwitch: (quickSwitch, canEnable) ->
    Promise.resolve()

  ###*
  # Schedule a task that runs every periodInMinutes.
  # In base class, this method is not implemented and will not do anything.
  # @param {string} name The name of the schedule. If there is a previous
  # schedule with the same name, it will be replaced by the new one.
  # @param {number} periodInMinutes The interval of the schedule
  # @param {function} callback The callback to call when the task runs
  # @returns {Promise} A promise which is fulfilled when the schedule is set
  ###
  schedule: (name, periodInMinutes, callback) ->
    Promise.resolve()

  ###*
  # Return true if the match result of current profile does not change with URLs
  # @returns {bool} Whether @match always return the same result for requests
  ###
  isCurrentProfileStatic: ->
    return true if not @_currentProfileName
    return false if @_tempProfileActive
    currentProfile = @currentProfile()
    return false if OmegaPac.Profiles.isInclusive(currentProfile)
    return true

  ###*
  # Update the profile by name.
  # @param {(string|string[]|null)} name The name of the profiles,
  # or null for all.
  # @param {?bool} opt_bypass_cache Do not read from the cache if true
  # @returns {Promise<Object.<string,({}|Error)>>} A map from keys to updated
  # profiles or errors.
  # A value is an error if `value instanceof Error`. Otherwise the value is an
  # updated profile.
  ###
  updateProfile: (name, opt_bypass_cache) ->
    @log.method('Options#updateProfile', this, arguments)
    results = {}
    OmegaPac.Profiles.each @_options, (key, profile) =>
      if name?
        if Array.isArray(name)
          return unless name.indexOf(profile.name) >= 0
        else
          return unless profile.name == name
      url = OmegaPac.Profiles.updateUrl(profile)
      if url
        type_hints = OmegaPac.Profiles.updateContentTypeHints(profile)
        fetchResult = @fetchUrl(url, opt_bypass_cache, type_hints)
        results[key] = fetchResult.then((data) =>
          # Errors and unsuccessful response codes shoud have been already
          # rejected by fetchUrl and will not end up here.
          # So empty data indicates success without any update (e.g. 304).
          return profile unless data
          profile = OmegaPac.Profiles.byKey(key, @_options)
          profile.lastUpdate = new Date().toISOString()
          if OmegaPac.Profiles.update(profile, data)
            OmegaPac.Profiles.dropCache(profile)
            changes = {}
            changes[key] = profile
            @_setOptions(changes).return(profile)
          else
            return profile
        ).catch (reason) ->
          if reason instanceof Error then reason else new Error(reason)

    Promise.props(results)

  ###*
  # Make an HTTP GET request to fetch the content of the url.
  # In base class, this method is not implemented and will always reject.
  # @param {string} url The name of the profiles,
  # @param {?bool} opt_bypass_cache Do not read from the cache if true
  # @param {?string} opt_type_hints MIME type hints for downloaded content.
  # @returns {Promise<String>} The text content fetched from the url
  ###
  fetchUrl: (url, opt_bypass_cache, opt_type_hints) ->
    Promise.reject new Error('not implemented')

  _replaceRefChanges: (fromName, toName, changes) ->
    changes ?= {}

    OmegaPac.Profiles.each @_options, (key, p) ->
      return if p.name == fromName or p.name == toName
      if OmegaPac.Profiles.replaceRef(p, fromName, toName)
        OmegaPac.Profiles.updateRevision(p)
        changes[OmegaPac.Profiles.nameAsKey(p)] = p

    if @_options['-startupProfileName'] == fromName
      changes['-startupProfileName'] = toName
    quickSwitch = @_options['-quickSwitchProfiles']
    for i in [0...quickSwitch.length]
      if quickSwitch[i] == fromName
        quickSwitch[i] = toName
        changes['-quickSwitchProfiles'] = quickSwitch

    return changes

  ###*
  # Replace all references of profile fromName to toName.
  # @param {String} fromName The original profile name
  # @param {String} toname The target profile name
  # @returns {Promise<OmegaOptions>} The updated options
  ###
  replaceRef: (fromName, toName) ->
    @log.method('Options#replaceRef', this, arguments)
    profile = OmegaPac.Profiles.byName(fromName, @_options)
    if not profile
      return Promise.reject new ProfileNotExistError(fromName)

    changes = @_replaceRefChanges(fromName, toName)
    for own key, value of changes
      @_options[key] = value

    fromKey = OmegaPac.Profiles.nameAsKey(fromName)
    if @_watchingProfiles[fromKey]
      if @_currentProfileName == fromName
        @_currentProfileName = toName
      @applyProfile(@_currentProfileName)

    @_setOptions(changes)

  ###*
  # Rename a profile and update references and options
  # @param {String} fromName The original profile name
  # @param {String} toname The target profile name
  # @returns {Promise<OmegaOptions>} The updated options
  ###
  renameProfile: (fromName, toName) ->
    @log.method('Options#renameProfile', this, arguments)
    if OmegaPac.Profiles.byName(toName, @_options)
      return Promise.reject new Error("Target name #{name} already taken!")
    profile = OmegaPac.Profiles.byName(fromName, @_options)
    if not profile
      return Promise.reject new ProfileNotExistError(fromName)

    profile.name = toName
    changes = {}
    changes[OmegaPac.Profiles.nameAsKey(profile)] = profile

    @_replaceRefChanges(fromName, toName, changes)
    for own key, value of changes
      @_options[key] = value

    fromKey = OmegaPac.Profiles.nameAsKey(fromName)
    changes[fromKey] = undefined
    delete @_options[fromKey]

    if @_watchingProfiles[fromKey]
      if @_currentProfileName == fromName
        @_currentProfileName = toName
      @applyProfile(@_currentProfileName)

    @_setOptions(changes)

  ###*
  # Add a temp rule.
  # @param {String} domain The domain for the temp rule.
  # @param {String} profileName The profile to apply for the domain.
  # @returns {Promise} A promise which is fulfilled when the rule is applied.
  ###
  addTempRule: (domain, profileName) ->
    @log.method('Options#addTempRule', this, arguments)
    return Promise.resolve() if not @_currentProfileName
    profile = OmegaPac.Profiles.byName(profileName, @_options)
    if not profile
      return Promise.reject new ProfileNotExistError(profileName)
    if not @_tempProfile?
      @_tempProfile = OmegaPac.Profiles.create('', 'SwitchProfile')
      currentProfile = @currentProfile()
      @_tempProfile.color = currentProfile.color
      @_tempProfile.defaultProfileName = currentProfile.name
    
    changed = false
    rule = @_tempProfileRules[domain]
    if rule and rule.profileName
      if rule.profileName != profileName
        key = OmegaPac.Profiles.nameAsKey(rule.profileName)
        list = @_tempProfileRulesByProfile[key]
        list.splice(list.indexOf(rule), 1)

        rule.profileName = profileName
        changed = true
    else
      rule =
        condition:
          conditionType: 'HostWildcardCondition'
          pattern: '*.' + domain
        profileName: profileName
        isTempRule: true
      @_tempProfile.rules.push(rule)
      @_tempProfileRules[domain] = rule
      changed = true

    key = OmegaPac.Profiles.nameAsKey(profileName)
    rulesByProfile = @_tempProfileRulesByProfile[key]
    if not rulesByProfile?
      rulesByProfile = @_tempProfileRulesByProfile[key] = []
    rulesByProfile.push(rule)

    if changed
      OmegaPac.Profiles.updateRevision(@_tempProfile)
      @applyProfile(@_currentProfileName)
    else
      Promise.resolve()

  ###*
  # Find a temp rule by domain.
  # @param {String} domain The domain of the temp rule.
  # @returns {Promise<?String>} The profile name for the domain, or null if such
  # rule does not exist.
  ###
  queryTempRule: (domain) ->
    rule = @_tempProfileRules[domain]
    if rule
      if rule.profileName
        return rule.profileName
      else
        delete @_tempProfileRules[domain]
    return null

  ###*
  # Add a condition to the current active switch profile.
  # @param {Object.<String,{}>} cond The condition to add
  # @param {string>} profileName The name of the result profile of the rule.
  # @returns {Promise} A promise which is fulfilled when the condition is saved.
  ###
  addCondition: (condition, profileName) ->
    @log.method('Options#addCondition', this, arguments)
    return Promise.resolve() if not @_currentProfileName
    profile = OmegaPac.Profiles.byName(@_currentProfileName, @_options)
    if not profile?.rules?
      return Promise.reject new Error(
        "Cannot add condition to Profile #{@profile.name} (#{profile.type})")
    target = OmegaPac.Profiles.byName(profileName, @_options)
    if not target?
      return Promise.reject new ProfileNotExistError(profileName)
    if not Array.isArray(condition)
      condition = [condition]

    for cond in condition
      # Try to remove rules with the same condition first.
      tag = OmegaPac.Conditions.tag(cond)
      for i in [0...profile.rules.length]
        if OmegaPac.Conditions.tag(profile.rules[i].condition) == tag
          profile.rules.splice(i, 1)
          break


      if @_options['-addConditionsToBottom']
        profile.rules.push({
          condition: cond
          profileName: profileName
        })
      else
        profile.rules.unshift({
          condition: cond
          profileName: profileName
        })

    OmegaPac.Profiles.updateRevision(profile)
    changes = {}
    changes[OmegaPac.Profiles.nameAsKey(profile)] = profile
    @_setOptions(changes)

  ###*
  # Set the defaultProfileName of the profile.
  # @param {string>} profileName The name of the profile to modify.
  # @param {string>} defaultProfileName The defaultProfileName to set.
  # @returns {Promise} A promise which is fulfilled when the profile is saved.
  ###
  setDefaultProfile: (profileName, defaultProfileName) ->
    @log.method('Options#setDefaultProfile', this, arguments)
    profile = OmegaPac.Profiles.byName(profileName, @_options)
    if not profile?
      return Promise.reject new ProfileNotExistError(profileName)
    else if not profile.defaultProfileName?
      return Promise.reject new Error("Profile #{@profile.name} " +
        "(@{profile.type}) does not have defaultProfileName!")
    target = OmegaPac.Profiles.byName(defaultProfileName, @_options)
    if not target?
      return Promise.reject new ProfileNotExistError(defaultProfileName)

    profile.defaultProfileName = defaultProfileName
    OmegaPac.Profiles.updateRevision(profile)
    changes = {}
    changes[OmegaPac.Profiles.nameAsKey(profile)] = profile
    @_setOptions(changes)

  ###*
  # Add a profile to the options
  # @param {{}} profile The profile to create
  # @returns {Promise<{}>} The saved profile
  ###
  addProfile: (profile) ->
    @log.method('Options#addProfile', this, arguments)
    if OmegaPac.Profiles.byName(profile.name, @_options)
      return Promise.reject(
        new Error("Target name #{profile.name} already taken!"))
    else
      changes = {}
      changes[OmegaPac.Profiles.nameAsKey(profile)] = profile
      @_setOptions(changes)

  ###*
  # Get the matching results of a request
  # @param {{}} request The request to test
  # @returns {Promise<{profile: {}, results: {}[]}>} The last matched profile
  # and the matching details
  ###
  matchProfile: (request) ->
    if not @_currentProfileName
      return Promise.resolve({profile: @_externalProfile, results: []})
    results = []
    profile =
      if @_tempProfileActive
        @_tempProfile
      else
        OmegaPac.Profiles.byName(@_currentProfileName, @_options)
    while profile
      lastProfile = profile
      result = OmegaPac.Profiles.match(profile, request)
      break unless result?
      results.push(result)
      if Array.isArray(result)
        next = result[0]
      else if result.profileName
        next = OmegaPac.Profiles.nameAsKey(result.profileName)
      else
        break
      profile = OmegaPac.Profiles.byKey(next, @_options)
    Promise.resolve(profile: lastProfile, results: results)

  ###*
  # Notify Options that the proxy settings are set externally.
  # @param {{}} profile The external profile
  # @param {?{}} args Extra arguments
  # @param {boolean=false} args.noRevert If true, do not revert changes.
  # @param {boolean=false} args.internal If true, treat the profile change as
  # caused by the options itself instead of external reasons.
  # @returns {Promise} A promise which is fulfilled when the profile is set
  ###
  setExternalProfile: (profile, args) ->
    if @_options['-revertProxyChanges'] and not @_isSystem
      if profile.name != @_currentProfileName and @_currentProfileName
        if not args?.noRevert
          @applyProfile(@_revertToProfileName)
          @_revertToProfileName = null
          return
        else
          @_revertToProfileName ?= @_currentProfileName
    p = OmegaPac.Profiles.byName(profile.name, @_options)
    if p
      if args?.internal
        @applyProfile(p.name, {proxy: false})
      else
        @applyProfile(p.name,
          {proxy: false, system: @_isSystem, reason: 'external'})
    else
      @_currentProfileName = null
      @_externalProfile = profile
      profile.color ?= '#49afcd'
      @_state.set({
        'currentProfileName': ''
        'externalProfile': profile
        'validResultProfiles': []
        'currentProfileCanAddRule': false
      })
      @currentProfileChanged('external')
      return

  ###*
  # Switch options syncing on and off.
  # @param {boolean} enabled Whether to enable syncing
  # @param {?{}} args Extra arguments
  # @param {boolean=false} args.force If true, overwrite options when conflict
  # @returns {Promise} A promise which is fulfilled when the syncing is switched
  ###
  setOptionsSync: (enabled, args) ->
    @log.method('Options#setOptionsSync', this, arguments)
    if not @sync?
      return Promise.reject(new Error('Options syncing is unsupported.'))
    @_state.get({'syncOptions': ''}).then ({syncOptions}) =>
      if not enabled
        if syncOptions == 'sync'
          @_state.set({'syncOptions': 'conflict'})
        @sync.enabled = false
        @_syncWatchStop?()
        @_syncWatchStop = null
        return

      if syncOptions == 'conflict'
        if not args?.force
          return Promise.reject(new Error(
            'Syncing not enabled due to conflict. Retry with force to overwrite
            local options and enable syncing.'))
      return if syncOptions == 'sync'
      @_state.set({'syncOptions': 'sync'}).then =>
        if syncOptions == 'conflict'
          # Try to re-init options from sync.
          @sync.enabled = false
          @_storage.remove().then =>
            @sync.enabled = true
            @init()
        else
          @sync.enabled = true
          @_syncWatchStop?()
          @sync.requestPush(@_options)
          @_syncWatchStop = @sync.watchAndPull(@_storage)
          return

  ###*
  # Clear the sync storage, resetting syncing state to pristine.
  # @returns {Promise} A promise which is fulfilled when the syncing is reset.
  ###
  resetOptionsSync: ->
    @log.method('Options#resetOptionsSync', this, arguments)
    if not @sync?
      return Promise.reject(new Error('Options syncing is unsupported.'))
    @sync.enabled = false
    @_syncWatchStop?()
    @_syncWatchStop = null
    @_state.set({'syncOptions': 'conflict'})

    return @sync.storage.remove().then =>
      @_state.set({'syncOptions': 'pristine'})

module.exports = Options
