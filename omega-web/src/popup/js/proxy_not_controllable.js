(function() {
  function closePopup() {
    window.close();
    // If the popup is opened as a tab, the above won't work. Let's reload then.
    document.body.style.opacity = 0;
    setTimeout(function() { history.go(0); }, 300);
  }
  var closeButton = document.getElementById('js-close');
  closeButton.addEventListener('click', closePopup, false);

  var manageButton = document.getElementById('js-manage-ext');
  manageButton.addEventListener('click', function () {
    OmegaTargetPopup.openManage(closePopup);
  }, false);

  var learnMoreButton = document.getElementById('js-nc-learn-more');
  learnMoreButton.addEventListener('click', function () {
    OmegaTargetPopup.openOptions('#!/general', closePopup);
  }, false);

  closeButton.textContent = OmegaTargetPopup.getMessage('dialog_cancel');
  learnMoreButton.textContent = 'Learn More'
    //OmegaTargetPopup.getMessage('popup_proxyNotControllableLearnMore');
  manageButton.textContent = OmegaTargetPopup.getMessage(
    'popup_proxyNotControllableManage');


  OmegaTargetPopup.getState([
    'proxyNotControllable',
  ], function(err, state) {
    var reason = state.proxyNotControllable;
    var messageElement = document.getElementById('js-nc-text');
    var detailsElement = document.getElementById('js-nc-details');
    messageElement.textContent = OmegaTargetPopup.getMessage(
      'popup_proxyNotControllable_' + reason);
    var detailsMessage = OmegaTargetPopup.getMessage(
      'popup_proxyNotControllableDetails_' + reason);
    if (!detailsMessage) detailsMessage = OmegaTargetPopup.getMessage(
      'popup_proxyNotControllableDetails');

    detailsElement.textContent = detailsMessage;
  });
})();
