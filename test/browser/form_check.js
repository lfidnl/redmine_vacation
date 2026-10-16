// Browser regression check for the absence form (/my/vacation_messages/new).
// Paste into the browser console (or run via a browser automation tool) on
// the "New absence" page. Returns { passed, failures }.
//
// Covers every combination the preview has to get right: lead time 0 / > 0,
// "append period" on / off, substitute, colour, "show banner" and the
// visibility-dependent sections. The server side of the same rules is
// covered by test/integration/vacation_hooks_test.rb.
(function () {
  var failures = [];
  var passed = 0;

  function f(id) { return document.getElementById('vacation_message_' + id); }
  function fire(el, type) { el.dispatchEvent(new Event(type, { bubbles: true })); }
  function set(id, value) {
    var el = f(id);
    el.value = value;
    fire(el, 'input');
    fire(el, 'change');
  }
  function check(id, value) {
    var el = f(id);
    if (el.checked !== value) el.click();
  }
  function shown(el) { return el.offsetParent !== null; }
  function preview(kind) { return document.querySelector('.vacation-preview[data-kind="' + kind + '"]'); }
  function text(kind) { return preview(kind).textContent.trim(); }
  function expect(label, actual, expected) {
    if (actual === expected) {
      passed++;
    } else {
      failures.push(label + ': expected ' + JSON.stringify(expected) + ', got ' + JSON.stringify(actual));
    }
  }
  function expectMatch(label, actual, regexp, shouldMatch) {
    expect(label, regexp.test(actual), shouldMatch !== false);
  }

  set('date_from', '2026-12-14');
  set('date_until', '2027-01-10');
  set('text', 'Winterurlaub');
  set('substitute_id', '');
  document.getElementById('vacation_substitute_search').value = '';
  check('show_banner', true);
  var period = /\(.+ - .+\)$/;

  [0, 7].forEach(function (lead) {
    set('lead_days', String(lead));
    [true, false].forEach(function (append) {
      check('append_dates', append);
      var tag = 'lead=' + lead + ' append=' + append;

      expect(tag + ' lead row visible', shown(preview('lead')), lead > 0);
      expectMatch(tag + ' active text', text('active'), /Winterurlaub/);
      expectMatch(tag + ' active period', text('active'), period, append);
      if (lead > 0) {
        expectMatch(tag + ' lead text', text('lead'), /Winterurlaub/);
        expectMatch(tag + ' lead period', text('lead'), period, append);
        expect(tag + ' lead wording differs', text('lead') !== text('active'), true);
        expectMatch(tag + ' lead info has date', document.querySelector('.vacation-preview-lead-info').textContent, /\d/);
      }
    });
  });

  // Single day: no range, just the date.
  check('append_dates', true);
  set('date_until', '2026-12-14');
  expectMatch('single day period', text('active'), /\([^-]+\)$/);
  set('date_until', '2027-01-10');

  // Substitute: only a suggestion picked from the list counts. Simulated by
  // setting the hidden id and the visible name like the autocomplete does.
  var search = document.getElementById('vacation_substitute_search');
  set('lead_days', '3');
  f('substitute_id').value = '999';
  search.value = 'Dana Vertretung';
  fire(f('append_dates'), 'change');
  expectMatch('substitute in active', text('active'), /Dana Vertretung/);
  expectMatch('substitute in lead', text('lead'), /Dana Vertretung/);
  search.value = 'Dan';
  fire(search, 'input');
  expect('typing clears hidden id', f('substitute_id').value, '');
  expectMatch('typed text without pick not in preview', text('active'), /Dan/, false);
  fire(search, 'blur');
  expect('blur without pick clears text', search.value, '');

  // Colour applies to both previews.
  set('lead_days', '3');
  set('color', '#003366');
  expect('colour active', preview('active').style.backgroundColor, 'rgb(0, 51, 102)');
  expect('colour lead', preview('lead').style.backgroundColor, 'rgb(0, 51, 102)');
  expect('dark colour -> white text', preview('active').style.color, 'rgb(255, 255, 255)');
  set('color', '#ffe3e3');

  // Banner switch hides colour, lead time and previews.
  check('show_banner', false);
  expect('banner off hides options', shown(f('color')), false);
  check('show_banner', true);
  expect('banner on shows options', shown(f('color')), true);

  // Visibility-dependent sections.
  set('visibility', 'selected');
  expect('selected shows recipients', shown(f('principal_ids')), true);
  expect('selected hides projects', shown(f('project_ids')), false);
  set('visibility', 'project_members');
  expect('project_members shows projects', shown(f('project_ids')), true);
  expect('project_members hides recipients', shown(f('principal_ids')), false);
  set('visibility', 'logged');
  expect('logged hides both', shown(f('project_ids')) || shown(f('principal_ids')), false);

  set('lead_days', '0');
  return { passed: passed, failures: failures };
})();
