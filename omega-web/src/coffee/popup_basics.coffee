# Use events to ensure that the log can be downloaded even if everything else
# fails to load.
document.querySelector('.error-log').addEventListener 'click', (->
  window.OmegaTargetWebBasics.getLog (log) ->
    blob = new Blob [log], {type: "text/plain;charset=utf-8"}
    saveAs(blob, "OmegaLog_#{Date.now()}.txt")
), false

window.OmegaTargetWebBasics.getEnv (env) ->
  url = 'https://github.com/FelisCatus/SwitchyOmega/issues/new?title=&body='
  body = window.OmegaTargetWebBasics.getMessage('popup_issueTemplate', env)
  body ||= """
    \n\n
    <!-- Please write your comment ABOVE this line. -->
    SwitchyOmega #{env.projectVersion}
    #{env.userAgent}
  """
  document.querySelector('.report-issue').href = url + encodeURIComponent(body)
