import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/constants.dart';
import '../core/i18n.dart';
import '../core/theme.dart';
import '../models/user.dart';
import 'premium.dart';

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

  /// False when the first child is its own hero header.
  final bool showHeader;

  const FrPage({
    super.key,
    required this.title,
    this.subtitle,
    this.actions,
    required this.children,
    this.padding = const EdgeInsets.all(24),
    this.showHeader = true,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (showHeader)
          FadeSlideIn(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 22, 24, 0),
              child: Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1100),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              style: Theme.of(context).textTheme.headlineMedium,
                            ),
                            if (subtitle != null) ...[
                              const SizedBox(height: 4),
                              Text(
                                subtitle!,
                                style: TextStyle(
                                  color: FrColors.muted,
                                  fontSize: 14,
                                  height: 1.4,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      ...?actions,
                    ],
                  ),
                ),
              ),
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
                  children: [
                    for (var i = 0; i < children.length; i++)
                      FadeSlideIn(index: i + 1, child: children[i]),
                  ],
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
    return PremiumCard(
      padding: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        // Column, not Row: at phone widths a Row squeezes the text column so
        // hard that words break mid-letter ("Custo mers").
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color.lerp(c, Colors.white, 0.25)!, c],
                    ),
                    borderRadius: BorderRadius.circular(FrRadius.md),
                    boxShadow: [
                      BoxShadow(
                        color: c.withValues(alpha: 0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Icon(icon, color: Colors.white, size: 21),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: FrColors.muted, fontSize: 12.5),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              value,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.6,
              ),
            ),
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
            _FloatingOrb(icon: icon),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.4,
              ),
            ),
            if (message != null) ...[
              const SizedBox(height: 4),
              Text(
                message!,
                textAlign: TextAlign.center,
                style: TextStyle(color: FrColors.muted, fontSize: 13.5),
              ),
            ],
            if (action != null) ...[const SizedBox(height: 20), action!],
          ],
        ),
      ),
    );
  }
}

/// EmptyState's gently bobbing 3D orb.
class _FloatingOrb extends StatefulWidget {
  final IconData icon;
  const _FloatingOrb({required this.icon});

  @override
  State<_FloatingOrb> createState() => _FloatingOrbState();
}

class _FloatingOrbState extends State<_FloatingOrb>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2600),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (reduceMotion(context)) {
      _c.stop();
    } else if (!_c.isAnimating) {
      _c.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final v = Curves.easeInOut.transform(_c.value);
        return Transform.translate(
          offset: Offset(0, -8 * v),
          child: ClayOrb(
            icon: widget.icon,
            size: 84,
            colors: const [Color(0xFFFFB199), Color(0xFFE5484D)],
            shadowLift: v,
          ),
        );
      },
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
    'pending' => StatusChip('Pending review', color: FrColors.warning),
    'verified' => StatusChip('Verified', color: FrColors.success),
    'rejected' => StatusChip('Rejected', color: FrColors.danger),
    _ => StatusChip(status, color: FrColors.muted),
  };

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 5, 11, 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

/// Compact segmented progress through the pickup flow, with a
/// "Step n of m · label" caption. Cash orders skip the receipt step.
/// Renders nothing for rejected/cancelled orders — the StatusChip says it.
class OrderProgressBar extends StatelessWidget {
  final String status;
  final String paymentMethod;
  const OrderProgressBar({
    super.key,
    required this.status,
    required this.paymentMethod,
  });

  @override
  Widget build(BuildContext context) {
    final steps = paymentMethod == kPayCash
        ? kOrderStatusFlow.where((s) => s != kOrderProofSubmitted).toList()
        : kOrderStatusFlow;
    final idx = steps.indexOf(status);
    if (idx < 0) return const SizedBox.shrink();
    final color = status == kOrderReady || status == kOrderCompleted
        ? FrColors.success
        : FrColors.primary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            for (var i = 0; i < steps.length; i++) ...[
              if (i > 0) const SizedBox(width: 4),
              Expanded(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 500),
                  curve: Curves.easeOutCubic,
                  height: 7,
                  decoration: BoxDecoration(
                    color: i <= idx
                        ? null
                        : FrColors.muted.withValues(alpha: 0.16),
                    gradient: i <= idx
                        ? LinearGradient(
                            colors: [
                              Color.lerp(color, Colors.white, 0.25)!,
                              color,
                            ],
                          )
                        : null,
                    borderRadius: BorderRadius.circular(4),
                    boxShadow: i == idx
                        ? [
                            BoxShadow(
                              color: color.withValues(alpha: 0.4),
                              blurRadius: 8,
                            ),
                          ]
                        : null,
                  ),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 6),
        Text(
          'Step ${idx + 1} of ${steps.length} · '
          '${kOrderStatusLabels[status] ?? status}',
          style: TextStyle(
            fontSize: 11.5,
            color: FrColors.muted,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

/// "4.6 ★ (23)" — compact stall rating; renders "New" with no reviews.
class RatingBadge extends StatelessWidget {
  final double? rating;
  final int count;
  final double size;
  const RatingBadge({
    super.key,
    required this.rating,
    required this.count,
    this.size = 13,
  });

  @override
  Widget build(BuildContext context) {
    final r = rating;
    if (r == null || count == 0) {
      return Text(
        tr('New'),
        style: TextStyle(
          fontSize: size - 1,
          color: FrColors.muted,
          fontWeight: FontWeight.w700,
        ),
      );
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.star_rounded, size: size + 3, color: FrColors.warning),
        const SizedBox(width: 2),
        Text(
          r.toStringAsFixed(1),
          style: TextStyle(fontSize: size, fontWeight: FontWeight.w800),
        ),
        Text(
          ' ($count)',
          style: TextStyle(fontSize: size - 1, color: FrColors.muted),
        ),
      ],
    );
  }
}

/// Tappable 1-5 star input.
class StarPicker extends StatelessWidget {
  final int value; // 0 = none yet
  final ValueChanged<int>? onChanged;
  final double size;
  const StarPicker({
    super.key,
    required this.value,
    this.onChanged,
    this.size = 36,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 1; i <= 5; i++)
          IconButton(
            tooltip: '$i star${i == 1 ? '' : 's'}',
            visualDensity: VisualDensity.compact,
            iconSize: size,
            onPressed: onChanged == null ? null : () => onChanged!(i),
            icon: Icon(
              i <= value ? Icons.star_rounded : Icons.star_outline_rounded,
              color: i <= value ? FrColors.warning : FrColors.muted,
            ),
          ),
      ],
    );
  }
}

/// "Ready in ~25 min" for a new ASAP order at [v], given the orders the
/// stall is already working through.
String waitLabel(Vendor v, int ordersAhead) {
  final minutes = (ordersAhead + 1) * v.prepMinutes;
  return minutes <= v.prepMinutes
      ? tr('Ready in ~{m} min', {'m': minutes})
      : tr('Ready in ~{m} min · {n} ahead', {'m': minutes, 'n': ordersAhead});
}

/// Display name / icon for a product tag (see kProductTags).
String tagLabel(String tag) => switch (tag) {
  'halal' => tr('Halal'),
  'vegetarian' => tr('Vegetarian'),
  'spicy' => tr('Spicy'),
  'bestseller' => tr('Bestseller'),
  _ => tag,
};

IconData tagIcon(String tag) => switch (tag) {
  'halal' => Icons.verified_outlined,
  'vegetarian' => Icons.eco_outlined,
  'spicy' => Icons.local_fire_department_outlined,
  'bestseller' => Icons.star_outline,
  _ => Icons.label_outline,
};

/// "12:30 PM".
String fmtClock(DateTime t) {
  final h12 = t.hour % 12 == 0 ? 12 : t.hour % 12;
  return '$h12:${t.minute.toString().padLeft(2, '0')} '
      '${t.hour < 12 ? 'AM' : 'PM'}';
}

/// Text field with the app's styling. Password fields ([obscure]) get a
/// show/hide eye button automatically.
class FrTextField extends StatefulWidget {
  final TextEditingController controller;
  final String label;
  final String? hint;
  final bool obscure;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;
  final int maxLines;
  final Widget? suffix;
  final bool enabled;

  /// Hard cap on what can be typed/pasted (null = no cap).
  final int? maxLength;
  final List<TextInputFormatter>? inputFormatters;

  /// Called when the user presses Enter in this field.
  final ValueChanged<String>? onSubmitted;

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
    this.maxLength,
    this.inputFormatters,
    this.onSubmitted,
  });

  @override
  State<FrTextField> createState() => _FrTextFieldState();
}

class _FrTextFieldState extends State<FrTextField> {
  late bool _hidden = widget.obscure;

  @override
  Widget build(BuildContext context) {
    final eye = widget.obscure
        ? IconButton(
            tooltip: _hidden ? tr('Show password') : tr('Hide password'),
            onPressed: () => setState(() => _hidden = !_hidden),
            icon: AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
              transitionBuilder: (c, a) =>
                  ScaleTransition(scale: a, child: c),
              child: Icon(
                _hidden
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined,
                key: ValueKey(_hidden),
              ),
            ),
          )
        : null;
    return TextFormField(
      controller: widget.controller,
      obscureText: _hidden,
      // Browsers' password managers and spellcheck behave on secrets.
      autocorrect: !widget.obscure,
      enableSuggestions: !widget.obscure,
      keyboardType: widget.keyboardType,
      validator: widget.validator,
      // Show problems as soon as the user has typed, not only on submit.
      autovalidateMode: widget.validator == null
          ? AutovalidateMode.disabled
          : AutovalidateMode.onUserInteraction,
      maxLines: widget.maxLines,
      enabled: widget.enabled,
      maxLength: widget.maxLength,
      inputFormatters: widget.inputFormatters,
      onFieldSubmitted: widget.onSubmitted,
      // A live "12/300" counter only on long free-text fields.
      buildCounter:
          (context, {required currentLength, required isFocused, maxLength}) =>
              maxLength != null && maxLength >= 150 && isFocused
              ? Text(
                  '$currentLength/$maxLength',
                  style: const TextStyle(fontSize: 11),
                )
              : null,
      decoration: InputDecoration(
        labelText: widget.label,
        hintText: widget.hint,
        suffixIcon: widget.suffix ?? eye,
        alignLabelWithHint: widget.maxLines > 1,
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
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.3,
              ),
            ),
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

  const FrImage(
    this.url, {
    super.key,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
  });

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
  // Replace, don't queue: tapping a button 8 times used to line up 8
  // messages that then played for half a minute.
  ScaffoldMessenger.of(context)
    ..clearSnackBars()
    ..showSnackBar(
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
