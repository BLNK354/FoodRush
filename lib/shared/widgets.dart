import 'dart:convert';

import 'package:flutter/material.dart';

import '../core/constants.dart';
import '../core/theme.dart';

// ---------------------------------------------------------------------------
// Page scaffold (nav rails are provided by role shells)
// ---------------------------------------------------------------------------

/// Standard inner page: header row + scrollable content.
class FrPage extends StatelessWidget {
  final String title;
  final String? subtitle;
  final List<Widget>? actions;
  final List<Widget> children;
  final EdgeInsets padding;

  const FrPage({
    super.key,
    required this.title,
    this.subtitle,
    this.actions,
    required this.children,
    this.padding = const EdgeInsets.all(24),
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: Theme.of(context)
                            .textTheme
                            .headlineSmall
                            ?.copyWith(fontWeight: FontWeight.w800)),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(subtitle!,
                          style: const TextStyle(
                              color: FrColors.muted, fontSize: 13.5)),
                    ],
                  ],
                ),
              ),
              ...?actions,
            ],
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: padding,
            // Align(topCenter) + ConstrainedBox instead of Center: shrink-wrap
            // centering under an unbounded scroll viewport has been observed to
            // trip 'RenderBox was not laid out' asserts in web debug builds
            // when data lands mid-frame, and top-aligning is the correct
            // behavior for short pages anyway.
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1100),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: children,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Building blocks
// ---------------------------------------------------------------------------

class StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color? color;

  const StatCard({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final c = color ?? FrColors.primary;
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        // Column, not Row: at phone widths a Row squeezes the text column so
        // hard that words break mid-letter ("Custo mers").
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: c.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(FrRadius.md),
                  ),
                  child: Icon(icon, color: c, size: 22),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: FrColors.muted, fontSize: 12.5),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(value,
                style: const TextStyle(
                    fontSize: 22, fontWeight: FontWeight.w800)),
          ],
        ),
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? message;
  final Widget? action;

  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56, color: FrColors.muted.withValues(alpha: 0.5)),
            const SizedBox(height: 12),
            Text(title,
                style: const TextStyle(
                    fontSize: 17, fontWeight: FontWeight.w700)),
            if (message != null) ...[
              const SizedBox(height: 4),
              Text(
                message!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: FrColors.muted, fontSize: 13.5),
              ),
            ],
            if (action != null) ...[const SizedBox(height: 16), action!],
          ],
        ),
      ),
    );
  }
}

/// Colored chip for order / payment status.
class StatusChip extends StatelessWidget {
  final String label;
  final Color color;
  const StatusChip(this.label, {super.key, required this.color});

  static StatusChip order(String status) {
    final (label, color) = switch (status) {
      kOrderAwaitingPayment => ('Awaiting payment', FrColors.warning),
      kOrderProofSubmitted => ('Receipt submitted', FrColors.info),
      kOrderAccepted => ('Accepted', FrColors.info),
      kOrderPreparing => ('Preparing', FrColors.secondary),
      kOrderReady => ('Ready for pickup', FrColors.success),
      kOrderCompleted => ('Completed', FrColors.muted),
      kOrderRejected => ('Rejected', FrColors.danger),
      kOrderCancelled => ('Cancelled', FrColors.muted),
      _ => (status, FrColors.muted),
    };
    return StatusChip(label, color: color);
  }

  static StatusChip proof(String status) => switch (status) {
        'pending' => const StatusChip('Pending review', color: FrColors.warning),
        'verified' => const StatusChip('Verified', color: FrColors.success),
        'rejected' => const StatusChip('Rejected', color: FrColors.danger),
        _ => StatusChip(status, color: FrColors.muted),
      };

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(FrRadius.sm),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class FrTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String? hint;
  final bool obscure;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;
  final int maxLines;
  final Widget? suffix;
  final bool enabled;

  const FrTextField({
    super.key,
    required this.controller,
    required this.label,
    this.hint,
    this.obscure = false,
    this.keyboardType,
    this.validator,
    this.maxLines = 1,
    this.suffix,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      obscureText: obscure,
      keyboardType: keyboardType,
      validator: validator,
      maxLines: maxLines,
      enabled: enabled,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        suffixIcon: suffix,
        alignLabelWithHint: maxLines > 1,
      ),
    );
  }
}

class SectionHeader extends StatelessWidget {
  final String title;
  final Widget? trailing;
  const SectionHeader(this.title, {super.key, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, top: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(title,
                style: const TextStyle(
                    fontSize: 16.5, fontWeight: FontWeight.w800)),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

String peso(num amount) {
  final v = amount.toDouble();
  final s = v == v.roundToDouble()
      ? v.toStringAsFixed(0)
      : v.toStringAsFixed(2);
  return '₱$s';
}

/// Image widget that accepts both data URLs (Firestore-stored images) and
/// http(s) URLs (legacy Cloud Storage links).
class FrImage extends StatelessWidget {
  final String? url;
  final BoxFit fit;
  final double? width;
  final double? height;

  const FrImage(this.url, {super.key, this.fit = BoxFit.cover, this.width, this.height});

  @override
  Widget build(BuildContext context) {
    final u = url;
    if (u == null || u.isEmpty) {
      return const Center(child: Icon(Icons.image_not_supported_outlined));
    }
    if (u.startsWith('data:')) {
      final b64 = u.split(',').last;
      try {
        return Image.memory(
          const Base64Decoder().convert(b64),
          fit: fit,
          width: width,
          height: height,
          gaplessPlayback: true,
        );
      } catch (_) {
        return const Center(child: Icon(Icons.broken_image_outlined));
      }
    }
    return Image.network(u, fit: fit, width: width, height: height);
  }
}

void showSnack(BuildContext context, String message, {bool error = false}) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message),
      backgroundColor: error ? FrColors.danger : null,
    ),
  );
}

Future<bool> confirmDialog(
  BuildContext context, {
  required String title,
  String? message,
  String confirmLabel = 'Confirm',
  bool destructive = false,
}) async {
  final res = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: message == null ? null : Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          style: destructive
              ? FilledButton.styleFrom(backgroundColor: FrColors.danger)
              : null,
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return res ?? false;
}
