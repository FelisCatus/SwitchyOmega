module.exports = ->
  schemaVersion: 2
  "-enableQuickSwitch": false
  "-refreshOnProfileChange": true
  "-startupProfileName": ""
  "-quickSwitchProfiles": []
  "-revertProxyChanges": false
  "-confirmDeletion": true
  "-downloadInterval": 1440
  "+proxy":
    bypassList: [
      pattern: "<local>"
      conditionType: "BypassCondition"
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
