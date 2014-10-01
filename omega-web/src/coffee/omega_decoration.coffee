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
)
