/// Small browser-only conveniences (system notifications, a chime, the tab
/// title badge, file downloads). On non-web builds every call is a no-op, so
/// callers never need `kIsWeb` checks.
library;

export 'browser_stub.dart' if (dart.library.js_interop) 'browser_web.dart';
