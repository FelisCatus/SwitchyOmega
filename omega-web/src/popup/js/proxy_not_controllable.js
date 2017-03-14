(function() {
  var closeButton = document.getElementById('js-close');
  closeButton.addEventListener('click', window.close.bind(window), false);

  var manageButton = document.getElementById('js-manage-ext');
  manageButton.addEventListener('click',
    OmegaTargetPopup.openManage.bind(OmegaTargetPopup), false);

  closeButton.textContent = OmegaTargetPopup.getMessage('dialog_cancel');
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
