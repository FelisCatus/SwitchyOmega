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
        var proxy = matchResult[2];
        var auth = matchResult[3];
        if (proxy && !state.useLegacyStringReturn) {
          var proxyInfo = {
            type: proxy.scheme,
            host: proxy.host,
            port: proxy.port,
          };
          if (proxyInfo.type === 'socks5') {
            // MOZ: SOCKS5 proxies are identified by "type": "socks".
            // https://dxr.mozilla.org/mozilla-central/rev/ffe6cc09ccf38cca6f0e727837bbc6cb722d1e71/toolkit/components/extensions/ProxyScriptContext.jsm#51
            proxyInfo.type = 'socks';
            // Enable SOCKS5 remote DNS.
            // TODO(catus): Maybe allow the users to configure this?
            proxyInfo.proxyDNS = true;
          }
          if (auth) {
            proxyInfo.username = auth.username;
            proxyInfo.password = auth.password;
          }
          return [proxyInfo];
        } else if (next.charCodeAt(0) !== 43) {
          // MOZ: Legacy proxy support expects PAC-like string return type.
          // TODO(catus): Remove support for string return type.
          // MOZ: SOCKS5 proxies are supported under the prefix SOCKS.
          // https://dxr.mozilla.org/mozilla-central/rev/ffe6cc09ccf38cca6f0e727837bbc6cb722d1e71/toolkit/components/extensions/ProxyScriptContext.jsm#51
          // Note: We have to replace this because MOZ won't process the rest of
          //       the list if the syntax of the first item is not recognized.
          return next.replace(/SOCKS5 /g, 'SOCKS ');
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
