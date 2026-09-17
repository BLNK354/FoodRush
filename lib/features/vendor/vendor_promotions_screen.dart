import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import '../../models/misc.dart';
import '../../models/user.dart';
import '../../providers/repository.dart';
import '../../shared/widgets.dart';

class VendorPromotionsScreen extends ConsumerStatefulWidget {
  const VendorPromotionsScreen({super.key});

  @override
  ConsumerState<VendorPromotionsScreen> createState() =>
      _VendorPromotionsScreenState();
}

class _VendorPromotionsScreenState extends ConsumerState<VendorPromotionsScreen> {
  Vendor? _vendor;
  List<Promotion> _promos = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final vendor = await Repository.instance.getMyVendor();
      if (vendor == null) {
        if (!mounted) return;
        setState(() => _loading = false);
        return;
      }
      final promos = await Repository.instance.listPromotions(vendorId: vendor.id);
      if (!mounted) return;
      setState(() {
        _vendor = vendor;
        _promos = promos;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      showSnack(context, 'Could not load promotions: $e', error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final mine = _promos.where((p) => !p.isPlatformWide).toList();
    final platform = _promos.where((p) => p.isPlatformWide).toList();

    return FrPage(
      title: 'Promotions',
      subtitle: 'Discount codes for your stall.',
      actions: [
        IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
        FilledButton.icon(
          onPressed: _vendor == null ? null : () => _editPromo(null),
          icon: const Icon(Icons.add),
          label: const Text('New promo'),
        ),
      ],
      children: [
        if (_loading && _promos.isEmpty)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(48),
              child: CircularProgressIndicator(),
            ),
          )
        else ...[
          SectionHeader('Your promo codes'),
          if (mine.isEmpty)
            const EmptyState(
              icon: Icons.local_offer_outlined,
              title: 'No promo codes yet',
              message: 'Create one to attract more orders.',
            )
          else
            ...mine.map(_promoTile),
          const SizedBox(height: 24),
          SectionHeader('FoodRush-wide codes'),
          if (platform.isEmpty)
            const Text('No platform-wide promos right now.',
                style: TextStyle(color: FrColors.muted))
          else
            ...platform.map((p) => Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  child: ListTile(
                    leading: const Icon(Icons.card_giftcard,
                        color: FrColors.secondary),
                    title: Text(p.code,
                        style: const TextStyle(fontWeight: FontWeight.w800)),
                    subtitle: Text(_desc(p)),
                  ),
                )),
        ],
        const SizedBox(height: 40),
      ],
    );
  }

  String _desc(Promotion p) {
    final d = p.discountType == 'percent'
        ? '${_trim(p.discountValue)}% off'
        : '${peso(p.discountValue)} off';
    final min = p.minOrder != null ? ' · min ${peso(p.minOrder!)}' : '';
    final active = p.isActive ? '' : ' · INACTIVE';
    return '$d$min$active';
  }

  String _trim(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(2);

  Widget _promoTile(Promotion p) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: Icon(
          Icons.local_offer,
          color: p.isActive ? FrColors.primary : FrColors.muted,
        ),
        title: Text(p.code,
            style: const TextStyle(fontWeight: FontWeight.w800)),
        subtitle: Text(_desc(p)),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Switch(
              value: p.isActive,
              onChanged: (_) => _toggle(p),
            ),
            IconButton(
              icon: const Icon(Icons.edit_outlined, size: 20),
              onPressed: () => _editPromo(p),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline,
                  size: 20, color: FrColors.danger),
              onPressed: () => _delete(p),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _toggle(Promotion p) async {
    try {
      await Repository.instance.upsertPromotion(
        id: p.id,
        vendorId: p.vendorId,
        code: p.code,
        discountType: p.discountType,
        discountValue: p.discountValue,
        minOrder: p.minOrder,
        isActive: !p.isActive,
        startsAt: p.startsAt,
        endsAt: p.endsAt,
      );
      await _load();
    } catch (e) {
      if (mounted) showSnack(context, 'Update failed: $e', error: true);
    }
  }

  Future<void> _delete(Promotion p) async {
    final ok = await confirmDialog(
      context,
      title: 'Delete ${p.code}?',
      confirmLabel: 'Delete',
      destructive: true,
    );
    if (!ok) return;
    try {
      await Repository.instance.deletePromotion(p.id);
      await _load();
    } catch (e) {
      if (mounted) showSnack(context, 'Delete failed: $e', error: true);
    }
  }

  Future<void> _editPromo(Promotion? existing) async {
    final code = TextEditingController(text: existing?.code ?? '');
    final value = TextEditingController(
        text: existing == null ? '' : _trim(existing.discountValue));
    final existingMin = existing?.minOrder;
    final minOrder = TextEditingController(
        text: existingMin == null ? '' : _trim(existingMin));
    String type = existing?.discountType ?? 'percent';
    bool active = existing?.isActive ?? true;

    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(existing == null ? 'New promo code' : 'Edit promo'),
          content: SizedBox(
            width: 380,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: code,
                  textCapitalization: TextCapitalization.characters,
                  decoration: const InputDecoration(
                      labelText: 'Code (e.g. FIFOYSALAMAT)'),
                ),
                const SizedBox(height: 12),
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'percent', label: Text('% off')),
                    ButtonSegment(value: 'fixed', label: Text('₱ off')),
                  ],
                  selected: {type},
                  onSelectionChanged: (s) =>
                      setDialogState(() => type = s.first),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: value,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: type == 'percent'
                        ? 'Discount percent'
                        : 'Discount amount (₱)',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: minOrder,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                      labelText: 'Minimum order (₱, optional)'),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Active'),
                  value: active,
                  onChanged: (v) => setDialogState(() => active = v),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
    if (saved != true) return;

    final valueNum = double.tryParse(value.text.trim());
    if (code.text.trim().isEmpty || valueNum == null || valueNum <= 0) {
      if (mounted) {
        showSnack(context, 'Code and a positive value are required.',
            error: true);
      }
      return;
    }

    try {
      await Repository.instance.upsertPromotion(
        id: existing?.id,
        vendorId: _vendor?.id,
        code: code.text.trim(),
        discountType: type,
        discountValue: valueNum,
        minOrder: double.tryParse(minOrder.text.trim()),
        isActive: active,
      );
      if (mounted) showSnack(context, 'Promo saved.');
      await _load();
    } catch (e) {
      if (mounted) showSnack(context, 'Save failed: $e', error: true);
    }
  }
}
