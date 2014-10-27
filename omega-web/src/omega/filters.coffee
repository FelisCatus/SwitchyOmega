angular.module('omega').filter 'profiles', (builtinProfiles, profileOrder,
  isProfileNameHidden, isProfileNameReserved) ->

  charCodePlus = '+'.charCodeAt(0)
  builtinProfileList = (profile for _, profile of builtinProfiles)
  (options, filter) ->
    result = []
    for name, value of options when name.charCodeAt(0) == charCodePlus
      result.push value
    if (typeof filter == 'object' or (
      typeof filter == 'string' and filter.charCodeAt(0) == charCodePlus))
      if typeof filter == 'string'
        filter = filter.substr(1)
      result = OmegaPac.Profiles.validResultProfilesFor(filter, options)
    if filter == 'all'
      result = result.filter (profile) -> !isProfileNameHidden(profile.name)
      result = result.concat builtinProfileList
    else
      result = result.filter (profile) -> !isProfileNameReserved(profile.name)
    if filter == 'sorted'
      result.sort profileOrder
    result

angular.module('omega').filter 'tr', (omegaTarget) -> omegaTarget.getMessage
angular.module('omega').filter 'dispName', (omegaTarget) ->
  (name) ->
    if typeof name == 'object'
      name = name.name
    omegaTarget.getMessage('profile_' + name) || name
