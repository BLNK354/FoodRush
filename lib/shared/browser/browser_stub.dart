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
