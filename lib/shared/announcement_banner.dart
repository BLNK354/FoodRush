import 'dart:async';

import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../models/misc.dart';
import '../providers/repository.dart';

/// Shows the admin's announcement above [child] in every signed-in area.
/// Dismissing hides that version for the rest of the session; editing the
/// announcement (new updatedAt) shows it again.
class WithAnnouncement extends StatefulWidget {
  final Widget child;
  const WithAnnouncement({super.key, required this.child});

  @override
  State<WithAnnouncement> createState() => _WithAnnouncementState();
}

class _WithAnnouncementState extends State<WithAnnouncement> {
  static final _dismissed = <String>{};
  StreamSubscription<Announcement>? _sub;
  Announcement? _a;

  @override
  void initState() {
    super.initState();
    _sub = Repository.instance.streamAnnouncement().listen(
          (a) => mounted ? setState(() => _a = a) : null,
          onError: (Object _) {}, // no banner is better than a broken page
        );
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  String _key(Announcement a) =>
      '${a.updatedAt?.millisecondsSinceEpoch}:${a.message}';

  @override
  Widget build(BuildContext context) {
    final a = _a;
    final show = a != null && a.visible && !_dismissed.contains(_key(a));
    if (!show) return widget.child;
    final color = a.level == 'warning' ? FrColors.warning : FrColors.info;
    return Column(
      children: [
        Material(
          color: color.withValues(alpha: 0.14),
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 4, 8),
              child: Row(
                children: [
                  Icon(
                    a.level == 'warning'
                        ? Icons.warning_amber_rounded
                        : Icons.campaign_outlined,
                    color: color,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(a.message,
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                  ),
                  IconButton(
                    tooltip: 'Dismiss',
                    icon: const Icon(Icons.close, size: 18),
                    onPressed: () => setState(() => _dismissed.add(_key(a))),
                  ),
                ],
              ),
            ),
          ),
        ),
        Expanded(child: widget.child),
      ],
    );
  }
}
