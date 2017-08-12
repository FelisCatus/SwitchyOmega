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
          // MOZ: SOCKS5 proxies are supported under the prefix SOCKS.
          // https://dxr.mozilla.org/mozilla-central/source/toolkit/components/extensions/ProxyScriptContext.jsm#178
          // Note: We have to replace this because MOZ won't process the rest of
          //       the list if the syntax of the first item is not recognized.
          next = next.replace(/SOCKS5 /g, 'SOCKS ');

          return next;
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
    browser.runtime.sendMessage({event: 'proxyScriptLoaded'});
  }
})();
