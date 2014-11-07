OmegaTarget = require('omega-target')
OmegaPac = OmegaTarget.OmegaPac

module.exports = (details, options, fixedProfileConfig) ->
  if details.name
    details
  else
    switch details.value.mode
      when 'system'
        OmegaPac.Profiles.byName('system')
      when 'direct'
        OmegaPac.Profiles.byName('direct')
      when 'auto_detect'
        OmegaPac.Profiles.create({
          profileType: 'PacProfile'
          name: ''
          pacUrl: 'http://wpad/wpad.dat'
        })
      when 'pac_script'
        url = details.value.pacScript.url
        if url
          profile = null
          OmegaPac.Profiles.each options, (key, p) ->
            if p.profileType == 'PacProfile' and p.pacUrl == url
              profile = p
          profile ? OmegaPac.Profiles.create({
            profileType: 'PacProfile'
            name: ''
            pacUrl: url
          })
        else do ->
          profile = null
          script = details.value.pacScript.data
          OmegaPac.Profiles.each options, (key, p) ->
            if p.profileType == 'PacProfile' and p.pacScript == script
              profile = p
          return profile if profile
          # Try to parse the prefix used by this class.
          script = script.trim()
          magic = '/*OmegaProfile*'
          if script.substr(0, magic.length) == magic
            end = script.indexOf('*/')
            if end > 0
              i = magic.length
              tokens = script.substring(magic.length, end).split('*')
              [profileName, revision] = tokens
              try
                profileName = JSON.parse(profileName)
              catch
                profileName = null
              if profileName and revision
                profile = OmegaPac.Profiles.byName(profileName, options)
                if OmegaPac.Revision.compare(profile.revision, revision) == 0
                  return profile
          return OmegaPac.Profiles.create({
            profileType: 'PacProfile'
            name: ''
            pacScript: script
          })
      when 'fixed_servers'
        props = ['proxyForHttp', 'proxyForHttps', 'proxyForFtp',
          'fallbackProxy', 'singleProxy']
        proxies = {}
        for prop in props
          result = OmegaPac.Profiles.pacResult(details.value.rules[prop])
          if prop == 'singleProxy' and details.value.rules[prop]?
            proxies['fallbackProxy'] = result
          else
            proxies[prop] = result
        bypassSet = {}
        bypassCount = 0
        if details.value.rules.bypassList
          for pattern in details.value.rules.bypassList
            bypassSet[pattern] = true
            bypassCount++
        if bypassSet['<local>']
          for host in OmegaPac.Conditions.localHosts when bypassSet[host]
            delete bypassSet[host]
            bypassCount--
        profile = null
        OmegaPac.Profiles.each options, (key, p) ->
          return if p.profileType != 'FixedProfile'
          return if p.bypassList.length != bypassCount
          for condition in p.bypassList
            return unless bypassSet[condition.pattern]
          rules = fixedProfileConfig(p).rules
          if rules['singleProxy']
            rules['fallbackProxy'] = rules['singleProxy']
            delete rules['singleProxy']
          return unless rules?
          for prop in props when rules[prop] or proxies[prop]
            if OmegaPac.Profiles.pacResult(rules[prop]) != proxies[prop]
              return
          profile = p
        if profile
          profile
        else
          profile = OmegaPac.Profiles.create({
            profileType: 'FixedProfile'
            name: ''
          })
          for prop in props when details.value.rules[prop]
            if prop == 'singleProxy'
              profile['fallbackProxy'] = details.value.rules[prop]
            else
              profile[prop] = details.value.rules[prop]
          profile.bypassList =
            for own pattern of bypassSet
              {conditionType: 'BypassCondition', pattern: pattern}
          profile
