import 'dart:js_interop';

@JS('gtag')
external void _gtag(JSAny? command, JSAny? eventName, JSAny? params);

/// Sends a GA4 event straight through the gtag.js loaded in index.html. Used on
/// web because the firebase_analytics web plugin doesn't reliably deliver custom
/// events. gtag is a global defined in web/index.html.
void gtagEvent(String name, Map<String, Object> params) {
  try {
    _gtag('event'.toJS, name.toJS, params.jsify());
  } catch (_) {}
}
