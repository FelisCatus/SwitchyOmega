function callBackgroundNoReply(method, args, cb) {
  chrome.runtime.sendMessage({
    method: method,
    args: args,
    noReply: true,
    refreshActivePage: true,
  });
  if (cb) return cb();
}

function callBackground(method, args, cb) {
  chrome.runtime.sendMessage({
    method: method,
    args: args,
  }, function(response) {
    if (chrome.runtime.lastError != null)
      return cb && cb(chrome.runtime.lastError)
    if (response.error) return cb && cb(response.error)
    return cb && cb(null, response.result)
  });
}

var requestInfoCallback = null;

OmegaTargetPopup = {
  getState: function (keys, cb) {
    if (typeof localStorage === 'undefined' || !localStorage.length) {
      callBackground('getState', [keys], cb);
      return;
    }
    var results = {};
    keys.forEach(function(key) {
      try {
        results[key] = JSON.parse(localStorage['omega.local.' + key]);
      } catch (_) {
        return null;
      }
    });
    if (cb) cb(null, results);
  },
  applyProfile: function (name, cb) {
    callBackgroundNoReply('applyProfile', [name], cb);
  },
  openOptions: function (hash, cb) {
    var options_url = chrome.extension.getURL('options.html');

    chrome.tabs.query({
      url: options_url
    }, function(tabs) {
      if (!chrome.runtime.lastError && tabs && tabs.length > 0) {
        var props = {
          active: true
        };
        if (hash) {
          var url = options_url + hash;
          props.url = url;
        }
        chrome.tabs.update(tabs[0].id, props);
      } else {
        chrome.tabs.create({
          url: options_url
        });
      }
      if (cb) return cb();
    });
  },
  getActivePageInfo: function(cb) {
    chrome.tabs.query({active: true, lastFocusedWindow: true}, function (tabs) {
      if (tabs.length === 0 || !tabs[0].url) return cb();
      var args = {tabId: tabs[0].id, url: tabs[0].url};
      callBackground('getPageInfo', [args], cb)
    });
  },
  setDefaultProfile: function(profileName, defaultProfileName, cb) {
    callBackgroundNoReply('setDefaultProfile',
      [profileName, defaultProfileName], cb);
  },
  addTempRule: function(domain, profileName, cb) {
    callBackgroundNoReply('addTempRule', [domain, profileName], cb);
  },
  openManage: function(domain, profileName, cb) {
    chrome.tabs.create({
      url: 'chrome://extensions/?id=' + chrome.runtime.id,
    }, cb);
  },
  getMessage: chrome.i18n.getMessage.bind(chrome.i18n),
};
