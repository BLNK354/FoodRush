import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/branding.dart';
import '../shared/browser/browser.dart' as browser;
import 'repository.dart';

/// The admin's Branding, live from Firestore. The last copy is kept in the
/// browser so the next visit starts in the right colours instead of
/// flashing the stock look while it loads.
///
/// The Branding editor can [preview] a draft: the whole app restyles in
/// that admin's browser only, until [endPreview] (or a save) settles it.
class BrandingController extends Notifier<Branding> {
  static const _cacheKey = 'branding';

  /// What this browser saw last time (or the stock look).
  static Branding cached() =>
      Branding.fromJson(browser.readPref(_cacheKey)) ?? Branding.defaults;

  /// The latest saved look (what everyone else sees).
  Branding _live = Branding.defaults;
  bool _previewing = false;

  Branding get live => _live;

  @override
  Branding build() {
    _live = cached();
    final sub = Repository.instance.streamBranding().listen((b) {
      _live = b;
      browser.writePref(_cacheKey, b.toJson());
      if (!_previewing && b != state) state = b;
    }, onError: (Object _) {
      // Offline or rules not deployed yet: keep the cached look.
    });
    ref.onDispose(sub.cancel);
    return _live;
  }

  void preview(Branding draft) {
    _previewing = true;
    if (draft != state) state = draft;
  }

  void endPreview() {
    _previewing = false;
    if (state != _live) state = _live;
  }
}

final brandingProvider =
    NotifierProvider<BrandingController, Branding>(BrandingController.new);
