import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../providers/repository.dart';
import 'premium.dart';

/// A person's profile photo, or their initial on the brand gradient when
/// they have none (or the viewer may not see it). Tap to enlarge when
/// [enlarge] is on: stalls use that to match a face at pickup.
class UserAvatar extends StatefulWidget {
  final String? uid;
  final String name;
  final double size;
  final bool enlarge;

  const UserAvatar({
    super.key,
    required this.uid,
    required this.name,
    this.size = 40,
    this.enlarge = false,
  });

  @override
  State<UserAvatar> createState() => _UserAvatarState();
}

class _UserAvatarState extends State<UserAvatar> {
  Stream<String?>? _stream;
  String? _streamUid;

  String get _initial {
    final t = widget.name.trim();
    return t.isEmpty ? '?' : t[0].toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final id = widget.uid;
    if (id == null || id.isEmpty) return _circle(null);
    // Keep one subscription per person across rebuilds.
    if (_streamUid != id) {
      _streamUid = id;
      _stream = Repository.instance.streamAvatar(id);
    }
    final name = widget.name;
    return StreamBuilder<String?>(
      stream: _stream,
      builder: (context, snap) {
        final photo = snap.data;
        final circle = _circle(photo);
        if (!widget.enlarge || photo == null) return circle;
        return Tooltip(
          message: 'View photo',
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: () => showDialog<void>(
              context: context,
              builder: (_) => _PhotoDialog(photo: photo, name: name),
            ),
            child: circle,
          ),
        );
      },
    );
  }

  Widget _circle(String? photo) {
    final size = widget.size;
    final image = brandImage(photo);
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: image == null ? FrGradients.sunset : null,
        image: image == null
            ? null
            : DecorationImage(image: image, fit: BoxFit.cover),
        border: Border.all(color: FrColors.surface, width: size > 60 ? 3 : 1.5),
        boxShadow: size > 60 ? FrShadows.soft : null,
      ),
      child: image == null
          ? Text(_initial,
              style: TextStyle(
                  color: Colors.white,
                  fontSize: size * 0.42,
                  fontWeight: FontWeight.w900))
          : null,
    );
  }
}

class _PhotoDialog extends StatelessWidget {
  final String photo;
  final String name;
  const _PhotoDialog({required this.photo, required this.name});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AspectRatio(
              aspectRatio: 1,
              child: Image(image: brandImage(photo)!, fit: BoxFit.cover),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(name,
                        style: const TextStyle(
                            fontWeight: FontWeight.w800, fontSize: 16)),
                  ),
                  TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Close')),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
