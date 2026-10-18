import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/theme.dart';

/// Premium building blocks: depth (layered shadows, clay-style 3D orbs,
/// pointer-tilt cards), glass surfaces and restrained motion. Every
/// animation is skipped when the OS asks for reduced motion.

bool reduceMotion(BuildContext context) =>
    MediaQuery.maybeDisableAnimationsOf(context) ?? false;

final _brandImages = <String, ImageProvider>{};

/// A Branding image (data URL) as an ImageProvider, decoded once.
ImageProvider? brandImage(String? dataUrl) {
  if (dataUrl == null || !dataUrl.startsWith('data:image/')) return null;
  if (_brandImages.length > 8) _brandImages.clear();
  return _brandImages.putIfAbsent(
      dataUrl, () => MemoryImage(base64Decode(dataUrl.split(',').last)));
}

// ---------------------------------------------------------------------------
// Surfaces
// ---------------------------------------------------------------------------

/// Elevated card: soft layered shadow, hairline border, large radius.
class PremiumCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double? radius; // null = FrRadius.xl
  final Gradient? gradient;
  final Color? color;
  final bool raised;

  const PremiumCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.radius,
    this.gradient,
    this.color,
    this.raised = false,
  });

  @override
  Widget build(BuildContext context) {
    final radius = this.radius ?? FrRadius.xl;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: gradient == null ? (color ?? FrColors.surface) : null,
        gradient: gradient,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: FrColors.hairline),
        boxShadow: raised ? FrShadows.raised : FrShadows.soft,
      ),
      child: Padding(padding: padding, child: child),
    );
  }
}

/// Frosted glass panel for bars and floating chrome.
class GlassPanel extends StatelessWidget {
  final Widget child;
  final BorderRadius borderRadius;
  final EdgeInsetsGeometry padding;
  final double blur;

  const GlassPanel({
    super.key,
    required this.child,
    this.borderRadius = BorderRadius.zero,
    this.padding = EdgeInsets.zero,
    this.blur = 18,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: borderRadius,
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: FrColors.glass,
            borderRadius: borderRadius,
            border: Border.all(color: FrColors.hairline),
          ),
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}

/// Slow-drifting warm light blobs behind a screen. Cheap: radial
/// gradients only, no blur filters.
class AuroraBackground extends StatefulWidget {
  final Widget child;
  final double intensity;
  const AuroraBackground({super.key, required this.child, this.intensity = 1});

  @override
  State<AuroraBackground> createState() => _AuroraBackgroundState();
}

class _AuroraBackgroundState extends State<AuroraBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(seconds: 24));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (reduceMotion(context)) {
      _c.stop();
    } else if (!_c.isAnimating) {
      _c.repeat();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final k = widget.intensity * (FrColors.dark ? 0.55 : 1.0);
    final animate =
        Brand.current.animatedBackground && !reduceMotion(context);
    if (!animate) {
      _c.stop();
    } else if (!_c.isAnimating) {
      _c.repeat();
    }
    final photo = brandImage(Brand.current.loginImage);
    return Stack(
      fit: StackFit.expand,
      children: [
        ColoredBox(color: FrColors.cream),
        if (photo != null) ...[
          Image(image: photo, fit: BoxFit.cover, gaplessPlayback: true),
          // Fade the photo into the page so cards stay readable.
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  FrColors.cream.withValues(alpha: 0.35),
                  FrColors.cream.withValues(alpha: 0.75),
                  FrColors.cream.withValues(alpha: 0.92),
                ],
              ),
            ),
          ),
        ],
        AnimatedBuilder(
          animation: _c,
          builder: (context, _) {
            final t = _c.value * 2 * math.pi;
            return CustomPaint(
              painter: _AuroraPainter(t, k),
              size: Size.infinite,
            );
          },
        ),
        widget.child,
      ],
    );
  }
}

class _AuroraPainter extends CustomPainter {
  final double t;
  final double k;
  _AuroraPainter(this.t, this.k);

  void _blob(Canvas canvas, Offset c, double r, Color color) {
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..shader = RadialGradient(colors: [color, color.withValues(alpha: 0)])
            .createShader(Rect.fromCircle(center: c, radius: r)),
    );
  }

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final r = math.max(w, h) * 0.55;
    _blob(
        canvas,
        Offset(w * (0.15 + 0.08 * math.sin(t)), h * (0.12 + 0.06 * math.cos(t))),
        r,
        FrColors.primary.withValues(alpha: 0.16 * k));
    _blob(
        canvas,
        Offset(w * (0.9 + 0.06 * math.cos(t * 1.3)),
            h * (0.3 + 0.08 * math.sin(t * 0.7))),
        r * 0.9,
        FrColors.secondary.withValues(alpha: 0.16 * k));
    _blob(
        canvas,
        Offset(w * (0.55 + 0.1 * math.sin(t * 0.6)),
            h * (1.0 + 0.05 * math.cos(t))),
        r,
        const Color(0xFFFFC94D).withValues(alpha: 0.12 * k));
  }

  @override
  bool shouldRepaint(_AuroraPainter old) => old.t != t || old.k != k;
}

// ---------------------------------------------------------------------------
// 3D
// ---------------------------------------------------------------------------

/// A glossy "clay" sphere holding an icon: highlight top-left, core shade
/// bottom-right and a soft contact shadow underneath, which reads as 3D.
class ClayOrb extends StatelessWidget {
  final IconData icon;
  final double size;
  final List<Color>? colors; // null = brand colours
  final double shadowLift;

  const ClayOrb({
    super.key,
    required this.icon,
    this.size = 72,
    this.colors,
    this.shadowLift = 0,
  });

  @override
  Widget build(BuildContext context) {
    final colors = this.colors ??
        [Color.lerp(FrColors.primary, FrColors.secondary, 0.45)!, FrColors.primary];
    return SizedBox(
      width: size,
      height: size * 1.22,
      child: Stack(
        alignment: Alignment.topCenter,
        clipBehavior: Clip.none,
        children: [
          // Contact shadow: shrinks and fades as the orb lifts.
          Positioned(
            bottom: 0,
            child: Container(
              width: size * (0.62 - 0.18 * shadowLift),
              height: size * 0.09,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(size),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF3A1F14)
                        .withValues(alpha: 0.30 - 0.15 * shadowLift),
                    blurRadius: size * 0.12,
                    spreadRadius: size * 0.01,
                  ),
                ],
              ),
            ),
          ),
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                center: const Alignment(-0.35, -0.45),
                radius: 0.95,
                colors: [
                  Color.lerp(colors.first, Colors.white, 0.45)!,
                  colors.first,
                  colors.last,
                  Color.lerp(colors.last, Colors.black, 0.35)!,
                ],
                stops: const [0, 0.35, 0.78, 1],
              ),
              boxShadow: [
                BoxShadow(
                  color: colors.last.withValues(alpha: 0.35),
                  blurRadius: size * 0.35,
                  offset: Offset(0, size * 0.18),
                ),
              ],
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Specular glint.
                Positioned(
                  top: size * 0.12,
                  left: size * 0.2,
                  child: Container(
                    width: size * 0.26,
                    height: size * 0.14,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(size),
                      color: Colors.white.withValues(alpha: 0.55),
                    ),
                  ),
                ),
                Icon(icon,
                    color: Colors.white,
                    size: size * 0.46,
                    shadows: [
                      Shadow(
                          color: Colors.black.withValues(alpha: 0.25),
                          blurRadius: 6,
                          offset: const Offset(0, 2)),
                    ]),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Orbs floating in perspective that drift and lean toward the pointer.
class FloatingFoodScene extends StatefulWidget {
  final double height;
  const FloatingFoodScene({super.key, this.height = 300});

  @override
  State<FloatingFoodScene> createState() => _FloatingFoodSceneState();
}

class _OrbSpec {
  final IconData icon;
  final Alignment at;
  final double size;
  final List<Color> colors;
  final double phase;
  final double depth;
  const _OrbSpec(this.icon, this.at, this.size, this.colors, this.phase, this.depth);
}

// The centre orb wears the brand colours; the rest keep their food tones.
List<_OrbSpec> get _orbs => [
  _OrbSpec(Icons.lunch_dining, const Alignment(0, -0.1), 1.0,
      [Color.lerp(FrColors.primary, FrColors.secondary, 0.45)!, FrColors.primary], 0, 1.0),
  const _OrbSpec(Icons.local_cafe, Alignment(-0.82, -0.62), 0.58,
      [Color(0xFFFFB547), Color(0xFFE07A00)], 1.3, 0.6),
  const _OrbSpec(Icons.ramen_dining, Alignment(0.85, -0.5), 0.66,
      [Color(0xFFFF9B6A), Color(0xFFE5484D)], 2.4, 0.7),
  const _OrbSpec(Icons.icecream, Alignment(-0.7, 0.72), 0.5,
      [Color(0xFFFF8FB1), Color(0xFFD6336C)], 3.6, 0.5),
  const _OrbSpec(Icons.local_pizza, Alignment(0.72, 0.68), 0.54,
      [Color(0xFFFFD166), Color(0xFFF08C00)], 4.7, 0.55),
];

class _FloatingFoodSceneState extends State<FloatingFoodScene>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(seconds: 6));
  Offset _pointer = Offset.zero; // -1..1 in each axis

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (reduceMotion(context)) {
      _c.stop();
    } else if (!_c.isAnimating) {
      _c.repeat();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // The admin can switch the 3D food off (Content → Branding).
    if (!Brand.current.effects3d) return const SizedBox.shrink();
    return SizedBox(
      height: widget.height,
      child: LayoutBuilder(builder: (context, box) {
        final base = math.min(box.maxWidth, widget.height) * 0.42;
        return MouseRegion(
          onHover: (e) => setState(() => _pointer = Offset(
                (e.localPosition.dx / box.maxWidth) * 2 - 1,
                (e.localPosition.dy / widget.height) * 2 - 1,
              )),
          onExit: (_) => setState(() => _pointer = Offset.zero),
          child: TweenAnimationBuilder<Offset>(
            tween: Tween(end: _pointer),
            duration: const Duration(milliseconds: 450),
            curve: Curves.easeOutCubic,
            builder: (context, p, _) => AnimatedBuilder(
              animation: _c,
              builder: (context, _) {
                final t = _c.value * 2 * math.pi;
                return Transform(
                  alignment: Alignment.center,
                  transform: Matrix4.identity()
                    ..setEntry(3, 2, 0.0012)
                    ..rotateX(-p.dy * 0.18)
                    ..rotateY(p.dx * 0.22),
                  child: Stack(
                    children: [
                      for (final o in _orbs)
                        Align(
                          alignment: o.at,
                          child: Transform.translate(
                            offset: Offset(
                              p.dx * 14 * o.depth,
                              math.sin(t + o.phase) * 9 * o.depth +
                                  p.dy * 10 * o.depth,
                            ),
                            child: Transform.rotate(
                              angle: math.sin(t * 0.5 + o.phase) * 0.08,
                              child: ClayOrb(
                                icon: o.icon,
                                size: base * o.size,
                                colors: o.colors,
                                shadowLift: (math.sin(t + o.phase) + 1) / 2,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
        );
      }),
    );
  }
}

/// Card that leans toward the pointer in 3D, lifts on hover and dips on
/// press. Falls back to a plain press effect on touch screens.
class TiltCard extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final double maxTilt;
  final double? radius; // null = FrRadius.xl

  const TiltCard({
    super.key,
    required this.child,
    this.onTap,
    this.maxTilt = 0.12,
    this.radius,
  });

  @override
  State<TiltCard> createState() => _TiltCardState();
}

class _TiltCardState extends State<TiltCard> {
  Offset _tilt = Offset.zero;
  bool _hover = false;
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final still = reduceMotion(context);
    final target = still ? Offset.zero : _tilt;
    final scale = still ? 1.0 : (_down ? 0.975 : (_hover ? 1.015 : 1.0));
    return LayoutBuilder(builder: (context, box) {
      return MouseRegion(
        cursor: widget.onTap == null
            ? MouseCursor.defer
            : SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hover = true),
        onHover: (e) => setState(() => _tilt = Offset(
              (e.localPosition.dx / box.maxWidth) * 2 - 1,
              (e.localPosition.dy / box.maxHeight.clamp(1, 2000)) * 2 - 1,
            )),
        onExit: (_) => setState(() {
          _hover = false;
          _tilt = Offset.zero;
        }),
        child: GestureDetector(
          onTapDown: (_) => setState(() => _down = true),
          onTapUp: (_) => setState(() => _down = false),
          onTapCancel: () => setState(() => _down = false),
          onTap: widget.onTap == null
              ? null
              : () {
                  HapticFeedback.selectionClick();
                  widget.onTap!();
                },
          child: TweenAnimationBuilder<double>(
            tween: Tween(end: scale),
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            builder: (context, s, child) => TweenAnimationBuilder<Offset>(
              tween: Tween(end: target),
              duration: const Duration(milliseconds: 260),
              curve: Curves.easeOutCubic,
              builder: (context, t, child) => Transform(
                alignment: Alignment.center,
                transform: Matrix4.identity()
                  ..setEntry(3, 2, 0.0015)
                  ..rotateX(-t.dy * widget.maxTilt)
                  ..rotateY(t.dx * widget.maxTilt)
                  ..scaleByDouble(s, s, 1, 1),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(widget.radius ?? FrRadius.xl),
                    boxShadow: _hover && !still
                        ? FrShadows.raised
                        : FrShadows.soft,
                  ),
                  child: child,
                ),
              ),
              child: child,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(widget.radius ?? FrRadius.xl),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: FrColors.surface,
                  borderRadius: BorderRadius.circular(widget.radius ?? FrRadius.xl),
                  border: Border.all(color: FrColors.hairline),
                ),
                child: widget.child,
              ),
            ),
          ),
        ),
      );
    });
  }
}

/// The FoodRush logo as a glossy 3D tile that gently sways.
class BrandMark extends StatefulWidget {
  final double size;
  const BrandMark({super.key, this.size = 56});

  @override
  State<BrandMark> createState() => _BrandMarkState();
}

class _BrandMarkState extends State<BrandMark>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(seconds: 5));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (reduceMotion(context)) {
      _c.stop();
    } else if (!_c.isAnimating) {
      _c.repeat();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.size;
    return AnimatedBuilder(
      animation: _c,
      builder: (context, child) {
        final t = _c.value * 2 * math.pi;
        return Transform(
          alignment: Alignment.center,
          transform: Matrix4.identity()
            ..setEntry(3, 2, 0.002)
            ..rotateY(math.sin(t) * 0.22)
            ..rotateX(math.cos(t) * 0.1),
          child: child,
        );
      },
      child: Container(
        width: s,
        height: s,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(s * 0.3),
          gradient: FrGradients.brand,
          image: brandImage(Brand.current.logo) == null
              ? null
              : DecorationImage(
                  image: brandImage(Brand.current.logo)!, fit: BoxFit.cover),
          boxShadow: [
            BoxShadow(
              color: FrColors.primary.withValues(alpha: 0.45),
              blurRadius: s * 0.45,
              offset: Offset(0, s * 0.2),
            ),
          ],
        ),
        child: Stack(
          children: [
            // Top bevel highlight.
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(s * 0.3),
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.center,
                    colors: [
                      Colors.white.withValues(alpha: 0.35),
                      Colors.white.withValues(alpha: 0),
                    ],
                  ),
                ),
              ),
            ),
            if (Brand.current.logo == null)
            Center(
              child: Icon(Icons.lunch_dining,
                  color: Colors.white,
                  size: s * 0.55,
                  shadows: const [
                    Shadow(
                        color: Color(0x55000000),
                        blurRadius: 8,
                        offset: Offset(0, 3)),
                  ]),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Motion
// ---------------------------------------------------------------------------

/// Fades and rises into place once, after [index] × [step].
class FadeSlideIn extends StatefulWidget {
  final Widget child;
  final int index;
  final Duration step;
  final double offset;

  const FadeSlideIn({
    super.key,
    required this.child,
    this.index = 0,
    this.step = const Duration(milliseconds: 55),
    this.offset = 18,
  });

  @override
  State<FadeSlideIn> createState() => _FadeSlideInState();
}

class _FadeSlideInState extends State<FadeSlideIn>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 520));
  late final Animation<double> _a =
      CurvedAnimation(parent: _c, curve: Curves.easeOutCubic);
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (reduceMotion(context)) {
      _c.value = 1;
      return;
    }
    final delay = widget.step * math.min(widget.index, 8);
    Future.delayed(delay, () {
      if (mounted) _c.forward();
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _a,
      builder: (context, child) => Opacity(
        opacity: _a.value,
        child: Transform.translate(
          offset: Offset(0, (1 - _a.value) * widget.offset),
          child: child,
        ),
      ),
      child: widget.child,
    );
  }
}

/// Primary call-to-action: brand gradient, glow, press dip, busy spinner.
class GradientButton extends StatefulWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final bool busy;
  final double height;
  final bool expand;

  const GradientButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.busy = false,
    this.height = 54,
    this.expand = true,
  });

  @override
  State<GradientButton> createState() => _GradientButtonState();
}

class _GradientButtonState extends State<GradientButton> {
  bool _down = false;
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null && !widget.busy;
    final content = widget.busy
        ? SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(
                strokeWidth: 2.4, color: FrColors.onPrimary),
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.icon != null) ...[
                Icon(widget.icon, color: FrColors.onPrimary, size: 20),
                const SizedBox(width: 8),
              ],
              Flexible(
                child: Text(
                  widget.label,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: FrColors.onPrimary,
                    fontWeight: FontWeight.w800,
                    fontSize: 15.5,
                    letterSpacing: 0.1,
                  ),
                ),
              ),
            ],
          );
    return Semantics(
      button: true,
      enabled: enabled,
      label: widget.label,
      excludeSemantics: true,
      child: MouseRegion(
        cursor: enabled ? SystemMouseCursors.click : MouseCursor.defer,
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: GestureDetector(
          onTapDown: enabled ? (_) => setState(() => _down = true) : null,
          onTapUp: enabled ? (_) => setState(() => _down = false) : null,
          onTapCancel: () => setState(() => _down = false),
          onTap: enabled
              ? () {
                  HapticFeedback.lightImpact();
                  widget.onPressed!();
                }
              : null,
          child: AnimatedScale(
            scale: _down ? 0.97 : 1,
            duration: const Duration(milliseconds: 120),
            child: AnimatedOpacity(
              opacity: enabled || widget.busy ? 1 : 0.45,
              duration: const Duration(milliseconds: 200),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                height: widget.height,
                width: widget.expand ? double.infinity : null,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(FrRadius.lg),
                  gradient: FrGradients.brand,
                  boxShadow: enabled
                      ? [
                          BoxShadow(
                            color: FrColors.primary
                                .withValues(alpha: _hover ? 0.5 : 0.32),
                            blurRadius: _hover ? 26 : 18,
                            offset: Offset(0, _hover ? 10 : 7),
                          ),
                        ]
                      : null,
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Glossy top half.
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      height: widget.height / 2,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.vertical(
                              top: Radius.circular(FrRadius.lg)),
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              FrColors.onPrimary.withValues(alpha: 0.18),
                              FrColors.onPrimary.withValues(alpha: 0),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 22),
                      child: content,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Text painted with the brand gradient.
class GradientText extends StatelessWidget {
  final String text;
  final TextStyle style;
  final Gradient? gradient; // null = brand gradient
  const GradientText(this.text,
      {super.key, required this.style, this.gradient});

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      blendMode: BlendMode.srcIn,
      shaderCallback: (r) => (gradient ?? FrGradients.brand).createShader(r),
      child: Text(text, style: style),
    );
  }
}

/// A softly pulsing "live" dot (open stall, order in progress).
class PulseDot extends StatefulWidget {
  final Color color;
  final double size;
  const PulseDot({super.key, required this.color, this.size = 8});

  @override
  State<PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<PulseDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1600));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (reduceMotion(context)) {
      _c.stop();
    } else if (!_c.isAnimating) {
      _c.repeat();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.size;
    return SizedBox(
      width: s * 2.4,
      height: s * 2.4,
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) => Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: s + s * 1.4 * _c.value,
              height: s + s * 1.4 * _c.value,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: widget.color.withValues(alpha: 0.35 * (1 - _c.value)),
              ),
            ),
            Container(
              width: s,
              height: s,
              decoration:
                  BoxDecoration(shape: BoxShape.circle, color: widget.color),
            ),
          ],
        ),
      ),
    );
  }
}

/// Animates between number values (totals, counters).
class AnimatedNumber extends StatelessWidget {
  final double value;
  final String Function(double) format;
  final TextStyle? style;
  const AnimatedNumber(
      {super.key, required this.value, required this.format, this.style});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(end: value),
      duration: reduceMotion(context)
          ? Duration.zero
          : const Duration(milliseconds: 500),
      curve: Curves.easeOutCubic,
      builder: (context, v, _) => Text(format(v), style: style),
    );
  }
}
