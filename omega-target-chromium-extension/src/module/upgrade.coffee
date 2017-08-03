OmegaTarget = require('omega-target')
OmegaPac = OmegaTarget.OmegaPac

module.exports = (oldOptions, i18n) ->
  config = try JSON.parse(oldOptions['config'])
  if config
    options = changes ? {}
    options['schemaVersion'] = 2
    boolItems =
      '-confirmDeletion': 'confirmDeletion'
      '-refreshOnProfileChange': 'refreshTab'
      '-enableQuickSwitch': 'quickSwitch'
      '-revertProxyChanges': 'preventProxyChanges'
    for own key, oldKey of boolItems
      options[key] = !!config[oldKey]
    options['-downloadInterval'] =
      parseInt(config['ruleListReload']) || 15

    auto = OmegaPac.Profiles.create(
      profileType: 'SwitchProfile'
      name: i18n.upgrade_profile_auto
      color: '#55bb55'
      defaultProfileName: 'direct' # We will set this to rulelist.name soon.
    )
    OmegaPac.Profiles.updateRevision(auto)
    options[OmegaPac.Profiles.nameAsKey(auto.name)] = auto

    rulelist = OmegaPac.Profiles.create(
      profileType: 'RuleListProfile'
      name: '__ruleListOf_' + auto.name
      color: '#dd6633'
      format:
        if config['ruleListAutoProxy'] then 'AutoProxy' else 'Switchy'
      defaultProfileName: 'direct'
      sourceUrl: config['ruleListUrl'] || ''
    )
    options[OmegaPac.Profiles.nameAsKey(rulelist.name)] = rulelist

    auto.defaultProfileName = rulelist.name

    nameMap = {'auto': auto.name, 'direct': 'direct'}
    oldProfiles = (try JSON.parse(oldOptions['profiles'])) || {}
    colorTranslations =
      'blue': '#99ccee'
      'green': '#99dd99'
      'red': '#ffaa88'
      'yellow': '#ffee99'
      'purple': '#d497ee'
      '': '#99ccee'

    seenFixedProfile = false
    for own _, oldProfile of oldProfiles
      profile = null
      switch oldProfile['proxyMode']
        when 'auto'
          profile = OmegaPac.Profiles.create(
            profileType: 'PacProfile'
          )
          url = oldProfile['proxyConfigUrl']
          if url.substr(0, 5) == 'data:'
            text = url.substr(url.indexOf(',') + 1)
            Buffer = require('buffer').Buffer
            text = new Buffer(text, 'base64').toString('utf8')
            profile.pacScript = text
          else
            profile.pacUrl = url
        when 'manual'
          seenFixedProfile = true
          profile = OmegaPac.Profiles.create(
            profileType: 'FixedProfile'
          )
          if !!oldProfile['useSameProxy']
            profile.fallbackProxy = OmegaPac.Profiles.parseHostPort(
              oldProfile['proxyHttp'], 'http')
          else if oldProfile['proxySocks']
            protocol =
              if oldProfile['socksVersion'] == 5
                'socks5'
              else
                'socks4'
            profile.fallbackProxy = OmegaPac.Profiles.parseHostPort(
              oldProfile['proxySocks'],
              protocol
            )
          else
            profile.proxyForHttp = OmegaPac.Profiles.parseHostPort(
              oldProfile['proxyHttp'], 'http')
            profile.proxyForHttps = OmegaPac.Profiles.parseHostPort(
              oldProfile['proxyHttps'], 'http')
            profile.proxyForFtp = OmegaPac.Profiles.parseHostPort(
              oldProfile['proxyFtp'], 'http')
          if oldProfile['proxyExceptions']?
            haslocalPattern = false
            profile.bypassList = []
            oldProfile['proxyExceptions'].split(';').forEach (line) ->
              line = line.trim()
              return unless line
              haslocalPattern = true if line == '<local>'
              profile.bypassList.push(
                conditionType: 'BypassCondition'
                pattern: line
              )
            if haslocalPattern
              profile.bypassList = profile.bypassList.filter (cond) ->
                OmegaPac.Conditions.localHosts.indexOf(cond.pattern) < 0
      if profile
        color = oldProfile['color']
        profile.color = colorTranslations[color] ? colorTranslations['']
        name = oldProfile['name'] ? oldProfile['id']
        name = name.trim()
        if name[0] == '_'
          name = 'p' + name
        profile.name = name
        num = 1
        while OmegaPac.Profiles.byName(profile.name, options)
          profile.name = name + num
          num++
        nameMap[oldProfile['id']] = profile.name
        OmegaPac.Profiles.updateRevision(profile)
        options[OmegaPac.Profiles.nameAsKey(profile.name)] = profile

    if not seenFixedProfile
      exampleFixedProfileName = 'Example Profile'
      options[OmegaPac.Profiles.nameAsKey(exampleFixedProfileName)] =
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
        name: exampleFixedProfileName
        color: "#99ccee"
        fallbackProxy:
          port: 8080
          scheme: "http"
          host: "proxy.example.com"

    startupId = config['startupProfileId']
    options['-startupProfileName'] = nameMap[startupId] || ''

    quickSwitch = try JSON.parse(oldOptions['quickSwitchProfiles'])
    options['-quickSwitchProfiles'] = if not quickSwitch? then [] else
      quickSwitch.map (p) -> nameMap[p]

    if config['ruleListProfileId']
      rulelist.matchProfileName =
        nameMap[config['ruleListProfileId']] || 'direct'

    defaultRule = try JSON.parse(oldOptions['defaultRule'])
    if defaultRule
      rulelist.defaultProfileName =
        nameMap[defaultRule.profileId] || 'direct'
      if not config.ruleListEnabled
        auto.defaultProfileName = rulelist.defaultProfileName
    OmegaPac.Profiles.updateRevision(rulelist)

    rules = try JSON.parse(oldOptions['rules'])
    if rules
      conditionFromRule = (rule) ->
        switch rule['patternType']
          when 'wildcard'
            pattern = rule['urlPattern']
            OmegaPac.RuleList['Switchy'].conditionFromLegacyWildcard(pattern)
          else
            conditionType: 'UrlRegexCondition'
            pattern: rule['urlPattern']
      auto.rules = for own _, rule of rules
        profileName: nameMap[rule['profileId']] || 'direct'
        condition: conditionFromRule(rule)
    return options
  return
