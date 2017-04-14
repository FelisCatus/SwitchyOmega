FindProxyForURL = (function () {
  var OmegaPac = require('omega-pac');
  var options = {};
  var state = {};
  var activeProfile = null;
  var fallbackResult = 'DIRECT';
  var pacCache = {};

  init();

  return FindProxyForURL;

  function FindProxyForURL(url, host, details) {
    if (!activeProfile) {
      warn('Warning: Proxy script not initialized on handling: ' + url);
      return fallbackResult;
    }
    // Moz: Neither path or query is included url regardless of scheme for now.
    // This is even more strict than Chromium restricting HTTPS URLs.
    // Therefore, it leads to different behavior than the icon and badge.
    // https://bugzilla.mozilla.org/show_bug.cgi?id=1337001
    var request = OmegaPac.Conditions.requestFromUrl(url);
    var profile = activeProfile;
    var matchResult, next;
    while (profile) {
      matchResult = OmegaPac.Profiles.match(profile, request)
      if (!matchResult) {
        if (profile.profileType === 'DirectProfile') {
          return 'DIRECT';
        } else if (profile.pacScript) {
          return runPacProfile(profile.pacScript);
        } else {
          warn('Warning: Unsupported profile: ' + profile.profileType);
          return fallbackResult;
        }
      }

      if (Array.isArray(matchResult)) {
        next = matchResult[0];
        // TODO: Maybe also return user/pass if Mozilla supports it or it ends
        //       up standardized in WebExtensions in the future.
        // MOZ: Mozilla has a bug tracked for user/pass in PAC return value.
        // https://bugzilla.mozilla.org/show_bug.cgi?id=1319641
        if (next.charCodeAt(0) !== 43) {
          // MOZ: HTTPS proxies are supported under the prefix PROXY.
          // https://dxr.mozilla.org/mozilla-central/source/toolkit/components/extensions/ProxyScriptContext.jsm#180
          return next.replace(/HTTPS /g, 'PROXY ');
        }
      } else if (matchResult.profileName) {
        next = OmegaPac.Profiles.nameAsKey(matchResult.profileName)
      } else {
        return fallbackResult;
      }
      profile = OmegaPac.Profiles.byKey(next, options)
    }
    warn('Warning: Cannot find profile: ' + next);
    return fallbackResult;
  }

  function runPacProfile(profile) {
    var cached = pacCache[profile.name];
    if (!cached || cached.revision !== profile.revision) {
      // https://github.com/FelisCatus/SwitchyOmega/issues/390
      var body = ';\n' + profile.pacScript + '\n\n/* End of PAC */;'
      body += 'return FindProxyForURL';
      var func = new Function(body).call(this);

      if (typeof func !== 'function') {
        warn('Warning: Cannot compile pacScript: ' + profile.name);
        func = function() { return fallbackResult; };
      }
      cached = {func: func, revision: profile.revision}
      pacCache[cacheKey] = cached;
    }
    try {
      // Moz: Most scripts probably won't run without global PAC functions.
      // Example: dnsDomainIs, shExpMatch, isInNet.
      // https://bugzilla.mozilla.org/show_bug.cgi?id=1353510
      return cached.func.call(this);
    } catch (ex) {
      warn('Warning: Error occured in pacScript: ' + profile.name, ex);
      return fallbackResult;
    }
  }

  function warn(message, error) {
    // We don't have console here and alert is not implemented.
    // Throwing and messaging seems to be the only ways to communicate.
    // MOZ: alert(): https://bugzilla.mozilla.org/show_bug.cgi?id=1353510
    browser.runtime.sendMessage({
      event: 'proxyScriptLog',
      message: message,
      error: error,
      level: 'warn',
    });
  }

  function init() {
    browser.runtime.sendMessage({event: 'proxyScriptLoaded'});
    browser.runtime.onMessage.addListener(function(message) {
      if (message.event === 'proxyScriptStateChanged') {
        state = message.state;
        options = message.options;
        if (!state.currentProfileName) {
          activeProfile = state.tempProfile;
        } else {
          activeProfile = OmegaPac.Profiles.byName(state.currentProfileName,
            options);
        }
      }
    });
  }
})();
