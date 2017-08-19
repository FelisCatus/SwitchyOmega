module.exports = ->
  schemaVersion: 2
  "-enableQuickSwitch": false
  "-refreshOnProfileChange": true
  "-startupProfileName": ""
  "-quickSwitchProfiles": []
  "-revertProxyChanges": true
  "-confirmDeletion": true
  "-showInspectMenu": true
  "-addConditionsToBottom": false
  "-showExternalProfile": true
  "-downloadInterval": 1440
  "+proxy":
    bypassList: [
      {
        pattern: "127.0.0.1"
        conditionType: "BypassCondition"
      }
      {
        pattern: "::1"
        conditionType: "BypassCondition"
      }
      {
        pattern: "localhost"
        conditionType: "BypassCondition"
      }
    ]
    profileType: "FixedProfile"
    name: "proxy"
    color: "#99ccee"
    fallbackProxy:
      port: 8080
      scheme: "http"
      host: "proxy.example.com"

  "+auto switch":
    profileType: "SwitchProfile"
    rules: [
      {
        condition:
          pattern: "internal.example.com"
          conditionType: "HostWildcardCondition"

        profileName: "direct"
      }
      {
        condition:
          pattern: "*.example.com"
          conditionType: "HostWildcardCondition"

        profileName: "proxy"
      }
    ]
    name: "auto switch"
    color: "#99dd99"
    defaultProfileName: "direct"
