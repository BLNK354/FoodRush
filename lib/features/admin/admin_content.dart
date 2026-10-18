import 'dart:async';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../models/misc.dart';
import '../../models/user.dart';
import '../../providers/repository.dart';
import '../../shared/home_banners.dart';
import '../../shared/validation.dart';
import '../../shared/widgets.dart';
import '../customer/shop_screen.dart' show ShopHero;
import 'admin_branding.dart';

/// Admin CMS: what students see at the top of the Shop page — the hero
/// headline and a carousel of promo banners. Changes go live instantly.
class AdminContentScreen extends StatefulWidget {
  const AdminContentScreen({super.key});

  @override
  State<AdminContentScreen> createState() => _AdminContentScreenState();
}

class _AdminContentScreenState extends State<AdminContentScreen> {
  String _tab = 'branding';

  @override
  Widget build(BuildContext context) {
    return FrPage(
      title: 'Content',
      subtitle: 'Design the whole app and what students see on the Shop page.',
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: SegmentedButton<String>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(
                  value: 'branding',
                  icon: Icon(Icons.palette_outlined),
                  label: Text('Branding')),
              ButtonSegment(
                  value: 'shop',
                  icon: Icon(Icons.storefront_outlined),
                  label: Text('Shop page')),
            ],
            selected: {_tab},
            onSelectionChanged: (s) => setState(() => _tab = s.first),
          ),
        ),
        const SizedBox(height: 20),
        if (_tab == 'branding')
          const BrandingEditor()
        else ...const [
          _HeroEditor(),
          SizedBox(height: 20),
          _BannersEditor(),
        ],
        const SizedBox(height: 40),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Hero copy
// ---------------------------------------------------------------------------

class _HeroEditor extends StatefulWidget {
  const _HeroEditor();

  @override
  State<_HeroEditor> createState() => _HeroEditorState();
}

class _HeroEditorState extends State<_HeroEditor> {
  final _title = TextEditingController();
  final _subtitle = TextEditingController();
  bool _loaded = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    // Rebuild the preview as the admin types.
    _title.addListener(_refresh);
    _subtitle.addListener(_refresh);
    Repository.instance.streamHomeContent().first.then((c) {
      if (!mounted) return;
      _title.text = c.heroTitle;
      _subtitle.text = c.heroSubtitle;
      setState(() => _loaded = true);
    }, onError: (Object _) {
      if (mounted) setState(() => _loaded = true);
    });
  }

  void _refresh() => setState(() {});

  @override
  void dispose() {
    _title.dispose();
    _subtitle.dispose();
    super.dispose();
  }

  Future<void> _save({bool reset = false}) async {
    if (reset) {
      _title.clear();
      _subtitle.clear();
    }
    final err = firstError([
      validateText(_title.text, max: Limits.heroTitle, label: 'Headline'),
      validateText(_subtitle.text,
          max: Limits.heroSubtitle, label: 'Subheadline'),
    ]);
    if (err != null) {
      showSnack(context, err, error: true);
      return;
    }
    setState(() => _saving = true);
    try {
      await Repository.instance.setHomeContent(
          heroTitle: _title.text, heroSubtitle: _subtitle.text);
      if (mounted) {
        showSnack(context,
            reset ? 'Hero reset to the default text.' : 'Hero updated.');
      }
    } catch (e) {
      if (mounted) showSnack(context, 'Could not save: $e', error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final fields = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FrTextField(
          controller: _title,
          label: 'Headline',
          hint: 'Hungry? Skip the line.',
          maxLength: Limits.heroTitle,
          enabled: _loaded,
        ),
        const SizedBox(height: 12),
        FrTextField(
          controller: _subtitle,
          label: 'Subheadline',
          hint: 'Stalls on campus — order ahead, pick up when it\'s ready.',
          maxLines: 2,
          maxLength: Limits.heroSubtitle,
          enabled: _loaded,
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            FilledButton(
              onPressed: !_loaded || _saving ? null : _save,
              child: const Text('Save hero'),
            ),
            OutlinedButton(
              onPressed:
                  !_loaded || _saving ? null : () => _save(reset: true),
              child: const Text('Use default text'),
            ),
          ],
        ),
      ],
    );
    final preview = IgnorePointer(
      child: ShopHero(
        firstName: 'Juan',
        openCount: 3,
        title: _title.text,
        subtitle: _subtitle.text,
      ),
    );
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SectionHeader('Shop hero'),
            Text('The big greeting at the top of the Shop page. '
                'Leave a field blank to keep the default (translated) text.',
                style: TextStyle(color: FrColors.muted, fontSize: 13)),
            const SizedBox(height: 16),
            LayoutBuilder(builder: (context, c) {
              if (c.maxWidth < 860) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [fields, const SizedBox(height: 20), preview],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 4, child: fields),
                  const SizedBox(width: 24),
                  Expanded(flex: 6, child: preview),
                ],
              );
            }),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Banners
// ---------------------------------------------------------------------------

class _BannersEditor extends StatefulWidget {
  const _BannersEditor();

  @override
  State<_BannersEditor> createState() => _BannersEditorState();
}

class _BannersEditorState extends State<_BannersEditor> {
  StreamSubscription<List<HomeBanner>>? _sub;
  List<HomeBanner>? _banners;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _sub = Repository.instance.streamBanners().listen(
          (b) => mounted ? setState(() => _banners = b) : null,
          onError: (Object e) => mounted ? setState(() => _error = e) : null,
        );
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  Future<void> _edit([HomeBanner? existing]) async {
    final next = _banners?.length ?? 0;
    final saved = await showDialog<HomeBanner>(
      context: context,
      builder: (_) => _BannerDialog(
        initial: existing ?? HomeBanner(title: '', order: next),
      ),
    );
    if (saved == null) return;
    try {
      await Repository.instance.saveBanner(saved);
      if (mounted) {
        showSnack(context, existing == null ? 'Banner added.' : 'Banner saved.');
      }
    } catch (e) {
      if (mounted) showSnack(context, 'Could not save: $e', error: true);
    }
  }

  Future<void> _toggle(HomeBanner b, bool active) async {
    try {
      await Repository.instance.saveBanner(b.copyWith(active: active));
    } catch (e) {
      if (mounted) showSnack(context, 'Could not update: $e', error: true);
    }
  }

  Future<void> _move(int from, int to) async {
    final list = [...?_banners];
    if (to < 0 || to >= list.length) return;
    list.insert(to, list.removeAt(from));
    setState(() => _banners = list); // feels instant; the stream confirms
    try {
      await Repository.instance.reorderBanners(list.map((b) => b.id).toList());
    } catch (e) {
      if (mounted) showSnack(context, 'Could not reorder: $e', error: true);
    }
  }

  Future<void> _delete(HomeBanner b) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete banner?'),
        content: Text('"${b.title}" will disappear from the Shop page.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Delete')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await Repository.instance.deleteBanner(b.id);
      if (mounted) showSnack(context, 'Banner deleted.');
    } catch (e) {
      if (mounted) showSnack(context, 'Could not delete: $e', error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final banners = _banners;
    final live = banners?.where((b) => b.active).length ?? 0;
    Widget body;
    if (_error != null) {
      body = EmptyState(
        icon: Icons.error_outline,
        title: 'Could not load banners',
        message: '$_error',
      );
    } else if (banners == null) {
      body = const Padding(
        padding: EdgeInsets.all(32),
        child: Center(child: CircularProgressIndicator()),
      );
    } else if (banners.isEmpty) {
      body = EmptyState(
        icon: Icons.view_carousel_outlined,
        title: 'No banners yet',
        message: 'Promote a stall, a deal or campus news with a banner '
            'on the Shop page.',
        action: FilledButton.icon(
          onPressed: _edit,
          icon: const Icon(Icons.add),
          label: const Text('Create a banner'),
        ),
      );
    } else {
      body = Column(
        children: [
          for (var i = 0; i < banners.length; i++) ...[
            if (i > 0) const SizedBox(height: 14),
            _BannerRow(
              banner: banners[i],
              canUp: i > 0,
              canDown: i < banners.length - 1,
              onUp: () => _move(i, i - 1),
              onDown: () => _move(i, i + 1),
              onToggle: (v) => _toggle(banners[i], v),
              onEdit: () => _edit(banners[i]),
              onDelete: () => _delete(banners[i]),
            ),
          ],
        ],
      );
    }
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Expanded(child: SectionHeader('Shop banners')),
                if (banners != null && banners.isNotEmpty) ...[
                  StatusChip('$live live',
                      color: live > 0 ? FrColors.success : FrColors.muted),
                  const SizedBox(width: 12),
                  FilledButton.icon(
                    onPressed: _edit,
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('New banner'),
                  ),
                ],
              ],
            ),
            Text('Live banners rotate under the hero, top to bottom.',
                style: TextStyle(color: FrColors.muted, fontSize: 13)),
            const SizedBox(height: 16),
            body,
          ],
        ),
      ),
    );
  }
}

class _BannerRow extends StatelessWidget {
  final HomeBanner banner;
  final bool canUp;
  final bool canDown;
  final VoidCallback onUp;
  final VoidCallback onDown;
  final ValueChanged<bool> onToggle;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _BannerRow({
    required this.banner,
    required this.canUp,
    required this.canDown,
    required this.onUp,
    required this.onDown,
    required this.onToggle,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final controls = Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Switch(value: banner.active, onChanged: onToggle),
        const SizedBox(width: 4),
        Text(banner.active ? 'Live' : 'Hidden',
            style: TextStyle(
                fontWeight: FontWeight.w700,
                color: banner.active ? FrColors.success : FrColors.muted)),
        const SizedBox(width: 8),
        IconButton(
            tooltip: 'Move up',
            onPressed: canUp ? onUp : null,
            icon: const Icon(Icons.arrow_upward)),
        IconButton(
            tooltip: 'Move down',
            onPressed: canDown ? onDown : null,
            icon: const Icon(Icons.arrow_downward)),
        IconButton(
            tooltip: 'Edit',
            onPressed: onEdit,
            icon: const Icon(Icons.edit_outlined)),
        IconButton(
            tooltip: 'Delete',
            onPressed: onDelete,
            icon: Icon(Icons.delete_outline, color: FrColors.danger)),
      ],
    );
    final card = Opacity(
      opacity: banner.active ? 1 : 0.55,
      child: GestureDetector(
        onTap: onEdit,
        child: HomeBannerCard(banner: banner, preview: true, height: 140),
      ),
    );
    return LayoutBuilder(builder: (context, c) {
      if (c.maxWidth < 720) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [card, const SizedBox(height: 6), controls],
        );
      }
      return Row(
        children: [
          Expanded(child: card),
          const SizedBox(width: 16),
          SizedBox(width: 300, child: controls),
        ],
      );
    });
  }
}

// ---------------------------------------------------------------------------
// Banner editor dialog (with live preview)
// ---------------------------------------------------------------------------

class _BannerDialog extends StatefulWidget {
  final HomeBanner initial;
  const _BannerDialog({required this.initial});

  @override
  State<_BannerDialog> createState() => _BannerDialogState();
}

class _BannerDialogState extends State<_BannerDialog> {
  late final _title = TextEditingController(text: widget.initial.title);
  late final _body = TextEditingController(text: widget.initial.body ?? '');
  late final _cta = TextEditingController(text: widget.initial.ctaLabel ?? '');
  late String _style = widget.initial.style;
  late String? _link = widget.initial.link;
  late String? _image = widget.initial.imageUrl;
  late bool _active = widget.initial.active;
  List<Vendor> _stalls = const [];
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    for (final c in [_title, _body, _cta]) {
      c.addListener(() => setState(() {}));
    }
    Repository.instance.listApprovedVendors().then(
        (s) => mounted ? setState(() => _stalls = s) : null,
        onError: (Object _) {});
  }

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    _cta.dispose();
    super.dispose();
  }

  HomeBanner get _draft => HomeBanner(
        id: widget.initial.id,
        title: _title.text,
        body: _body.text,
        ctaLabel: _cta.text,
        link: _link,
        imageUrl: _image,
        style: _style,
        active: _active,
        order: widget.initial.order,
      );

  Future<void> _pickImage() async {
    final picked = await FilePicker.platform
        .pickFiles(type: FileType.image, withData: true);
    final f = picked?.files.single;
    final Uint8List? bytes = f?.bytes;
    if (f == null || bytes == null) return;
    setState(() => _busy = true);
    try {
      // Wide banners need more pixels than menu photos, but must stay under
      // the rules' 300k-character cap.
      var url = await Repository.instance.uploadImage(
          pathPrefix: 'banners', bytes: bytes, fileName: f.name, maxDim: 1200);
      if (url.length > 290000) {
        url = await Repository.instance.uploadImage(
            pathPrefix: 'banners',
            bytes: bytes,
            fileName: f.name,
            maxDim: 900,
            quality: 60);
      }
      if (url.length > 290000) throw Exception('Image is too detailed.');
      if (mounted) setState(() => _image = url);
    } catch (e) {
      if (mounted) showSnack(context, 'Could not use image: $e', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _submit() {
    final err = firstError([
      validateText(_title.text,
          max: Limits.bannerTitle, required: true, label: 'Title'),
      validateText(_body.text, max: Limits.bannerBody, label: 'Text'),
      validateText(_cta.text, max: Limits.bannerCta, label: 'Button label'),
      _cta.text.trim().isNotEmpty && _link == null
          ? 'Pick where the button goes, or clear the button label'
          : null,
    ]);
    if (err != null) {
      showSnack(context, err, error: true);
      return;
    }
    Navigator.pop(context, _draft);
  }

  @override
  Widget build(BuildContext context) {
    final links = <String, String>{
      '/shop': 'Shop page',
      '/orders': 'My orders',
      '/cart': 'Cart',
      for (final s in _stalls) '/stall/${s.id}': 'Stall · ${s.name}',
      // Keep a saved link selectable even if its stall is gone now.
      if (_link != null) _link!: 'Current link ($_link)',
    };
    return Dialog(
      insetPadding: const EdgeInsets.all(16),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 580),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 12, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                        widget.initial.id.isEmpty ? 'New banner' : 'Edit banner',
                        style: Theme.of(context).textTheme.titleLarge),
                  ),
                  IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close)),
                ],
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    HomeBannerCard(banner: _draft, preview: true),
                    const SizedBox(height: 18),
                    FrTextField(
                      controller: _title,
                      label: 'Title',
                      hint: 'e.g. 20% off silog meals this week',
                      maxLength: Limits.bannerTitle,
                    ),
                    const SizedBox(height: 12),
                    FrTextField(
                      controller: _body,
                      label: 'Text (optional)',
                      hint: 'One or two short lines',
                      maxLines: 2,
                      maxLength: Limits.bannerBody,
                    ),
                    const SizedBox(height: 16),
                    Text('Background',
                        style: TextStyle(
                            fontWeight: FontWeight.w700, color: FrColors.ink)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        for (final s in HomeBanner.styles)
                          _StyleSwatch(
                            style: s,
                            selected: _style == s,
                            onTap: () => setState(() => _style = s),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 10,
                      runSpacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        OutlinedButton.icon(
                          onPressed: _busy ? null : _pickImage,
                          icon: _busy
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2))
                              : const Icon(Icons.image_outlined, size: 18),
                          label: Text(_image == null
                              ? 'Add background photo'
                              : 'Change photo'),
                        ),
                        if (_image != null)
                          TextButton(
                            onPressed: () => setState(() => _image = null),
                            child: const Text('Remove photo'),
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    FrTextField(
                      controller: _cta,
                      label: 'Button label (optional)',
                      hint: 'e.g. Order now',
                      maxLength: Limits.bannerCta,
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String?>(
                      initialValue: _link,
                      isExpanded: true,
                      decoration:
                          const InputDecoration(labelText: 'Button opens'),
                      items: [
                        const DropdownMenuItem(
                            value: null, child: Text('Nothing (no button)')),
                        for (final e in links.entries)
                          DropdownMenuItem(
                              value: e.key,
                              child: Text(e.value,
                                  overflow: TextOverflow.ellipsis)),
                      ],
                      onChanged: (v) => setState(() => _link = v),
                    ),
                    const SizedBox(height: 8),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      value: _active,
                      onChanged: (v) => setState(() => _active = v),
                      title: const Text('Live on the Shop page'),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel')),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: _busy ? null : _submit,
                    child: const Text('Save banner'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StyleSwatch extends StatelessWidget {
  final String style;
  final bool selected;
  final VoidCallback onTap;
  const _StyleSwatch(
      {required this.style, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: bannerStyleLabel(style),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(FrRadius.md),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: 64,
          height: 40,
          decoration: BoxDecoration(
            gradient: bannerGradient(style),
            borderRadius: BorderRadius.circular(FrRadius.md),
            border: Border.all(
              color: selected ? FrColors.ink : Colors.transparent,
              width: 2.5,
            ),
          ),
          child: selected
              ? const Icon(Icons.check, color: Colors.white, size: 20)
              : null,
        ),
      ),
    );
  }
}
