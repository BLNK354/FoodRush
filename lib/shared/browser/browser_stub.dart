// Non-web fallbacks for browser.dart. Keep signatures in sync with
// browser_web.dart.

bool get notificationsSupported => false;
bool get notificationsGranted => false;
Future<bool> requestNotificationPermission() async => false;
void showSystemNotification(String title, String body) {}
void playChime() {}
void vibrate() {}
void setTitleBadge(int count) {}
void downloadTextFile(String fileName, String content,
    {String mimeType = 'text/plain'}) {}
String? readPref(String key) => null;
void writePref(String key, String value) {}
void writeSessionValue(String key, String value) {}
bool get canPromptInstall => false;
Future<bool> promptInstall() async => false;
bool get isInstalledApp => true; // native builds are already "installed"
bool get isIos => false;
