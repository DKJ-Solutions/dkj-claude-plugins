/* ==========================================================================
   DKJ-Solutions house theme -- the theme choice and the picker
   --------------------------------------------------------------------------
   Companion to house-style.css. It picks one of the twelve themes the
   stylesheet defines and sets it as <html data-theme="...">.

   Which theme applies, in this order:
     1. the user's own choice, remembered per app on this device;
     2. otherwise the app's own default for the OS mode, declared on <html>:
        <html data-theme-light="purple" data-theme-dark="cyan">
        (an app picks its own pair, so apps are told apart before anyone chooses);
     3. otherwise the house defaults, Blauw (light) and Cyaan (dark).
   Without this script the stylesheet still works: no data-theme follows the
   OS with the house defaults. A page that ships data-theme="light" or "dark"
   keeps that mode: the script then picks that mode's default, not the OS's.

   Use:
     a script element with src="house-theme.js"     (in <head>, so nothing flashes;
                                                     inlining this file verbatim is fine too)
     DKJTheme.picker(document.getElementById('theme'))   (draws the picker)
     DKJTheme.picker(el, { light: 'Light', dark: 'Dark' }) (row labels for an app in another language)
     DKJTheme.settings(el, options)                  (draws the settings button: a round toggle
                                                     and a panel with the picker and a reset; returns
                                                     the panel's slot for the app's own controls)
     DKJTheme.set('ochre') / DKJTheme.reset() / DKJTheme.current()
   ========================================================================== */
(function () {
  var THEMES = [
    { id: 'magenta', name: 'Magenta',     mode: 'light', hex: '#720252' },
    { id: 'purple',  name: 'Paars',       mode: 'light', hex: '#4f0399' },
    { id: 'blue',    name: 'Blauw',       mode: 'light', hex: '#0704c0' },
    { id: 'teal',    name: 'Petrol',      mode: 'light', hex: '#02494f' },
    { id: 'ochre',   name: 'Oker',        mode: 'light', hex: '#494001' },
    { id: 'rust',    name: 'Roest',       mode: 'light', hex: '#633001' },
    { id: 'pink',    name: 'Roze',        mode: 'dark',  hex: '#fe97d0' },
    { id: 'lilac',   name: 'Lila',        mode: 'dark',  hex: '#c2affe' },
    { id: 'sky',     name: 'Hemelsblauw', mode: 'dark',  hex: '#b5b5fe' },
    { id: 'cyan',    name: 'Cyaan',       mode: 'dark',  hex: '#0fd6e8' },
    { id: 'yellow',  name: 'Geel',        mode: 'dark',  hex: '#e8b70c' },
    { id: 'orange',  name: 'Oranje',      mode: 'dark',  hex: '#fea56e' }
  ];
  var HOUSE_DEFAULT = { light: 'blue', dark: 'cyan' };
  var root = document.documentElement;
  /* storage is per origin, so each app on its own origin keeps its own choice; two apps sharing
     an origin tell their choices apart with <html data-theme-key="app-name"> */
  var key = 'dkj-theme' + (root.getAttribute('data-theme-key') ? ':' + root.getAttribute('data-theme-key') : '');
  var byId = function (id) { for (var i = 0; i < THEMES.length; i++) if (THEMES[i].id === id) return THEMES[i]; return null; };

  function stored() { try { return localStorage.getItem(key); } catch (e) { return null; } }
  function osMode() { return window.matchMedia && matchMedia('(prefers-color-scheme: dark)').matches ? 'dark' : 'light'; }
  function appDefault(mode) {
    var id = root.getAttribute('data-theme-' + mode);
    var t = byId(id);
    return t && t.mode === mode ? t.id : HOUSE_DEFAULT[mode];
  }
  /* a page that ships data-theme="light"/"dark" has fixed its mode; honour it */
  var shipped = root.getAttribute('data-theme');
  var fixedMode = shipped === 'light' || shipped === 'dark' ? shipped : null;
  function resolve() { var s = stored(); return byId(s) ? s : appDefault(fixedMode || osMode()); }
  function apply() { root.setAttribute('data-theme', resolve()); render(); }

  var pickers = [];
  function render() {
    var now = root.getAttribute('data-theme');
    for (var i = 0; i < pickers.length; i++) {
      var buttons = pickers[i].querySelectorAll('.theme-swatch');
      for (var j = 0; j < buttons.length; j++) buttons[j].setAttribute('aria-pressed', String(buttons[j].getAttribute('data-id') === now));
    }
  }
  /* the swatch a click landed in, without relying on Element.closest */
  function swatchOf(node, el) {
    for (; node && node !== el; node = node.parentNode)
      if (node.classList && node.classList.contains('theme-swatch')) return node;
    return null;
  }
  function onPick(e) { var b = swatchOf(e.target, e.currentTarget); if (b) set(b.getAttribute('data-id')); }
  /* the theme names are Dutch on purpose (DKJ-Solutions apps are Dutch); the row labels can be
     given in another language: picker(el, { light: 'Light', dark: 'Dark' }) */
  function picker(el, labels) {
    if (!el) return;
    labels = labels || {};
    var text = { light: labels.light || 'Licht', dark: labels.dark || 'Donker' };
    var html = '';
    ['light', 'dark'].forEach(function (mode) {
      html += '<div class="theme-picker__row"><span class="theme-picker__label">' + text[mode] + '</span>' +
        '<div class="theme-picker__swatches" role="group" aria-label="' + text[mode] + '">';
      THEMES.filter(function (t) { return t.mode === mode; }).forEach(function (t) {
        html += '<button type="button" class="theme-swatch theme-swatch--' + mode + '" data-id="' + t.id +
          '" aria-label="' + t.name + '" title="' + t.name + '" aria-pressed="false"><i></i></button>';
      });
      html += '</div></div>';
    });
    el.classList.add('theme-picker');
    el.innerHTML = html;
    /* the colours come from house-style.css: each theme block also matches .theme-swatch[data-id] */
    if (pickers.indexOf(el) < 0) { el.addEventListener('click', onPick); pickers.push(el); }
    render();
  }
  /* The settings button: a round toggle that opens a panel with the picker and a reset.
     settings(el, { label, title, theme, reset, light, dark }) -- every text is optional (Dutch by
     default, like the picker) and goes in as HTML, like the picker's labels: pass the app's own
     texts, never user input. Returns the panel's .theme-settings__extra element, where an app
     adds controls of its own. The panel closes on the toggle, Escape (focus goes back to the
     toggle), a click outside it and focus leaving it -- never on a click inside it. Drawing the
     same element twice returns the existing slot. */
  var ICON = '<svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true" focusable="false"';
  var GEAR = ICON + ' class="theme-settings__open"><circle cx="12" cy="12" r="3"/><path d="M19.4 15a1.65 1.65 0 0 0 .33 1.82l.06.06a2 2 0 1 1-2.83 2.83l-.06-.06a1.65 1.65 0 0 0-1.82-.33 1.65 1.65 0 0 0-1 1.51V21a2 2 0 1 1-4 0v-.09A1.65 1.65 0 0 0 9 19.4a1.65 1.65 0 0 0-1.82.33l-.06.06a2 2 0 1 1-2.83-2.83l.06-.06A1.65 1.65 0 0 0 4.68 15a1.65 1.65 0 0 0-1.51-1H3a2 2 0 1 1 0-4h.09A1.65 1.65 0 0 0 4.6 9a1.65 1.65 0 0 0-.33-1.82l-.06-.06a2 2 0 1 1 2.83-2.83l.06.06A1.65 1.65 0 0 0 9 4.68a1.65 1.65 0 0 0 1-1.51V3a2 2 0 1 1 4 0v.09a1.65 1.65 0 0 0 1 1.51 1.65 1.65 0 0 0 1.82-.33l.06-.06a2 2 0 1 1 2.83 2.83l-.06.06A1.65 1.65 0 0 0 19.4 9a1.65 1.65 0 0 0 1.51 1H21a2 2 0 1 1 0 4h-.09a1.65 1.65 0 0 0-1.51 1z"/></svg>';
  var CROSS = ICON + ' class="theme-settings__close"><path d="M18 6 6 18M6 6l12 12"/></svg>';
  var settingsCount = 0;
  function settings(el, opts) {
    if (!el) return null;
    var drawn = el.querySelector('.theme-settings__extra');
    if (drawn) return drawn;
    opts = opts || {};
    var id = 'theme-settings-' + (++settingsCount);
    var label = opts.label || 'Instellingen';
    el.classList.add('theme-settings');
    el.innerHTML =
      '<button type="button" class="theme-settings__toggle" aria-expanded="false" aria-controls="' + id +
        '" aria-label="' + label + '" title="' + label + '">' + GEAR + CROSS + '</button>' +
      '<div class="theme-settings__panel" id="' + id + '" role="group" aria-labelledby="' + id + '-title" hidden>' +
        '<p class="theme-settings__title" id="' + id + '-title">' + (opts.title || label) + '</p>' +
        '<div class="theme-settings__group"><span class="theme-settings__label">' + (opts.theme || 'Thema') + '</span>' +
          '<div class="theme-settings__picker"></div></div>' +
        '<div class="theme-settings__group theme-settings__foot"><div class="theme-settings__extra"></div>' +
          '<button type="button" class="btn theme-settings__reset">' + (opts.reset || 'Standaardthema') + '</button></div>' +
      '</div>';
    var toggle = el.querySelector('.theme-settings__toggle');
    var panel = el.querySelector('.theme-settings__panel');
    function show(open) { panel.hidden = !open; toggle.setAttribute('aria-expanded', String(open)); }
    toggle.addEventListener('click', function () { show(panel.hidden); });
    el.querySelector('.theme-settings__reset').addEventListener('click', reset);
    /* the document listeners remove themselves once el has left the page, so a redraw leaks nothing */
    function gone() {
      if (document.documentElement.contains(el)) return false;
      document.removeEventListener('keydown', onKey);
      document.removeEventListener('pointerdown', onPointer);
      return true;
    }
    function onKey(e) {
      if (gone() || panel.hidden || (e.key !== 'Escape' && e.key !== 'Esc')) return;
      var inside = el.contains(document.activeElement);
      show(false);
      if (inside) toggle.focus();   /* focus elsewhere on the page stays where it is */
    }
    /* a click outside closes it; a click inside, on a control or not, never does */
    function onPointer(e) { if (!gone() && !panel.hidden && !el.contains(e.target)) show(false); }
    document.addEventListener('keydown', onKey);
    document.addEventListener('pointerdown', onPointer);
    /* focus moving to an element outside closes it; a null relatedTarget is a click, decided above */
    el.addEventListener('focusout', function (e) { if (e.relatedTarget && !el.contains(e.relatedTarget)) show(false); });
    picker(el.querySelector('.theme-settings__picker'), { light: opts.light, dark: opts.dark });
    return el.querySelector('.theme-settings__extra');
  }
  function set(id) { if (!byId(id)) return; try { localStorage.setItem(key, id); } catch (e) {} apply(); }
  function reset() { try { localStorage.removeItem(key); } catch (e) {} apply(); }

  if (window.matchMedia) {
    var mq = matchMedia('(prefers-color-scheme: dark)');
    var onChange = function () { if (!byId(stored())) apply(); };
    if (mq.addEventListener) mq.addEventListener('change', onChange); else if (mq.addListener) mq.addListener(onChange);
  }
  apply();
  window.DKJTheme = { themes: THEMES.slice(), set: set, reset: reset, picker: picker, settings: settings, current: function () { return root.getAttribute('data-theme'); } };
})();
