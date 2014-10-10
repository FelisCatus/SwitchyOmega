angular.module('omega').controller 'MasterCtrl', ($scope, $rootScope, $window,
  $modal, $state, builtinProfiles, profileColors, profileIcons, omegaTarget, $q,
  $timeout, $location, $filter, getAttachedName) ->

  tr = $filter('tr')

  # This method allows watchers to change the value without recursively firing
  # itself. Usage: $scope.omegaWatchAndChange
  # coffeelint: disable=missing_fat_arrows
  $rootScope.omegaWatchAndChange = (expression, listener, objectEquality) ->
    scope = this
    # coffeelint: enable=missing_fat_arrows
    handler = (newValue, oldValue) ->
      modified = listener(newValue, oldValue)
      return if newValue == oldValue and newValue == modified
      for watcher in scope.$$watchers
        if watcher.exp == expression
          watcher.last = modified
    return scope.$watch(expression, handler, objectEquality)

  $rootScope.options = null

  omegaTarget.addOptionsChangeCallback (newOptions) ->
    $rootScope.options = angular.copy(newOptions)
    $rootScope.optionsOld = angular.copy(newOptions)
    $timeout ->
      $rootScope.optionsDirty = false
  
  $rootScope.revertOptions = ->
    $window.location.reload()

  $rootScope.exportScript = (name) ->
    getProfileName =
      if name
        $q.when(name)
      else
        omegaTarget.state('currentProfileName')
          
    getProfileName.then (profileName) ->
      return unless profileName
      profile = $rootScope.profileByName(profileName)
      return if profile.profileType in ['DirectProfile', 'SystemProfile']
      ast = OmegaPac.PacGenerator.script($rootScope.options, profileName)
      pac = ast.print_to_string(beautify: true, comments: true)
      pac = OmegaPac.PacGenerator.ascii(pac)
      blob = new Blob [pac], {type: "text/plain;charset=utf-8"}
      fileName = profileName.replace(/\W+/g, '_')
      saveAs(blob, "OmegaProfile_#{fileName}.pac")

  diff = jsondiffpatch.create(
    objectHash: (obj) -> JSON.stringify(obj)
    textDiff: minLength: 1 / 0
  )

  $rootScope.showAlert = (alert) -> $timeout ->
    $scope.alert = alert
    $scope.alertShown = true
    $scope.alertShownAt = Date.now()
    $timeout $rootScope.hideAlert, 3000
    return

  $rootScope.hideAlert = -> $timeout ->
    if Date.now() - $scope.alertShownAt >= 1000
      $scope.alertShown = false

  checkFormValid = ->
    fields = angular.element('.ng-invalid')
    if fields.length > 0
      fields[0].focus()
      $rootScope.showAlert(
        type: 'error'
        i18n: 'options_formInvalid'
      )
      return false
    return true

  $rootScope.applyOptions = ->
    return unless checkFormValid()
    plainOptions = angular.fromJson(angular.toJson($rootScope.options))
    patch = diff.diff($rootScope.optionsOld, plainOptions)
    omegaTarget.optionsPatch(patch).then ->
      $rootScope.showAlert(
        type: 'success'
        i18n: 'options_saveSuccess'
      )

  $rootScope.resetOptions = (options) ->
    omegaTarget.resetOptions(options).then(->
      $rootScope.showAlert(
        type: 'success'
        i18n: 'options_resetSuccess'
      )
    ).catch (err) ->
      $rootScope.showAlert(
        type: 'error'
        message: err
      )
      $q.reject err

  $rootScope.profileByName = (name) ->
    OmegaPac.Profiles.byName(name, $rootScope.options)

  $rootScope.applyOptionsConfirm = ->
    return $q.reject 'form_invalid' unless checkFormValid()
    return $q.when(true) unless $rootScope.optionsDirty
    $modal.open(templateUrl: 'partials/apply_options_confirm.html').result
      .then -> $rootScope.applyOptions()

  $rootScope.newProfile = ->
    scope = $rootScope.$new('isolate')
    scope.options = $rootScope.options
    scope.notConflict = (name) -> not $rootScope.profileByName(name)
    scope.profileIcons = profileIcons
    $modal.open(
      templateUrl: 'partials/new_profile.html'
      scope: scope
    ).result.then (profile) ->
      profile = OmegaPac.Profiles.create(profile)
      choice = Math.floor(Math.random() * profileColors.length)
      profile.color ?= profileColors[choice]
      OmegaPac.Profiles.updateRevision(profile)
      $rootScope.options[OmegaPac.Profiles.nameAsKey(profile)] = profile
      $state.go('profile', {name: profile.name})

  $rootScope.renameProfile = (fromName) ->
    $rootScope.applyOptionsConfirm().then ->
      profile = $rootScope.profileByName(fromName)
      scope = $rootScope.$new('isolate')
      scope.options = $rootScope.options
      scope.fromName = fromName
      scope.notConflict = (name) ->
        name == fromName or not $rootScope.profileByName(name)
      scope.profileIcons = profileIcons
      $modal.open(
        templateUrl: 'partials/rename_profile.html'
        scope: scope
      ).result.then (toName) ->
        if toName != fromName
          rename = omegaTarget.renameProfile(fromName, toName)
          attachedName = getAttachedName(fromName)
          if $rootScope.profileByName(attachedName)
            toAttachedName = getAttachedName(toName)
            defaultProfileName = undefined
            if $rootScope.profileByName(toAttachedName)
              defaultProfileName = profile.defaultProfileName
              rename = rename.then ->
                toAttachedKey = OmegaPac.Profiles.nameAsKey(toAttachedName)
                profile = $rootScope.profileByName(toName)
                profile.defaultProfileName = 'direct'
                OmegaPac.Profiles.updateRevision(profile)
                delete $rootScope.options[toAttachedKey]
                $rootScope.applyOptions()
            rename = rename.then ->
              omegaTarget.renameProfile(attachedName, toAttachedName)
            if defaultProfileName
              rename = rename.then ->
                profile = $rootScope.profileByName(toName)
                profile.defaultProfileName = defaultProfileName
                $rootScope.applyOptions()
          rename.then(->
            $state.go('profile', {name: toName})
          ).catch (err) ->
            $rootScope.showAlert(
              type: 'error'
              message: err
            )

  $scope.updatingProfile = {}

  $rootScope.updateProfile = (name) ->
    $rootScope.applyOptionsConfirm().then(->
      $scope.updatingProfile[name] = true
      omegaTarget.updateProfile(name).then((results) ->
        success = 0
        error = 0
        for own profileName, result of results
          if result instanceof Error
            error++
          else
            success++
        if error == 0
          $rootScope.showAlert(
            type: 'success'
            i18n: 'options_profileDownloadSuccess'
          )
        else
          $q.reject(results)
      ).catch((err) ->
        $rootScope.showAlert(
          type: 'error'
          i18n: 'options_profileDownloadError'
        )
      ).finally ->
        $scope.updatingProfile[name] = false
    )

  onOptionChange = (options, oldOptions) ->
    return if options == oldOptions or not oldOptions?
    plainOptions = angular.fromJson(angular.toJson(options))
    $rootScope.optionsDirty = true
  $rootScope.$watch 'options', onOptionChange, true

  $rootScope.$on '$stateChangeStart', (event, _, __, fromState) ->
    if not checkFormValid()
      event.preventDefault()

  $rootScope.$on '$stateChangeSuccess', ->
    omegaTarget.lastUrl($location.url())

  $window.onbeforeunload = ->
    if $rootScope.optionsDirty
      return tr('options_optionsNotSaved')
    else
      null

  document.addEventListener 'click', (->
    $rootScope.hideAlert()
  ), false

  $scope.profileIcons = profileIcons

  for own type of OmegaPac.Profiles.formatByType
    $scope.profileIcons[type] = $scope.profileIcons['RuleListProfile']

  $scope.alertIcons =
    'success': 'glyphicon-ok',
    'warning': 'glyphicon-warning-sign',
    'error': 'glyphicon-remove',
    'danger': 'glyphicon-danger',

  $scope.alertClassForType = (type) ->
    return '' if not type
    if type == 'error'
      type = 'danger'
    return 'alert-' + type

  $scope.downloadIntervals = [15, 60, 180, 360, 720, 1440, -1]
  $scope.downloadIntervalI18n = (interval) ->
    "options_downloadInterval_" + (if interval < 0 then "never" else interval)

  omegaTarget.refresh()
