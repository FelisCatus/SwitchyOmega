$script.ready('om-page-info', function() {
  document.querySelector('#js-direct .om-profile-name').textContent =
    OmegaTargetPopup.getMessage('profile_direct');
  document.querySelector('#js-system .om-profile-name').textContent =
    OmegaTargetPopup.getMessage('profile_system');
  document.querySelector('#js-addrule-label').textContent =
    OmegaTargetPopup.getMessage('popup_addCondition');
  document.querySelector('#js-option-label').textContent =
    OmegaTargetPopup.getMessage('popup_showOptions');
});
