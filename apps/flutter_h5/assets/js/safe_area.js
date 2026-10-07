(() => {
  if (window.top !== window) return;
  const safeTop = '__PLANET_SAFE_TOP__px';
  const styleId = 'planet-native-safe-area';

  function applySafeArea() {
    if (!document.documentElement) return false;

    // The root exists before <head> on some WebViews. Set the value now so
    // the first page script and stylesheet can already use it.
    document.documentElement.style.setProperty('--safe-top', safeTop);
    if (!document.head) return false;

    let style = document.getElementById(styleId);
    if (!style) {
      style = document.createElement('style');
      style.id = styleId;
      document.head.appendChild(style);
    }
    style.textContent = `:root { --safe-top: ${safeTop}; }`;
    return true;
  }

  if (!applySafeArea()) {
    const observer = new MutationObserver(() => {
      if (applySafeArea()) observer.disconnect();
    });
    observer.observe(document, { childList: true, subtree: true });
  }
})();
