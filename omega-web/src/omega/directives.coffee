angular.module('omega').directive 'inputGroupClear', ($timeout) ->
  restrict: 'A'
  templateUrl: 'partials/input_group_clear.html'
  scope:
    'model': '=model'
    'type': '@type'
    'ngPattern': '=?ngPattern'
    'placeholder': '@placeholder'
    'controller': '=?controller'
  link: (scope, element, attrs) ->
    scope.catchAll = new RegExp('')
    $timeout ->
      scope.controller = element.find('input').controller('ngModel')

    scope.oldModel = ''
    scope.controller = scope.input
    scope.modelChange = ->
      if scope.model
        scope.oldModel = ''
    scope.toggleClear = ->
      [scope.model, scope.oldModel] = [scope.oldModel, scope.model]
angular.module('omega').directive 'omegaUpload', ->
  restrict: 'A'
  scope:
    success: '&omegaUpload'
    error: '&omegaError'
  link: (scope, element, attrs) ->
    input = element[0]
    element.on 'change', ->
      if input.files.length > 0 and input.files[0].name.length > 0
        reader = new FileReader()
        reader.addEventListener 'load', (e) ->
          scope.$apply ->
            scope.success({'$content': e.target.result})
        reader.addEventListener 'error', (e) ->
          scope.$apply ->
            scope.error({'$error': e.target.error})
        reader.readAsText(input.files[0])
        input.value = ''
angular.module('omega').directive 'omegaIp2str', ->
  restrict: 'A'
  priority: 2 # Run post-link after input directive (0) and ngModel (1).
  require: 'ngModel'
  link: (scope, element, attr, ngModel) ->
    ngModel.$parsers.push (value) ->
      if value
        OmegaPac.Conditions.fromStr('Ip: ' + value)
      else
        ({conditionType: 'IpCondition', ip: '0.0.0.0', prefixLength: 0})
    ngModel.$formatters.push (value) ->
      if value?.ip
        OmegaPac.Conditions.str(value).split(' ', 2)[1]
      else
        ''
