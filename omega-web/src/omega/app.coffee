angular.module('omega').constant('builtinProfiles',
  OmegaPac.Profiles.builtinProfiles)

profileColors = [
  '#9ce', '#9d9', '#fa8', '#fe9', '#d497ee', '#47b', '#5b5', '#d63', '#ca0'
]
colors = [].concat(profileColors)
profileColorPalette = (colors.splice(0, 3) while colors.length)

angular.module('omega').constant('profileColors', profileColors)
angular.module('omega').constant('profileColorPalette', profileColorPalette)

angular.module('omega').config ($stateProvider, $urlRouterProvider,
  $httpProvider) ->
  $urlRouterProvider.otherwise '/ui'
  
  $stateProvider
    .state('ui',
      url: '/ui'
      templateUrl: 'partials/ui.html'
      #controller: 'UiCtrl'
    ).state('general',
      url: '/general'
      templateUrl: 'partials/general.html'
      #controller: 'GeneralCtrl'
    ).state('io',
      url: '/io'
      templateUrl: 'partials/io.html'
      controller: 'IoCtrl'
    ).state('profile',
      url: '/profile/:name'
      templateUrl: 'partials/profile.html'
      controller: 'ProfileCtrl'
    ).state('about',
      url: '/about'
      templateUrl: 'partials/about.html'
    )
