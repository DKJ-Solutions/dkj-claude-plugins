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
     <script src="house-theme.js"></script>         (in <head>, so nothing flashes)
     DKJTheme.picker(document.getElementById('theme'))   (draws the picker)
     DKJTheme.picker(el, { light: 'Light', dark: 'Dark' }) (row labels for an app in another language)
     DKJTheme.set('ochre') / DKJTheme.reset() / DKJTheme.current()
   ========================================================================== */
(function () {
  var THEMES = [
    { id: 'magenta', name: 'Magenta',     mode: 'light', hex: '#c0258f' },
    { id: 'purple',  name: 'Paars',       mode: 'light', hex: '#7a3fd6' },
    { id: 'blue',    name: 'Blauw',       mode: 'light', hex: '#2563d0' },
    { id: 'teal',    name: 'Petrol',      mode: 'light', hex: '#0f7c86' },
    { id: 'ochre',   name: 'Oker',        mode: 'light', hex: '#7a6b00' },
    { id: 'rust',    name: 'Roest',       mode: 'light', hex: '#ad5a0a' },
    { id: 'pink',    name: 'Roze',        mode: 'dark',  hex: '#ff7ac8' },
    { id: 'lilac',   name: 'Lila',        mode: 'dark',  hex: '#b69cff' },
    { id: 'sky',     name: 'Hemelsblauw', mode: 'dark',  hex: '#5cb3ff' },
    { id: 'cyan',    name: 'Cyaan',       mode: 'dark',  hex: '#2fc8d8' },
    { id: 'yellow',  name: 'Geel',        mode: 'dark',  hex: '#f2c230' },
    { id: 'orange',  name: 'Oranje',      mode: 'dark',  hex: '#f5873a' }
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
    /* the colour goes in through the CSSOM, so a strict style-src policy does not block it */
    var buttons = el.querySelectorAll('.theme-swatch');
    for (var i = 0; i < buttons.length; i++) buttons[i].style.setProperty('--swatch', byId(buttons[i].getAttribute('data-id')).hex);
    if (pickers.indexOf(el) < 0) { el.addEventListener('click', onPick); pickers.push(el); }
    render();
  }
  function set(id) { if (!byId(id)) return; try { localStorage.setItem(key, id); } catch (e) {} apply(); }
  function reset() { try { localStorage.removeItem(key); } catch (e) {} apply(); }

  if (window.matchMedia) {
    var mq = matchMedia('(prefers-color-scheme: dark)');
    var onChange = function () { if (!byId(stored())) apply(); };
    if (mq.addEventListener) mq.addEventListener('change', onChange); else if (mq.addListener) mq.addListener(onChange);
  }
  apply();
  window.DKJTheme = { themes: THEMES.slice(), set: set, reset: reset, picker: picker, current: function () { return root.getAttribute('data-theme'); } };
})();
