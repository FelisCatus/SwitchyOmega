(function() {
  var keyHandler = {
    38: moveUp, // Up
    40: moveDown, // Down
    37: closeDropdown, // Left
    39: openDropdown, // Right

    72: closeDropdown, // h
    74: moveDown, // j
    75: moveUp, // k
    76: openDropdown, // l

    191: showKeyboardHelp, // /
    63: showKeyboardHelp, // ?

    48: 'js-direct', // 0
    83: 'js-system', // s
    69: 'js-external', // e
    65: 'js-addrule', // a
    187: 'js-addrule', // +, =
    84: 'js-temprule', // t
    79: 'js-option', // o
    82: 'js-reqinfo', // r
  };

  for (i = 1; i <= 9; i++) {
    keyHandler[48 + i] = 'js-profile-' + i;
  }

  var walker;
  return init();

  function init() {
    walker = document.createTreeWalker(
      document.querySelector('.om-nav'),
      NodeFilter.SHOW_ELEMENT,
      {acceptNode: tabbableElementsOnly}
    );

    window.addEventListener('keydown', function(e) {
      var handler = keyHandler[e.keyCode];
      if (!handler) console.log(e.keyCode);
      if (handler == null) return;
      if (e.target.tagName === 'INPUT' || e.target.tagName === 'TEXTAREA') return;
      if (typeof handler === 'string') {
        clickById(handler);
      } else {
        handler();
      }
    });

    $script.ready('om-profile-items', function() {
      var activeNavLink = document.querySelector('.om-nav-item.om-active > a');
      if (activeNavLink) activeNavLink.focus();
    });
  }

  function tabbableElementsOnly(node) {
    if (node.classList.contains('om-hidden')) {
      return NodeFilter.FILTER_REJECT;
    } else if (node.classList.contains('om-dropdown') &&
      !node.parentElement.classList.contains('om-open')) {
      return NodeFilter.FILTER_REJECT;
    } else if (node.tabIndex >= 0) {
      return NodeFilter.FILTER_ACCEPT;
    } else {
      return NodeFilter.FILTER_SKIP;
    }
  }

  function moveUp() {
    walker.currentNode = document.activeElement;
    var result = null;
    if (walker.currentNode) {
      result = walker.previousNode();
    }
    if (!result) {
      walker.currentNode = walker.root.lastElementChild;
      walker.previousNode();
      walker.nextNode();
    }
    walker.currentNode.focus();
  }

  function moveDown() {
    walker.currentNode = document.activeElement;
    var result = null;
    if (walker.currentNode) {
      result = walker.nextNode();
    }
    if (!result) {
      walker.currentNode = walker.root;
      walker.nextNode();
    }
    walker.currentNode.focus();
  }

  function openDropdown() {
    var container = document.querySelector('.om-open');
    if (container) {
      // Existing dropdown. Just move to it.
      container.querySelector('a').focus();
      return;
    }
    var selectedItem = document.activeElement;
    if (!selectedItem || !selectedItem.parentElement) return;
    if (selectedItem.parentElement.classList.contains('om-has-dropdown')) {
      var toggle = selectedItem.querySelector('.om-edit-toggle');
      if (toggle) {
        toggle.click();
      } else {
        selectedItem.click();
      }
    }
  }

  function closeDropdown() {
    var container = document.querySelector('.om-open');
    if (container) {
      container.classList.remove('om-open');
      container.querySelector('a').focus();
    }
  }

  function showKeyboardHelp() {
    $script('js/keyboard_help.js');
  }

  function clickById(id) {
    var element = document.getElementById(id);
    if (element) element.click();
  }

})();
