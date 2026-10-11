// The supplied bundle accesses Sentry unconditionally. Keep rendering possible
// when its remote SDK is slow or unavailable; the real SDK replaces this stub.
window.Sentry = window.Sentry || {
  init() {},
  onLoad() {},
  setTags() {},
  setUser() {},
  addEventProcessor() {},
  captureException() {},
  captureMessage() {},
  browserTracingIntegration() { return {}; },
};
