Buffer = require('buffer').Buffer
Conditions = require('./conditions')

strStartsWith = (str, prefix) ->
  str.substr(0, prefix.length) == prefix

module.exports = exports =
  'AutoProxy':
    magicPrefix: 'W0F1dG9Qcm94' # Detect base-64 encoded "[AutoProxy".
    detect: (text) ->
      if strStartsWith(text, exports['AutoProxy'].magicPrefix)
        return true
      else if strStartsWith(text, '[AutoProxy')
        return true
      return
    preprocess: (text) ->
      text = text.trim()
      if strStartsWith(text, exports['AutoProxy'].magicPrefix)
        text = new Buffer(text, 'base64').toString('utf8')
      return text
    parse: (text, matchProfileName, defaultProfileName) ->
      text = text.trim()
      normal_rules = []
      exclusive_rules = []
      for line in text.split(/\n|\r/)
        line = line.trim()
        continue if line.length == 0 || line[0] == '!' || line[0] == '['
        source = line
        profile = matchProfileName
        list = normal_rules
        if line[0] == '@' and line[1] == '@'
          profile = defaultProfileName
          list = exclusive_rules
          line = line.substring(2)
        cond =
          if line[0] == '/'
            conditionType: 'UrlRegexCondition'
            pattern: line.substring(1, line.length - 1)
          else if line[0] == '|'
            if line[1] == '|'
              conditionType: 'HostWildcardCondition'
              pattern: "*." + line.substring(2)
            else
              conditionType: 'UrlWildcardCondition'
              pattern: line.substring(1) + "*"
          else if line.indexOf('*') < 0
            conditionType: 'KeywordCondition'
            pattern: line
          else
            conditionType: 'UrlWildcardCondition'
            pattern: 'http://*' + line + '*'
        list.push({condition: cond, profileName: profile, source: source})
      # Exclusive rules have higher priority, so they come first.
      return exclusive_rules.concat normal_rules

  'Switchy':
    omegaPrefix: '[SwitchyOmega Conditions'
    detect: (text) ->
      text = text.trim()
      if strStartsWith(text, exports['Switchy'].omegaPrefix)
        return true
      return

    parse: (text, matchProfileName, defaultProfileName) ->
      text = text.trim()
      switchy = exports['Switchy']
      parser = 'parseOmega'
      if not strStartsWith(text, switchy.omegaPrefix)
        if text[0] == '#' or text.indexOf('\n#') >= 0
          parser = 'parseLegacy'
      return switchy[parser](text, matchProfileName, defaultProfileName)

    # For the omega rule list format, please see the following wiki page:
    # https://github.com/FelisCatus/SwitchyOmega/wiki/SwitchyOmega-conditions-format
    compose: ({rules, defaultProfileName}, {withResult, useExclusive} = {}) ->
      eol = '\r\n'
      ruleList = '[SwitchyOmega Conditions]' + eol
      useExclusive ?= not withResult
      if withResult
        ruleList += '@with result' + eol + eol
      else
        ruleList += eol
      for rule in rules
        line = Conditions.str(rule.condition)
        if line[0] == '#' or line[0] == '+'
          # Escape leading # to avoid being detected as legacy format.
          # Reserve leading + for condition results.
          line = ': ' + line
        if useExclusive and rule.profileName == defaultProfileName
          line = '!' + line
        else if withResult
          # TODO(catus): What if rule.profileName contains ' +' or new lines?
          line += ' +' + rule.profileName
        ruleList += line + eol
      if withResult
        # TODO(catus): Also special chars and sequences in defaultProfileName.
        ruleList += '* +' + defaultProfileName + eol
      return ruleList

    conditionFromLegacyWildcard: (pattern) ->
      if pattern[0] == '@'
        pattern = pattern.substring(1)
      else
        if pattern.indexOf('://') <= 0 and pattern[0] != '*'
          pattern = '*' + pattern
        if pattern[pattern.length - 1] != '*'
          pattern += '*'

      host = Conditions.urlWildcard2HostWildcard(pattern)
      if host
        conditionType: 'HostWildcardCondition'
        pattern: host
      else
        conditionType: 'UrlWildcardCondition'
        pattern: pattern

    parseLegacy: (text, matchProfileName, defaultProfileName) ->
      normal_rules = []
      exclusive_rules = []
      begin = false
      section = 'WILDCARD'
      for line in text.split(/\n|\r/)
        line = line.trim()
        continue if line.length == 0 || line[0] == ';'
        if not begin
          if line.toUpperCase() == '#BEGIN'
            begin = true
          continue
        if line.toUpperCase() == '#END'
          break
        if line[0] == '[' and line[line.length - 1] == ']'
          section = line.substring(1, line.length - 1).toUpperCase()
          continue
        source = line
        profile = matchProfileName
        list = normal_rules
        if line[0] == '!'
          profile = defaultProfileName
          list = exclusive_rules
          line = line.substring(1)
        cond = switch section
          when 'WILDCARD'
            exports['Switchy'].conditionFromLegacyWildcard(line)
          when 'REGEXP'
            conditionType: 'UrlRegexCondition'
            pattern: line
          else
            null
        if cond?
          list.push({condition: cond, profileName: profile, source: source})
      # Exclusive rules have higher priority, so they come first.
      return exclusive_rules.concat normal_rules

    parseOmega: (text, matchProfileName, defaultProfileName) ->
      rules = []
      rulesWithDefaultProfile = []
      withResult = false
      for line in text.split(/\n|\r/)
        line = line.trim()
        continue if line.length == 0
        switch line[0]
          when '[' # Header line: Ignore.
            continue
          when ';' # Comment line: Ignore.
            continue
          when '@' # Directive line:
            iSpace = line.indexOf(' ')
            iSpace = line.length if iSpace < 0
            directive = line.substr(1, iSpace - 1)
            line = line.substr(iSpace + 1).trim()
            switch directive.toUpperCase()
              when 'WITH'
                feature = line.toUpperCase()
                if feature == 'RESULT' or feature == 'RESULTS'
                  withResult = true
            continue

        source = null
        if line[0] == '!'
          profile = if withResult then null else defaultProfileName
          source = line
          line = line.substr(1)
        else if withResult
          iSpace = line.lastIndexOf(' +')
          if iSpace < 0
            throw new Error("Missing result profile name: " + line)
          profile = line.substr(iSpace + 2).trim()
          line = line.substr(0, iSpace).trim()
          defaultProfileName = profile if line == '*'
        else
          profile = matchProfileName

        cond = Conditions.fromStr(line)
        if not cond
          throw new Error("Invalid rule: " + line)

        rule = {condition: cond, profileName: profile, source: source ? line}
        rules.push(rule)
        if not profile
          rulesWithDefaultProfile.push(rule)

      if withResult
        if not defaultProfileName
          throw new Error("Missing default rule with catch-all '*' condition!")
        for rule in rulesWithDefaultProfile
          rule.profileName = defaultProfileName
      return rules
