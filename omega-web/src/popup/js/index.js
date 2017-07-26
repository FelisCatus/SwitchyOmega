(function() {
  handleClick('js-option', showOptions);
  handleClick('js-temprule', showTempRuleDropdown);
  handleClick('js-direct', applyProfile.bind(this, 'direct'));
  handleClick('js-system', applyProfile.bind(this, 'system'));
  OmegaPopup.addTempRule = addTempRule;
  OmegaPopup.setDefaultProfile = setDefaultProfile;
  OmegaPopup.applyProfile = applyProfile;
  return;

  function handleClick(id, handler) {
    document.getElementById(id).addEventListener('click', handler, false);
  }

  function closePopup() {
    window.close();
  }

  function showOptions(e) {
    if (typeof OmegaTargetPopup !== 'undefined') {
      try {
        OmegaTargetPopup.openOptions(null, closePopup);
        e.preventDefault();
      } catch (_) {
      }
    }
  }

  function applyProfile(profileName) {
    $script.ready('om-target', function() {
      OmegaTargetPopup.applyProfile(profileName, closePopup);
    });
  }

  function setDefaultProfile(profileName, defaultProfileName) {
    $script.ready('om-target', function() {
      OmegaTargetPopup.setDefaultProfile(profileName, defaultProfileName,
        closePopup);
    });
  }

  function addTempRule(domain, profileName) {
    $script.ready('om-target', function() {
      OmegaTargetPopup.addTempRule(domain, profileName, closePopup);
    });
  }

  function showTempRuleDropdown() {
    $script.ready('om-dropdowns', function() {
      OmegaPopup.showTempRuleDropdown();
    });
  }
})();
