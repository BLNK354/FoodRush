import 'dart:js_interop';

import 'package:web/web.dart' as web;

import '../../core/constants.dart';

// Every call is best-effort: browsers block these APIs in many situations
// (no user gesture yet, permission denied, private mode), and an alert that
// fails must never break the page.

bool get notificationsSupported {
  try {
    web.Notification.permission;
    return true;
  } catch (_) {
    return false;
  }
}

bool get notificationsGranted {
  try {
    return web.Notification.permission == 'granted';
  } catch (_) {
    return false;
  }
}

/// Must be called from a user gesture (button tap) or browsers ignore it.
Future<bool> requestNotificationPermission() async {
  try {
    final result = await web.Notification.requestPermission().toDart;
    return result.toDart == 'granted';
  } catch (_) {
    return false;
  }
}

void showSystemNotification(String title, String body) {
  if (!notificationsGranted) return;
  try {
    final n = web.Notification(
      title,
      web.NotificationOptions(body: body, icon: 'icons/Icon-192.png'),
    );
    n.onclick = ((web.Event _) {
      web.window.focus();
      n.close();
    }).toJS;
  } catch (_) {}
}

web.AudioContext? _audio;

/// Short two-note chime, synthesized (no audio asset to load).
void playChime() {
  try {
    final ctx = _audio ??= web.AudioContext();
    const notes = [880.0, 1320.0];
    for (var i = 0; i < notes.length; i++) {
      final start = ctx.currentTime + i * 0.18;
      final osc = ctx.createOscillator();
      final gain = ctx.createGain();
      osc.frequency.setValueAtTime(notes[i], start);
      gain.gain.setValueAtTime(0.0001, start);
      gain.gain.exponentialRampToValueAtTime(0.25, start + 0.02);
      gain.gain.exponentialRampToValueAtTime(0.0001, start + 0.35);
      osc.connect(gain);
      gain.connect(ctx.destination);
      osc.start(start);
      osc.stop(start + 0.4);
    }
  } catch (_) {}
}

void vibrate() {
  try {
    web.window.navigator.vibrate([200, 100, 200].jsify()!);
  } catch (_) {}
}

/// "(2) FoodRush" in the tab while something needs attention; 0 clears it.
void setTitleBadge(int count) {
  try {
    web.document.title = count > 0 ? '($count) $kAppName' : kAppName;
  } catch (_) {}
}

/// Saves [content] as a file via a temporary blob link.
void downloadTextFile(String fileName, String content,
    {String mimeType = 'text/plain'}) {
  final blob = web.Blob(
    [content.toJS].toJS,
    web.BlobPropertyBag(type: '$mimeType;charset=utf-8'),
  );
  final url = web.URL.createObjectURL(blob);
  final a = web.HTMLAnchorElement()
    ..href = url
    ..download = fileName;
  web.document.body?.append(a);
  a.click();
  a.remove();
  web.URL.revokeObjectURL(url);
}

/// Small per-browser preference (e.g. theme mode). Null when storage is
/// unavailable (private mode, blocked site data).
String? readPref(String key) {
  try {
    return web.window.localStorage.getItem('foodrush.$key');
  } catch (_) {
    return null;
  }
}

/// Raw sessionStorage write (no app prefix), for library-owned keys.
void writeSessionValue(String key, String value) {
  try {
    web.window.sessionStorage.setItem(key, value);
  } catch (_) {}
}

void writePref(String key, String value) {
  try {
    web.window.localStorage.setItem('foodrush.$key', value);
  } catch (_) {}
}
