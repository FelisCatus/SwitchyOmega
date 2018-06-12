(function() {
  $script.ready('om-state', updateMenuByState);
  $script.ready('om-page-info', updateMenuByPageInfo);
  $script.ready(['om-state', 'om-page-info'], updateMenuByStateAndPageInfo);

  var profileTemplate = document.getElementById('js-profile-tpl')
    .cloneNode(true);
  profileTemplate.removeAttribute('id');

  var iconForProfileType = {
    'DirectProfile': 'glyphicon-transfer',
    'SystemProfile': 'glyphicon-off',
    'AutoDetectProfile': 'glyphicon-file',
    'FixedProfile': 'glyphicon-globe',
    'PacProfile': 'glyphicon-file',
    'VirtualProfile': 'glyphicon-question-sign',
    'RuleListProfile': 'glyphicon-list',
    'SwitchProfile': 'glyphicon-retweet',
  };
  var orderForType = {
    'FixedProfile': -2000,
    'PacProfile': -1000,
    'VirtualProfile': 1000,
    'SwitchProfile': 2000,
    'RuleListProfile': 3000,
  };

  return;

  function updateMenuByState() {
    var state = OmegaPopup.state;
    if (state.proxyNotControllable) {
      location.href = 'proxy_not_controllable.html';
      return;
    }
    addProfilesItems(state);
    $script.done('om-profile-items');
    updateOtherItems(state);
  }

  function compareProfile(a, b) {
    var diff;
    diff = (orderForType[a.profileType] | 0) - (orderForType[b.profileType] | 0);
    if (diff !== 0) {
      return diff;
    }
    if (a.name === b.name) {
      return 0;
    } else if (a.name < b.name) {
      return -1;
    } else {
      return 1;
    }
  }

  function updateMenuByPageInfo() {
    var info = OmegaPopup.pageInfo;
    if (info && info.errorCount > 0) {
      document.querySelector('.om-reqinfo').classList.remove('om-hidden');
      var text = OmegaTargetPopup.getMessage('popup_requestErrorCount',
        [info.errorCount]);
      document.querySelector('.om-reqinfo-text').textContent = text;
    }
  }

  function updateMenuByStateAndPageInfo() {
    var state = OmegaPopup.state;
    var info = OmegaPopup.pageInfo;
    if (state.showExternalProfile && state.externalProfile &&
        (!info || !info.errorCount)) {
      showMenuForExternalProfile(state);
    }
    if (!info || !info.url) return updateOtherItems(null);
    document.querySelector('.om-page-domain').textContent = info.domain;
    OmegaPopup.showTempRuleDropdown = showTempRuleDropdown;
    $script.done('om-dropdowns');
  }

  function showMenuForExternalProfile(state) {
    var profile = state.externalProfile;
    profile.name = OmegaTargetPopup.getMessage('popup_externalProfile')
    var profileDisp = createMenuItemForProfile(profile);

    var link = profileDisp.querySelector('a');
    link.id = 'js-external';
    link.addEventListener('click', function() {
      location.href = '../popup.html#!external';
    });

    if (state.currentProfileName === '') {
      profileDisp.classList.add('om-effective');
    }

    var reqInfo = document.querySelector('.om-reqinfo');
    reqInfo.parentElement.insertBefore(profileDisp, reqInfo);
  }

  function showTempRuleDropdown() {
    var tempRuleItem = document.querySelector('.om-nav-temprule');
    toggleDropdown(tempRuleItem, createTempRuleDropdown);
    document.getElementById('js-temprule').focus();
  }

  function updateOtherItems(state) {
    var hasValidResults = state && state.validResultProfiles &&
      state.validResultProfiles.length;
    if (!hasValidResults || !state.currentProfileCanAddRule) {
      document.querySelector('.om-nav-addrule').classList.add('om-hidden');
      document.getElementById('js-addrule').href = '#';
    }
    if (!hasValidResults) {
      document.querySelector('.om-nav-temprule').classList.add('om-hidden');
      document.getElementById('js-temprule').href = '#';
    }
  }

    var isValidResultProfile = {};
    validResultProfiles.forEach(function(name) {
      isValidResultProfile['+' + name] = true;
    });

  function addProfilesItems(state) {
    var systemProfileDisp = document.getElementById('js-system');
    var directProfileDisp = document.getElementById('js-direct');
    var currentProfileClass = 'om-active';
    if (state.isSystemProfile) {
      systemProfileDisp.parentElement.classList.add('om-active');
      currentProfileClass = 'om-effective';
    }
    if (state.currentProfileName === 'direct') {
      directProfileDisp.parentElement.classList.add(currentProfileClass);
    }

    systemProfileDisp.setAttribute('title',
      state.availableProfiles['+system'].desc);
    directProfileDisp.setAttribute('title',
      state.availableProfiles['+direct'].desc);

    var profilesEnd = document.getElementById('js-profiles-end');
    var profilesContainer = profilesEnd.parentElement;
    var profileCount = 0;
    var charCodeUnderscore = '_'.charCodeAt(0)
    var profiles = Object.keys(state.availableProfiles).map(function(key) {
      return state.availableProfiles[key];
    }).sort(compareProfile);
    profiles.forEach(function(profile) {
      if (profile.builtin) return;
      if (profile.name.charCodeAt(0) === charCodeUnderscore) return;
      profileCount++;

      var profileDisp = createMenuItemForProfile(profile,
        state.availableProfiles);
      var link = profileDisp.querySelector('a');
      link.id = 'js-profile-' + profileCount;
      link.addEventListener('click', function() {
        $script.ready('om-main', function() {
          OmegaPopup.applyProfile(profile.name);
        });
      });

      if (profile.name === state.currentProfileName) {
        profileDisp.classList.add(currentProfileClass);
      }

      if (profile.validResultProfiles) {
        profileDisp.classList.add('om-has-dropdown');
        link.classList.add('om-has-edit');
        var toggle = document.createElement('div');
        toggle.classList.add('om-edit-toggle');
        var icon = document.createElement('span');
        icon.setAttribute('class', 'glyphicon glyphicon-chevron-down');
        toggle.appendChild(icon);

        toggle.addEventListener('click', function(e) {
          e.stopPropagation();
          e.preventDefault();
          toggleDropdown(profileDisp,
            createDefaultProfileDropdown.bind(profileDisp, profile));
        });

        link.appendChild(toggle);
      }

      profilesContainer.insertBefore(profileDisp, profilesEnd);
    });
  }

  function createMenuItemForProfile(profile, profiles) {
    var profileDisp = profileTemplate.cloneNode(true);
    var text = OmegaTargetPopup.getMessage('profile_' + profile.name) ||
      profile.name;
    if (profile.defaultProfileName) {
      text += ' [' + profile.defaultProfileName + ']';
    }
    profileDisp.querySelector('.om-profile-name').textContent = text;

    var targetProfile = profile;
    if (profile.profileType === 'VirtualProfile') {
      targetProfile = profiles['+' + profile.defaultProfileName];
    }

    profileDisp.setAttribute('title',
      targetProfile.desc || targetProfile.name || '');

    var iconClass = iconForProfileType[targetProfile.profileType];
    var icon = profileDisp.querySelector('.glyphicon');
    icon.setAttribute('class', 'glyphicon ' + iconClass)
    icon.style.color = targetProfile.color;
    if (targetProfile !== profile) {
      icon.classList.add('om-virtual-profile-icon');
    }
    return profileDisp;
  }

  function toggleDropdown(container, createDropdown) {
    if (!container.classList.contains('om-dropdown-loaded')) {
      var dropdown = createDropdown();
      dropdown.classList.add('om-dropdown');
      container.appendChild(dropdown);
      container.classList.add('om-dropdown-loaded');
    }
    if (container.classList.contains('om-open')) {
      container.classList.remove('om-open');
    } else {
      container.classList.add('om-open');
    }
  }

  function createTempRuleDropdown() {
    var ul = document.createElement('ul');
    var state = OmegaPopup.state;
    var pageInfo = OmegaPopup.pageInfo;

    var profiles = state.validResultProfiles.map(function(name) {
      return state.availableProfiles['+' + name];
    }).sort(compareProfile);
    profiles.forEach(function(profile) {
      if (profile.name.indexOf('__') === 0) return;
      if ((profile.name === OmegaPopup.state.currentProfileName) &&
        (!pageInfo.tempRuleProfileName) &&
        (state.validResultProfiles.length > 1)
      ) return;
      var li = createMenuItemForProfile(profile, state.availableProfiles);
      var link = li.querySelector('a');
      link.addEventListener('click', function() {
        $script.ready('om-main', function() {
          OmegaPopup.addTempRule(pageInfo.domain, profile.name);
        });
      });
      if (profile.name === pageInfo.tempRuleProfileName) {
        li.classList.add('om-active');
      }
      ul.appendChild(li);
    });
    return ul;
  }

  function createDefaultProfileDropdown(profile) {
    var ul = document.createElement('ul');
    var state = OmegaPopup.state;
    var profiles = profile.validResultProfiles.map(function(name) {
      return state.availableProfiles['+' + name];
    }).sort(compareProfile);
    profiles.forEach(function(resultProfile) {
      if (resultProfile.name.indexOf('__') === 0) return;
      if ((resultProfile === profile.currentProfileName) &&
        (profile.validResultProfiles.length > 1)
      ) return;
      var li = createMenuItemForProfile(resultProfile, state.availableProfiles);
      var link = li.querySelector('a');
      link.addEventListener('click', function() {
        $script.ready('om-main', function() {
          OmegaPopup.setDefaultProfile(profile.name, resultProfile.name);
        });
      });
      if (resultProfile.name === profile.currentProfileName) {
        li.classList.add('om-active');
      }
      ul.appendChild(li);
    });
    return ul;
  }
})();
