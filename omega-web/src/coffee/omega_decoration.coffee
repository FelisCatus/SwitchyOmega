orderForType =
  'FixedProfile': -2000
  'PacProfile': -1000
  'SwitchProfile': 2000
  'RuleListProfile': 3000

angular.module('omegaDecoration', []).value('profileIcons', {
  'DirectProfile': 'glyphicon-transfer'
  'SystemProfile': 'glyphicon-off'
  'AutoDetectProfile': 'glyphicon-file'
  'FixedProfile': 'glyphicon-globe'
  'PacProfile': 'glyphicon-file'
  'RuleListProfile': 'glyphicon-list'
  'SwitchProfile': 'glyphicon-retweet'
}).constant('profileOrder', (a, b) ->
  diff = (orderForType[a.profileType] | 0) - (orderForType[b.profileType] | 0)
  return diff if diff != 0
  if a.name == b.name
    0
  else if a.name < b.name
    -1
  else
    1
).directive('omegaRepeatDone', ($parse) ->
  restrict: 'A'
  link: (scope, element, attrs) ->
    callback = $parse(attrs.omegaRepeatDone)
    if scope.$last
      scope.$evalAsync callback
).directive('omegaProfileSelect', ($timeout, profileIcons) ->
  restrict: 'A'
  templateUrl: 'partials/omega_profile_select.html'
  require: '?ngModel'
  scope:
    'profiles': '&omegaProfileSelect'
    'defaultText': '@?defaultText'
    'dispName': '&?dispName'
  link: (scope, element, attrs, ngModel) ->
    scope.profileIcons = profileIcons
    scope.currentProfiles = []
    scope.dispProfiles = undefined
    updateView = ->
      scope.profileIcon = ''
      for profile in scope.currentProfiles
        if profile.name == scope.profileName
          scope.selectedProfile = profile
          scope.profileIcon = profileIcons[profile.profileType]
          break
    scope.$watch(scope.profiles, ((profiles) ->
      scope.currentProfiles = profiles
      if scope.dispProfiles?
        scope.dispProfiles = currentProfiles
      updateView()
    ), true)

    scope.toggled = (open) ->
      if open and not scope.dispProfiles?
        scope.dispProfiles = scope.currentProfiles
        scope.toggled = undefined

    if ngModel
      ngModel.$render = ->
        scope.profileName = ngModel.$viewValue
        updateView()

    scope.setProfileName = (name) ->
      if ngModel
        ngModel.$setViewValue(name)
        ngModel.$render()

    scope.getName = (profile) ->
      scope.dispName?({$profile: profile}) || profile?.name
)
