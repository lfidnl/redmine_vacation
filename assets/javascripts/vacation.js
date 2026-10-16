(function () {
  'use strict';

  // Move the banners from the end of #content (where the hook renders them)
  // to the top, right below Redmine's own flash messages.
  function placeBanners() {
    var box = document.getElementById('vacation-messages');
    var content = document.getElementById('content');
    if (!box || !content) return;

    var flashes = content.querySelectorAll(':scope > .flash');
    var anchor = flashes.length ? flashes[flashes.length - 1].nextSibling : content.firstChild;
    content.insertBefore(box, anchor);
  }

  function hexToRgb(hex) {
    var m = /^#([0-9a-f]{2})([0-9a-f]{2})([0-9a-f]{2})$/i.exec(hex);
    return m ? [parseInt(m[1], 16), parseInt(m[2], 16), parseInt(m[3], 16)] : null;
  }

  function shade(rgb, factor) {
    return '#' + rgb.map(function (c) {
      return ('0' + Math.round(c * factor).toString(16)).slice(-2);
    }).join('');
  }

  // Mirrors VacationMessage#css_style.
  function applyColor(el, hex) {
    var rgb = hexToRgb(hex);
    if (!rgb) return;
    var luminance = (0.299 * rgb[0] + 0.587 * rgb[1] + 0.114 * rgb[2]) / 255;
    el.style.backgroundColor = hex;
    el.style.borderColor = shade(rgb, 0.7);
    el.style.color = luminance > 0.6 ? shade(rgb, 0.3) : '#ffffff';
  }

  function initForm() {
    var form = document.getElementById('vacation-message-form');
    if (!form) return;

    var color = form.querySelector('#vacation_message_color');
    var text = form.querySelector('#vacation_message_text');
    var visibility = form.querySelector('#vacation_message_visibility');
    var recipients = form.querySelector('.vacation-recipients');
    var preview = document.querySelector('.vacation-preview');

    function updatePreview() {
      if (!preview) return;
      preview.textContent = preview.dataset.template.replace('%TEXT%', text.value);
      applyColor(preview, color.value);
    }

    function toggleRecipients() {
      recipients.style.display = visibility.value === 'selected' ? '' : 'none';
    }

    form.querySelectorAll('.vacation-preset').forEach(function (button) {
      button.addEventListener('click', function () {
        color.value = button.dataset.color;
        updatePreview();
      });
    });
    color.addEventListener('input', updatePreview);
    text.addEventListener('input', updatePreview);
    visibility.addEventListener('change', toggleRecipients);

    updatePreview();
    toggleRecipients();
  }

  document.addEventListener('DOMContentLoaded', function () {
    placeBanners();
    initForm();
  });
})();
