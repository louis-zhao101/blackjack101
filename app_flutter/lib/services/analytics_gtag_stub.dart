/// Non-web stub: on mobile, custom events go through firebase_analytics, so
/// there's nothing to do here. Replaced by [analytics_gtag_web.dart] on web via
/// a conditional import.
void gtagEvent(String name, Map<String, Object> params) {}
