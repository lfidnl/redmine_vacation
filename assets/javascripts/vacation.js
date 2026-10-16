(function () {
  'use strict';

  // ---------------------------------------------------------------- banner

  var DISMISS_KEY = 'redmine_vacation.dismissed';

  function localToday() {
    var d = new Date();
    return d.getFullYear() + '-' + ('0' + (d.getMonth() + 1)).slice(-2) + '-' + ('0' + d.getDate()).slice(-2);
  }

  // Browser storage can be missing or throw (private mode, blocked site
  // data); dismissing then simply lasts until the next page load.
  function readDismissed() {
    try {
      return JSON.parse(window.localStorage.getItem(DISMISS_KEY)) || {};
    } catch (e) {
      return {};
    }
  }

  function writeDismissed(map) {
    try {
      window.localStorage.setItem(DISMISS_KEY, JSON.stringify(map));
    } catch (e) { /* ignore */ }
  }

  // Move the banners from the end of #content (where the hook renders them)
  // to the top, right below Redmine's own flash messages, and hide the ones
  // dismissed today.
  function placeBanners() {
    var box = document.getElementById('vacation-messages');
    var content = document.getElementById('content');
    if (!box || !content) return;

    var flashes = content.querySelectorAll(':scope > .flash');
    var anchor = flashes.length ? flashes[flashes.length - 1].nextSibling : content.firstChild;
    content.insertBefore(box, anchor);

    var today = localToday();
    var dismissed = readDismissed();
    // Forget entries from earlier days so storage does not grow forever.
    Object.keys(dismissed).forEach(function (key) {
      if (dismissed[key] !== today) delete dismissed[key];
    });
    writeDismissed(dismissed);

    box.querySelectorAll('.vacation-message[data-dismiss-key]').forEach(function (banner) {
      var key = banner.dataset.dismissKey;
      if (dismissed[key] === today) banner.remove();

      var button = banner.querySelector('.vacation-dismiss');
      if (!button) return;
      button.addEventListener('click', function () {
        var map = readDismissed();
        map[key] = localToday();
        writeDismissed(map);
        banner.remove();
      });
    });
  }

  // ---------------------------------------------------------------- badges

  // Put a small "absent" badge next to every link to a user who is absent
  // today (issue lists, issue details, journals, ...).
  function decorateUserLinks() {
    var data = document.getElementById('vacation-absent-users');
    if (!data) return;

    var absent;
    try {
      absent = JSON.parse(data.textContent);
    } catch (e) {
      return;
    }
    var label = data.dataset.label;

    document.querySelectorAll('a.user[href]').forEach(function (link) {
      if (link.dataset.vacationBadge) return;
      if (link.closest('#vacation-messages')) return;

      var m = /\/users\/(\d+)(?:[?#].*)?$/.exec(link.getAttribute('href'));
      if (!m || !absent[m[1]]) return;

      var badge = document.createElement('span');
      badge.className = 'vacation-badge';
      badge.textContent = label;
      badge.title = absent[m[1]];
      link.insertAdjacentElement('afterend', badge);
      link.dataset.vacationBadge = '1';
    });
  }

  // ---------------------------------------------------------- assignee hint

  function updateAssigneeHint() {
    var hint = document.querySelector('.vacation-assignee-hint[data-hints]');
    var select = document.getElementById('issue_assigned_to_id');
    if (!hint || !select) return;

    // Show the hint right below the assignee field.
    var field = select.closest('p');
    if (field && hint.previousElementSibling !== field) {
      field.insertAdjacentElement('afterend', hint);
    }

    var hints;
    try {
      hints = JSON.parse(hint.dataset.hints);
    } catch (e) {
      return;
    }
    // Only write on change: every write is a DOM mutation, and watchDom()
    // would otherwise call us again forever.
    var text = hints[select.value] || '';
    if (hint.textContent !== text) hint.textContent = text;
    if (hint.hidden !== !text) hint.hidden = !text;
  }

  function initAssigneeHint() {
    updateAssigneeHint();
    // jQuery catches both native changes and the ones Redmine triggers
    // itself (e.g. "Assign to me"); the issue form is also re-rendered via
    // Ajax when tracker or status change.
    if (window.jQuery) {
      window.jQuery(document)
        .on('change', '#issue_assigned_to_id', updateAssigneeHint)
        .on('ajaxComplete', updateAssigneeHint);
    } else {
      document.addEventListener('change', function (event) {
        if (event.target.id === 'issue_assigned_to_id') updateAssigneeHint();
      });
    }
  }

  // ----------------------------------------------------------- user picker

  // Multi-person picker (My page block, home page setting): picking a
  // suggestion adds a chip with a hidden input, the x on a chip removes it.
  // Safe to call repeatedly; My page re-renders blocks via Ajax.
  function initUserPickers() {
    if (!window.jQuery || !window.jQuery.fn.autocomplete) return;

    document.querySelectorAll('.vacation-user-picker:not([data-ready])').forEach(function (picker) {
      picker.dataset.ready = '1';
      var chips = picker.querySelector('.vacation-user-chips');
      var search = picker.querySelector('.vacation-user-picker-search');

      function pickedIds() {
        return Array.prototype.map.call(chips.querySelectorAll('.vacation-user-chip'), function (chip) {
          return chip.dataset.id;
        });
      }

      function addChip(id, name) {
        var chip = document.createElement('span');
        chip.className = 'vacation-user-chip';
        chip.dataset.id = id;
        chip.appendChild(document.createTextNode(name + ' '));

        var input = document.createElement('input');
        input.type = 'hidden';
        input.name = picker.dataset.name;
        input.value = id;
        chip.appendChild(input);

        var remove = document.createElement('button');
        remove.type = 'button';
        remove.className = 'vacation-user-chip-remove';
        remove.title = picker.dataset.removeLabel;
        remove.setAttribute('aria-label', picker.dataset.removeLabel);
        remove.textContent = '\u00d7';
        chip.appendChild(remove);

        chips.appendChild(chip);
      }

      chips.addEventListener('click', function (event) {
        var button = event.target.closest('.vacation-user-chip-remove');
        if (button) button.closest('.vacation-user-chip').remove();
      });

      window.jQuery(search).autocomplete({
        minLength: 1,
        delay: 200,
        source: function (request, response) {
          window.jQuery.getJSON(picker.dataset.url, { term: request.term }, function (users) {
            var picked = pickedIds();
            response(users.filter(function (u) { return picked.indexOf(String(u.id)) === -1; }));
          });
        },
        select: function (event, ui) {
          addChip(ui.item.id, ui.item.label);
          search.value = '';
          return false;
        }
      });
      // Enter in the search field must not submit the surrounding form.
      search.addEventListener('keydown', function (event) {
        if (event.key === 'Enter') event.preventDefault();
      });
    });
  }

  // ------------------------------------------------------------------ form

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

  // Minimal strftime covering Setting::DATE_FORMATS and the locale defaults.
  // value is an <input type="date"> value (YYYY-MM-DD).
  function formatDate(value, el) {
    var m = /^(\d{4})-(\d{2})-(\d{2})$/.exec(value);
    if (!m) return '';
    var month = parseInt(m[2], 10);
    var names = JSON.parse(el.dataset.monthNames || '[]');
    var abbr = JSON.parse(el.dataset.abbrMonthNames || '[]');
    var parts = {
      Y: m[1], y: m[1].slice(-2), m: m[2], d: m[3],
      e: String(parseInt(m[3], 10)), B: names[month] || m[2], b: abbr[month] || m[2]
    };
    return el.dataset.dateFormat.replace(/%-?([YymdeBb%])/g, function (all, key) {
      if (key === '%') return '%';
      return all.charAt(1) === '-' ? String(parseInt(parts[key], 10) || parts[key]) : parts[key];
    });
  }

  // Mirrors VacationMessage#period_text.
  function period(from, until, el) {
    var start = formatDate(from, el);
    var end = formatDate(until, el);
    if (!start && !end) return '';
    if (!start || !end || from === until) return start || end;
    return start + ' - ' + end;
  }

  // Type-ahead for the substitute, using jQuery UI's autocomplete that ships
  // with Redmine. Only a suggestion picked from the list sets the hidden id;
  // free text that matches nobody is cleared when the field loses focus.
  function initSubstituteSearch(input, hidden, onChange) {
    if (!input) return;

    input.addEventListener('input', function () {
      hidden.value = '';
      onChange();
    });
    input.addEventListener('blur', function () {
      if (!hidden.value) input.value = '';
      onChange();
    });

    if (!window.jQuery || !window.jQuery.fn.autocomplete) return;
    window.jQuery(input).autocomplete({
      source: input.dataset.url,
      minLength: 1,
      delay: 200,
      select: function (event, ui) {
        hidden.value = ui.item.id;
        input.value = ui.item.label;
        onChange();
        return false;
      }
    });
  }

  function initForm() {
    var form = document.getElementById('vacation-message-form');
    if (!form) return;

    function field(name) { return form.querySelector('#vacation_message_' + name); }

    var owner = field('user_id');
    var color = field('color');
    var text = field('text');
    var dateFrom = field('date_from');
    var dateUntil = field('date_until');
    var appendDates = field('append_dates');
    var substitute = field('substitute_id');
    var substituteSearch = form.querySelector('.vacation-substitute-search');
    var showBanner = field('show_banner');
    var visibility = field('visibility');
    var recipients = form.querySelectorAll('.vacation-recipients');
    var projects = form.querySelectorAll('.vacation-projects');
    var bannerOptions = form.querySelectorAll('.vacation-banner-options');
    var leadDays = field('lead_days');
    var previews = form.querySelector('.vacation-previews');
    var leadRow = previews.querySelector('.vacation-preview-lead');
    var leadInfo = previews.querySelector('.vacation-preview-lead-info');
    var leadPreview = previews.querySelector('.vacation-preview[data-kind="lead"]');
    var activePreview = previews.querySelector('.vacation-preview[data-kind="active"]');

    // YYYY-MM-DD minus n days; UTC so DST changes cannot shift the date.
    function subtractDays(value, n) {
      var m = /^(\d{4})-(\d{2})-(\d{2})$/.exec(value);
      if (!m) return '';
      var d = new Date(Date.UTC(+m[1], +m[2] - 1, +m[3] - n));
      return d.toISOString().slice(0, 10);
    }

    // Mirrors _banner.html.erb / VacationMessage#banner_text: the lead time
    // only changes the wording; "append period" applies to both.
    function bannerLine(lead) {
      var value = text.value;
      if (appendDates.checked) {
        var p = period(dateFrom.value, dateUntil.value, previews);
        if (p) value += ' (' + p + ')';
      }
      var template = lead ? previews.dataset.templateUpcoming : previews.dataset.template;
      var line = template.replace('%NAME%', previews.dataset.name).replace('%TEXT%', value);
      if (substitute.value && substituteSearch.value) {
        line += ' - ' + previews.dataset.substituteLabel + ': ' + substituteSearch.value;
      }
      return line;
    }

    function updatePreview() {
      var days = parseInt(leadDays.value, 10);
      var hasLead = days > 0;

      leadRow.style.display = hasLead ? '' : 'none';
      if (hasLead) {
        leadPreview.textContent = bannerLine(true);
        applyColor(leadPreview, color.value);
        var start = formatDate(subtractDays(dateFrom.value, days), previews);
        leadInfo.textContent = start ? previews.dataset.leadInfo.replace('%DATE%', start) : '';
      }

      activePreview.textContent = bannerLine(false);
      applyColor(activePreview, color.value);
    }

    function toggle(elements, visible) {
      elements.forEach(function (el) { el.style.display = visible ? '' : 'none'; });
    }

    function toggleSections() {
      toggle(recipients, visibility.value === 'selected');
      toggle(projects, visibility.value === 'project_members');
      toggle(bannerOptions, showBanner.checked);
    }

    form.querySelectorAll('.vacation-preset').forEach(function (button) {
      button.addEventListener('click', function () {
        color.value = button.dataset.color;
        updatePreview();
      });
    });
    [color, text, dateFrom, dateUntil, leadDays].forEach(function (input) {
      // "change" as well: the Redmine datepicker sets values programmatically.
      input.addEventListener('input', updatePreview);
      input.addEventListener('change', updatePreview);
    });
    appendDates.addEventListener('change', updatePreview);
    initSubstituteSearch(substituteSearch, substitute, updatePreview);
    visibility.addEventListener('change', toggleSections);
    showBanner.addEventListener('change', toggleSections);

    // Managers: project, recipient and substitute choices depend on the
    // person, so switching it reloads the form for that person.
    if (owner) {
      owner.addEventListener('change', function () {
        window.location.search = '?user_id=' + encodeURIComponent(owner.value);
      });
    }

    updatePreview();
    toggleSections();
  }

  // Redmine replaces parts of the page in several ways (jQuery Ajax for the
  // issue form, rails-ujs for My page blocks, ...), not all of which fire
  // jQuery's ajaxComplete. Watching the DOM catches every one of them.
  function watchDom() {
    if (!window.MutationObserver) return;
    var scheduled = false;
    new MutationObserver(function () {
      if (scheduled) return;
      scheduled = true;
      window.requestAnimationFrame(function () {
        scheduled = false;
        decorateUserLinks();
        initUserPickers();
        updateAssigneeHint();
      });
    }).observe(document.body, { childList: true, subtree: true });
  }

  document.addEventListener('DOMContentLoaded', function () {
    placeBanners();
    decorateUserLinks();
    initAssigneeHint();
    initUserPickers();
    initForm();
    watchDom();
  });
})();
