import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import '../../models/branding.dart';
import '../../providers/branding_provider.dart';
import '../../providers/repository.dart';
import '../../shared/premium.dart';
import '../../shared/widgets.dart';

/// Content → Branding: the admin restyles the whole app — name, logo,
/// colours, pictures, corners, font, effects, default theme.
///
/// Edits preview live across the whole app in this browser only; nobody
/// else sees them until Save. Leaving or Discard puts the saved look back.
class BrandingEditor extends ConsumerStatefulWidget {
  const BrandingEditor({super.key});

  @override
  ConsumerState<BrandingEditor> createState() => _BrandingEditorState();
}

class _BrandingEditorState extends ConsumerState<BrandingEditor> {
  late final BrandingController _ctrl = ref.read(brandingProvider.notifier);
  late Branding _draft = _ctrl.live;
  final _name = TextEditingController();
  final _tagline = TextEditingController();
  bool _saving = false;
  String? _uploading; // which image is being processed

  bool get _dirty => _draft != _ctrl.live;

  @override
  void initState() {
    super.initState();
    _name.text = _draft.appName;
    _tagline.text = _draft.tagline;
  }

  @override
  void dispose() {
    _name.dispose();
    _tagline.dispose();
    // Unsaved preview: put the saved look back (after this frame — the
    // provider can't change while the tree is being torn down).
    final ctrl = _ctrl;
    Future.microtask(ctrl.endPreview);
    super.dispose();
  }

  void _update(Branding b) {
    setState(() => _draft = b);
    _ctrl.preview(b);
  }

  void _discard() {
    final live = _ctrl.live;
    setState(() {
      _draft = live;
      _name.text = live.appName;
      _tagline.text = live.tagline;
    });
    _ctrl.endPreview();
  }

  Future<void> _resetToStock() async {
    final ok = await confirmDialog(
      context,
      title: 'Go back to the stock FoodRush look?',
      message: 'Colours, logo, pictures and style return to the defaults. '
          'You still need to press Save to apply it for everyone.',
      confirmLabel: 'Use stock look',
    );
    if (!ok) return;
    _name.text = Branding.defaults.appName;
    _tagline.text = '';
    _update(Branding.defaults);
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.isEmpty) {
      showSnack(context, 'The app needs a name.', error: true);
      return;
    }
    setState(() => _saving = true);
    try {
      final b = _draft.copyWith(appName: name, tagline: _tagline.text.trim());
      await Repository.instance.saveBranding(b);
      if (mounted) {
        setState(() => _draft = b);
        showSnack(context, 'Saved. Everyone sees the new look now.');
      }
    } catch (e) {
      if (mounted) showSnack(context, 'Could not save: $e', error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  /// Picks a photo and shrinks it to fit the rules' size cap.
  Future<String?> _pickImage(String which,
      {required int maxDim, required int cap}) async {
    final picked =
        await FilePicker.platform.pickFiles(type: FileType.image, withData: true);
    final f = picked?.files.single;
    final Uint8List? bytes = f?.bytes;
    if (f == null || bytes == null) return null;
    setState(() => _uploading = which);
    try {
      var dim = maxDim;
      var quality = 78;
      for (var i = 0; i < 4; i++) {
        final url = await Repository.instance.uploadImage(
            pathPrefix: 'branding',
            bytes: bytes,
            fileName: f.name,
            maxDim: dim,
            quality: quality);
        if (url.length <= cap) return url;
        dim = (dim * 0.75).round();
        quality = (quality - 8).clamp(45, 90);
      }
      throw Exception('That picture is too detailed. Try a smaller one.');
    } catch (e) {
      if (mounted) showSnack(context, 'Could not use image: $e', error: true);
      return null;
    } finally {
      if (mounted) setState(() => _uploading = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final editor = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _identity(),
        const SizedBox(height: 16),
        _colours(),
        const SizedBox(height: 16),
        _pictures(),
        const SizedBox(height: 16),
        _style(),
      ],
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SaveBar(
          dirty: _dirty,
          saving: _saving,
          onSave: _save,
          onDiscard: _discard,
          onStock: _resetToStock,
        ),
        const SizedBox(height: 16),
        LayoutBuilder(builder: (context, c) {
          if (c.maxWidth < 900) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _BrandPreview(draft: _draft),
                const SizedBox(height: 16),
                editor,
              ],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 6, child: editor),
              const SizedBox(width: 20),
              Expanded(flex: 5, child: _BrandPreview(draft: _draft)),
            ],
          );
        }),
      ],
    );
  }

  // ---- sections ----------------------------------------------------------

  Widget _section(String title, String hint, List<Widget> children) =>
      PremiumCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SectionHeader(title),
            Text(hint, style: TextStyle(color: FrColors.muted, fontSize: 13)),
            const SizedBox(height: 16),
            ...children,
          ],
        ),
      );

  Widget _identity() => _section(
        'Name & logo',
        'Shown on the sign-in screen, the top bar and the browser tab.',
        [
          FrTextField(
            controller: _name,
            label: 'App name',
            maxLength: 24,
            onSubmitted: (_) {},
          ),
          _OnChange(
              controller: _name,
              onChanged: (v) => _update(_draft.copyWith(
                  appName: v.trim().isEmpty ? Branding.defaults.appName : v))),
          const SizedBox(height: 12),
          FrTextField(
            controller: _tagline,
            label: 'Tagline (optional)',
            hint: 'Blank keeps the built-in, translated tagline',
            maxLength: 60,
          ),
          _OnChange(
              controller: _tagline,
              onChanged: (v) => _update(_draft.copyWith(tagline: v))),
          const SizedBox(height: 16),
          _ImagePickerRow(
            label: 'Logo',
            hint: 'Square works best. Replaces the burger icon.',
            image: _draft.logo,
            square: true,
            busy: _uploading == 'logo',
            onPick: () async {
              final url = await _pickImage('logo', maxDim: 256, cap: 145000);
              if (url != null) _update(_draft.copyWith(logo: () => url));
            },
            onRemove: () => _update(_draft.copyWith(logo: () => null)),
          ),
        ],
      );

  Widget _colours() {
    final contrastLow = _contrast(_draft.primary, Colors.white) < 3;
    return _section(
      'Colours',
      'Pick a ready-made palette or choose your own. Buttons, highlights, '
          'gradients and the 3D food all follow these.',
      [
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final p in BrandPalette.all)
              _PaletteChip(
                palette: p,
                selected: p.primary == _draft.primary &&
                    p.accent == _draft.accent,
                onTap: () => _update(
                    _draft.copyWith(primary: p.primary, accent: p.accent)),
              ),
          ],
        ),
        const SizedBox(height: 18),
        Row(
          children: [
            Expanded(
              child: _ColourField(
                label: 'Brand colour',
                color: _draft.primary,
                onChanged: (c) => _update(_draft.copyWith(primary: c)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _ColourField(
                label: 'Accent colour',
                color: _draft.accent,
                onChanged: (c) => _update(_draft.copyWith(accent: c)),
              ),
            ),
          ],
        ),
        if (contrastLow) ...[
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(Icons.info_outline_rounded,
                  size: 18, color: FrColors.warning),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'This brand colour is light, so text on buttons will be '
                  'dark for readability.',
                  style: TextStyle(color: FrColors.muted, fontSize: 12.5),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _pictures() => _section(
        'Pictures',
        'Photos behind the sign-in screens and the Shop greeting.',
        [
          _ImagePickerRow(
            label: 'Sign-in background',
            hint: 'Shown softly behind the login and sign-up cards.',
            image: _draft.loginImage,
            busy: _uploading == 'login',
            onPick: () async {
              final url =
                  await _pickImage('login', maxDim: 1600, cap: 295000);
              if (url != null) _update(_draft.copyWith(loginImage: () => url));
            },
            onRemove: () => _update(_draft.copyWith(loginImage: () => null)),
          ),
          const Divider(height: 28),
          _ImagePickerRow(
            label: 'Shop greeting photo',
            hint: 'Blended behind "Hungry? Skip the line." on the Shop page.',
            image: _draft.heroImage,
            busy: _uploading == 'hero',
            onPick: () async {
              final url = await _pickImage('hero', maxDim: 1400, cap: 295000);
              if (url != null) _update(_draft.copyWith(heroImage: () => url));
            },
            onRemove: () => _update(_draft.copyWith(heroImage: () => null)),
          ),
        ],
      );

  Widget _style() => _section(
        'Style',
        'The overall feel of every screen.',
        [
          _Labelled(
            'Corners',
            SegmentedButton<String>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(
                    value: 'rounded',
                    icon: Icon(Icons.rounded_corner),
                    label: Text('Rounded')),
                ButtonSegment(
                    value: 'soft',
                    icon: Icon(Icons.crop_square_rounded),
                    label: Text('Soft')),
                ButtonSegment(
                    value: 'sharp',
                    icon: Icon(Icons.crop_square),
                    label: Text('Sharp')),
              ],
              selected: {_draft.corner},
              onSelectionChanged: (s) =>
                  _update(_draft.copyWith(corner: s.first)),
            ),
          ),
          _Labelled(
            'Font',
            SegmentedButton<String>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(value: 'modern', label: Text('Modern')),
                ButtonSegment(value: 'classic', label: Text('Classic')),
              ],
              selected: {_draft.font},
              onSelectionChanged: (s) =>
                  _update(_draft.copyWith(font: s.first)),
            ),
          ),
          _Labelled(
            'New visitors see',
            SegmentedButton<String>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(
                    value: 'system',
                    icon: Icon(Icons.brightness_auto),
                    label: Text('Device')),
                ButtonSegment(
                    value: 'light',
                    icon: Icon(Icons.light_mode_outlined),
                    label: Text('Light')),
                ButtonSegment(
                    value: 'dark',
                    icon: Icon(Icons.dark_mode_outlined),
                    label: Text('Dark')),
              ],
              selected: {_draft.defaultTheme},
              onSelectionChanged: (s) =>
                  _update(_draft.copyWith(defaultTheme: s.first)),
            ),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _draft.effects3d,
            onChanged: (v) => _update(_draft.copyWith(effects3d: v)),
            title: const Text('3D floating food',
                style: TextStyle(fontWeight: FontWeight.w700)),
            subtitle: const Text('On the sign-in screen and Shop greeting'),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _draft.animatedBackground,
            onChanged: (v) => _update(_draft.copyWith(animatedBackground: v)),
            title: const Text('Moving background glow',
                style: TextStyle(fontWeight: FontWeight.w700)),
            subtitle: const Text('Slowly drifting light behind sign-in screens'),
          ),
        ],
      );

  static double _contrast(Color a, Color b) {
    final la = a.computeLuminance(), lb = b.computeLuminance();
    final hi = la > lb ? la : lb, lo = la > lb ? lb : la;
    return (hi + 0.05) / (lo + 0.05);
  }
}

// ---------------------------------------------------------------------------
// Pieces
// ---------------------------------------------------------------------------

/// Calls [onChanged] as [controller] changes (keeps fields uncluttered).
class _OnChange extends StatefulWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  const _OnChange({required this.controller, required this.onChanged});

  @override
  State<_OnChange> createState() => _OnChangeState();
}

class _OnChangeState extends State<_OnChange> {
  late String _last = widget.controller.text;

  void _listen() {
    final t = widget.controller.text;
    if (t == _last) return;
    _last = t;
    widget.onChanged(t);
  }

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_listen);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_listen);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

class _SaveBar extends StatelessWidget {
  final bool dirty;
  final bool saving;
  final VoidCallback onSave;
  final VoidCallback onDiscard;
  final VoidCallback onStock;
  const _SaveBar({
    required this.dirty,
    required this.saving,
    required this.onSave,
    required this.onDiscard,
    required this.onStock,
  });

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      padding: const EdgeInsets.fromLTRB(18, 14, 14, 14),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 12,
        runSpacing: 12,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              dirty
                  ? PulseDot(color: FrColors.warning, size: 7)
                  : Icon(Icons.check_circle_rounded,
                      size: 18, color: FrColors.success),
              const SizedBox(width: 6),
              Text(
                dirty
                    ? 'Previewing changes. Only you can see them until you save.'
                    : 'This is the look everyone sees.',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ],
          ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              TextButton(onPressed: onStock, child: const Text('Stock look')),
              OutlinedButton(
                  onPressed: dirty && !saving ? onDiscard : null,
                  child: const Text('Discard')),
              GradientButton(
                expand: false,
                height: 48,
                icon: Icons.check_rounded,
                label: 'Save for everyone',
                busy: saving,
                onPressed: dirty ? onSave : null,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Labelled extends StatelessWidget {
  final String label;
  final Widget child;
  const _Labelled(this.label, this.child);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: TextStyle(
                    color: FrColors.muted,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            SingleChildScrollView(
                scrollDirection: Axis.horizontal, child: child),
          ],
        ),
      );
}

class _PaletteChip extends StatelessWidget {
  final BrandPalette palette;
  final bool selected;
  final VoidCallback onTap;
  const _PaletteChip(
      {required this.palette, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.fromLTRB(6, 6, 14, 6),
        decoration: BoxDecoration(
          color: FrColors.surfaceAlt,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected ? palette.primary : Colors.transparent,
            width: 2,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [palette.accent, palette.primary],
                  stops: const [0.35, 0.65],
                ),
              ),
              child: selected
                  ? const Icon(Icons.check_rounded,
                      size: 16, color: Colors.white)
                  : null,
            ),
            const SizedBox(width: 8),
            Text(palette.name,
                style: const TextStyle(fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }
}

/// A colour swatch + hex code; tapping opens the colour chooser.
class _ColourField extends StatelessWidget {
  final String label;
  final Color color;
  final ValueChanged<Color> onChanged;
  const _ColourField(
      {required this.label, required this.color, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(FrRadius.md),
      onTap: () async {
        final c = await showDialog<Color>(
          context: context,
          builder: (_) => _ColourDialog(initial: color, title: label),
        );
        if (c != null) onChanged(c);
      },
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: FrColors.surfaceAlt,
          borderRadius: BorderRadius.circular(FrRadius.md),
        ),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(FrRadius.sm),
                border: Border.all(color: FrColors.hairline),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: TextStyle(
                          color: FrColors.muted,
                          fontSize: 12,
                          fontWeight: FontWeight.w700)),
                  Text(Branding.hex(color),
                      style: const TextStyle(fontWeight: FontWeight.w800)),
                ],
              ),
            ),
            Icon(Icons.colorize_rounded, color: FrColors.muted, size: 20),
          ],
        ),
      ),
    );
  }
}

/// A grid of swatches (hues × shades, plus greys) and a hex box.
class _ColourDialog extends StatefulWidget {
  final Color initial;
  final String title;
  const _ColourDialog({required this.initial, required this.title});

  @override
  State<_ColourDialog> createState() => _ColourDialogState();
}

class _ColourDialogState extends State<_ColourDialog> {
  late Color _color = widget.initial;
  late final _hex = TextEditingController(text: Branding.hex(widget.initial));

  static final List<Color> _swatches = [
    for (final l in [0.32, 0.45, 0.58])
      for (var h = 0; h < 360; h += 30)
        HSLColor.fromAHSL(1, h.toDouble(), 0.78, l).toColor(),
    for (final g in [0x26, 0x45, 0x6E, 0x9E])
      Color.fromARGB(255, g, g, g),
  ];

  @override
  void dispose() {
    _hex.dispose();
    super.dispose();
  }

  void _pick(Color c) => setState(() {
        _color = c;
        _hex.text = Branding.hex(c);
      });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: SizedBox(
        width: 380,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final c in _swatches)
                  InkWell(
                    onTap: () => _pick(c),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      width: 26,
                      height: 26,
                      decoration: BoxDecoration(
                        color: c,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: c.toARGB32() == _color.toARGB32()
                              ? FrColors.ink
                              : Colors.transparent,
                          width: 2,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: _color,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _hex,
                    maxLength: 7,
                    decoration: const InputDecoration(
                        labelText: 'Hex code', counterText: ''),
                    onChanged: (v) {
                      final c = Branding.parseHex(v);
                      if (c != null) setState(() => _color = c);
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel')),
        FilledButton(
            onPressed: () => Navigator.pop(context, _color),
            child: const Text('Use colour')),
      ],
    );
  }
}

class _ImagePickerRow extends StatelessWidget {
  final String label;
  final String hint;
  final String? image;
  final bool square;
  final bool busy;
  final VoidCallback onPick;
  final VoidCallback onRemove;
  const _ImagePickerRow({
    required this.label,
    required this.hint,
    required this.image,
    required this.busy,
    required this.onPick,
    required this.onRemove,
    this.square = false,
  });

  @override
  Widget build(BuildContext context) {
    final provider = brandImage(image);
    return Row(
      children: [
        Container(
          width: square ? 64 : 112,
          height: 64,
          decoration: BoxDecoration(
            color: FrColors.surfaceAlt,
            borderRadius: BorderRadius.circular(FrRadius.md),
            image: provider == null
                ? null
                : DecorationImage(image: provider, fit: BoxFit.cover),
            border: Border.all(color: FrColors.hairline),
          ),
          child: busy
              ? const Center(
                  child: SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2.4)))
              : provider == null
                  ? Icon(Icons.add_photo_alternate_outlined,
                      color: FrColors.muted)
                  : null,
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontWeight: FontWeight.w800)),
              Text(hint,
                  style: TextStyle(color: FrColors.muted, fontSize: 12.5)),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: busy ? null : onPick,
                    icon: const Icon(Icons.upload_rounded, size: 18),
                    label: Text(image == null ? 'Upload' : 'Replace'),
                  ),
                  if (image != null)
                    TextButton.icon(
                      onPressed: busy ? null : onRemove,
                      icon: const Icon(Icons.delete_outline_rounded, size: 18),
                      label: const Text('Remove'),
                    ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// A small mock of the sign-in screen in the draft look (the rest of the
/// app restyles live around it).
class _BrandPreview extends StatelessWidget {
  final Branding draft;
  const _BrandPreview({required this.draft});

  @override
  Widget build(BuildContext context) {
    final photo = brandImage(draft.loginImage);
    return PremiumCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 10),
            child: Row(
              children: [
                Icon(Icons.visibility_outlined,
                    size: 18, color: FrColors.muted),
                const SizedBox(width: 6),
                Text('Preview: sign-in screen',
                    style: TextStyle(
                        color: FrColors.muted, fontWeight: FontWeight.w700)),
              ],
            ),
          ),
          ClipRRect(
            borderRadius: BorderRadius.vertical(
                bottom: Radius.circular(FrRadius.xl)),
            child: SizedBox(
              height: 420,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ColoredBox(color: FrColors.cream),
                  if (photo != null)
                    Opacity(
                        opacity: 0.45,
                        child: Image(image: photo, fit: BoxFit.cover)),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          FrColors.primary.withValues(alpha: 0.10),
                          FrColors.cream.withValues(alpha: 0.6),
                        ],
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(22),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const BrandMark(size: 54),
                        const SizedBox(height: 12),
                        GradientText(draft.appName,
                            style: const TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -1)),
                        Text(
                          draft.tagline.isEmpty
                              ? 'LPU · order ahead, skip the line'
                              : draft.tagline,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              color: FrColors.muted,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 18),
                        GlassPanel(
                          borderRadius: BorderRadius.circular(FrRadius.xl),
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const Text('Welcome back',
                                  style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w800)),
                              const SizedBox(height: 10),
                              Container(
                                height: 38,
                                decoration: BoxDecoration(
                                  color: FrColors.surfaceAlt,
                                  borderRadius:
                                      BorderRadius.circular(FrRadius.md),
                                ),
                              ),
                              const SizedBox(height: 12),
                              const IgnorePointer(
                                child: GradientButton(
                                  label: 'Sign in',
                                  height: 42,
                                  onPressed: _noop,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

void _noop() {}
