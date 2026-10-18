import 'package:cloud_firestore/cloud_firestore.dart' show FirebaseException;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/i18n.dart';
import '../../core/constants.dart';
import '../../core/theme.dart';
import '../../models/user.dart';
import '../../providers/cart_provider.dart';
import '../../providers/repository.dart';
import '../../shared/validation.dart';
import '../../shared/premium.dart';
import '../../shared/widgets.dart';

class CheckoutScreen extends ConsumerStatefulWidget {
  const CheckoutScreen({super.key});

  @override
  ConsumerState<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends ConsumerState<CheckoutScreen> {
  final _promo = TextEditingController();
  final _note = TextEditingController();
  String _payment = kPayGcash;
  String? _promoError;
  double _discount = 0;
  bool _placing = false;
  String? _vendorName;
  String? _pickupPoint;
  Vendor? _vendor;
  int? _ordersAhead;

  /// Requested pickup time; null = ASAP.
  DateTime? _pickupAt;

  @override
  void dispose() {
    _promo.dispose();
    _note.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _loadVendorInfo();
  }

  Future<void> _loadVendorInfo() async {
    final vendorId = ref.read(cartProvider.notifier).vendorId;
    if (vendorId == null) return;
    try {
      final v = await Repository.instance.getVendor(vendorId);
      if (!mounted || v == null) return;
      setState(() {
        _vendor = v;
        _vendorName = v.name;
        _pickupPoint = v.pickupPoint;
      });
      final ahead = await Repository.instance.ordersAhead(vendorId);
      if (mounted) setState(() => _ordersAhead = ahead);
    } catch (_) {}
  }

  /// 15-minute pickup slots from the earliest realistic time until the stall
  /// closes today (or 4 hours out when it has no schedule).
  List<DateTime> _slots(Vendor v) {
    final now = DateTime.now();
    final wait = ((_ordersAhead ?? 0) + 1) * v.prepMinutes;
    final earliest = now.add(Duration(minutes: wait < 15 ? 15 : wait));
    var t = DateTime(
      earliest.year,
      earliest.month,
      earliest.day,
      earliest.hour,
      (earliest.minute ~/ 15 + 1) * 15,
    );
    final today = v.hours[now.weekday];
    final end = v.hasSchedule && today != null
        ? DateTime(
            now.year,
            now.month,
            now.day,
          ).add(Duration(minutes: today.closeMinute))
        : now.add(const Duration(hours: 4));
    final out = <DateTime>[];
    while (t.isBefore(end) && t.day == now.day && out.length < 48) {
      if (v.isOpenAt(t)) out.add(t);
      t = t.add(const Duration(minutes: 15));
    }
    return out;
  }

  double get _subtotal => ref.read(cartProvider.notifier).subtotal;

  Future<void> _applyPromo() async {
    final vendorId = ref.read(cartProvider.notifier).vendorId;
    if (vendorId == null || _promo.text.trim().isEmpty) return;
    try {
      final res = await Repository.instance.applyPromo(
        code: _promo.text,
        vendorId: vendorId,
        subtotal: _subtotal,
      );
      if (!mounted) return;
      setState(() {
        _discount = res.valid ? res.discount : 0;
        _promoError = res.valid ? null : res.message;
      });
      showSnack(context, res.message, error: !res.valid);
    } catch (e) {
      if (mounted) showSnack(context, 'Promo check failed: $e', error: true);
    }
  }

  Future<void> _placeOrder() async {
    final cart = ref.read(cartProvider);
    if (cart.isEmpty || _placing) return; // double-tap guard
    final noteErr = validateText(_note.text, max: Limits.note, label: 'Note');
    if (noteErr != null) {
      showSnack(context, noteErr, error: true);
      return;
    }
    setState(() => _placing = true);

    final vendorId = ref.read(cartProvider.notifier).vendorId!;
    try {
      final result = await Repository.instance.placeOrder(
        vendorId: vendorId,
        items: cart
            .map(
              (l) => {
                'product_id': l.product.id,
                'qty': l.qty,
                'addons': [for (final a in l.addons) a.name],
              },
            )
            .toList(),
        paymentMethod: _payment,
        promoCode: _promo.text.trim(),
        note: _note.text.trim(),
        pickupAt: _pickupAt,
      );

      ref.read(cartProvider.notifier).clear();
      if (!mounted) return;
      final orderId = result['orderId'] as String;
      context.go('/orders/$orderId?new=1');
    } catch (e) {
      if (!mounted) return;
      setState(() => _placing = false);
      showSnack(context, _orderError(e), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final lines = ref.watch(cartProvider);
    if (lines.isEmpty) {
      return FrPage(
        title: tr('Checkout'),
        children: [
          SizedBox(height: 60),
          EmptyState(
            icon: Icons.receipt_long,
            title: tr('Nothing to check out'),
          ),
        ],
      );
    }

    final subtotal = lines.fold(0.0, (s, l) => s + l.lineTotal);
    final total = subtotal - _discount;
    final isGcash = _payment == kPayGcash;

    return FrPage(
      title: tr('Checkout'),
      subtitle: tr('Pickup only — no deliveries on FoodRush.'),
      children: [
        // Order summary
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.storefront,
                      size: 18,
                      color: FrColors.primary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _vendorName ?? 'Loading…',
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                ...lines.map(
                  (l) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Row(
                      children: [
                        Expanded(child: Text('${l.qty} × ${l.label}')),
                        Text(peso(l.lineTotal)),
                      ],
                    ),
                  ),
                ),
                const Divider(height: 24),
                _row('Subtotal', peso(subtotal)),
                if (_discount > 0)
                  _row(
                    'Discount',
                    '-${peso(_discount)}',
                    color: FrColors.success,
                  ),
                _row('Total', peso(total), bold: true),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),

        // Pickup info
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: FrColors.info.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(FrRadius.md),
                  ),
                  child: Icon(Icons.takeout_dining, color: FrColors.info),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tr('Pickup at the stall'),
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _pickupPoint ?? kDefaultPickupNote,
                        style: TextStyle(color: FrColors.muted, fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        if (_vendor != null) ...[
          const SizedBox(height: 20),
          _pickupTimeCard(_vendor!),
        ],
        const SizedBox(height: 20),

        // Payment method
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  tr('Payment method'),
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 12),
                RadioGroup<String>(
                  groupValue: _payment,
                  onChanged: (v) => setState(() => _payment = v!),
                  child: Column(
                    children: [
                      RadioListTile<String>(
                        value: kPayGcash,
                        title: Text(tr('GCash — pay now, upload receipt')),
                        subtitle: Text(
                          'You will be shown the stall\'s GCash number after ordering.',
                          style: TextStyle(fontSize: 12.5),
                        ),
                        contentPadding: EdgeInsets.zero,
                      ),
                      RadioListTile<String>(
                        value: kPayCash,
                        title: Text(tr('Cash — pay at pickup')),
                        subtitle: Text(
                          'Exact amount appreciated. Your order is accepted right away.',
                          style: TextStyle(fontSize: 12.5),
                        ),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),

        // Promo + note
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  tr('Promo code'),
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: FrTextField(
                        controller: _promo,
                        label: tr('Enter code'),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                            RegExp(r'[A-Za-z0-9]'),
                          ),
                          LengthLimitingTextInputFormatter(Limits.promoCode),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    OutlinedButton(
                      onPressed: _applyPromo,
                      child: Text(tr('Apply')),
                    ),
                  ],
                ),
                if (_promoError != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      _promoError!,
                      style: TextStyle(color: FrColors.danger, fontSize: 12.5),
                    ),
                  ),
                const SizedBox(height: 16),
                FrTextField(
                  controller: _note,
                  label: tr('Note for the stall (optional)'),
                  maxLines: 2,
                  maxLength: Limits.note,
                  validator: (v) =>
                      validateText(v, max: Limits.note, label: 'Note'),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),

        GradientButton(
          onPressed: _placeOrder,
          busy: _placing,
          height: 58,
          icon: isGcash
              ? Icons.account_balance_wallet_outlined
              : Icons.payments_outlined,
          label: isGcash
              ? tr('Place order — {total} via GCash', {'total': peso(total)})
              : tr('Place order — {total} cash at pickup', {
                  'total': peso(total),
                }),
        ),
        const SizedBox(height: 40),
      ],
    );
  }

  Widget _pickupTimeCard(Vendor v) {
    final slots = _slots(v);
    // A previously chosen slot may have slipped into the past.
    if (_pickupAt != null && !slots.contains(_pickupAt)) _pickupAt = null;
    final asapLabel = _ordersAhead == null
        ? 'As soon as possible'
        : 'As soon as possible · ${waitLabel(v, _ordersAhead!)}';
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              tr('Pickup time'),
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<DateTime?>(
              // Rebuild when the slot window moves on, so the field never
              // holds a value missing from its items.
              key: ValueKey(slots.isEmpty ? null : slots.first),
              initialValue: _pickupAt,
              isExpanded: true,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.schedule),
              ),
              items: [
                DropdownMenuItem(value: null, child: Text(asapLabel)),
                for (final t in slots)
                  DropdownMenuItem(
                    value: t,
                    child: Text(tr('Today, {time}', {'time': fmtClock(t)})),
                  ),
              ],
              onChanged: (t) => setState(() => _pickupAt = t),
            ),
            if (slots.isEmpty) ...[
              const SizedBox(height: 8),
              Text(
                tr('No later slots today. The stall closes soon.'),
                style: TextStyle(color: FrColors.muted, fontSize: 12.5),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Readable reason for a failed order instead of raw Firestore text.
  static String _orderError(Object e) {
    if (e is FirebaseException) {
      return switch (e.code) {
        'permission-denied' =>
          'The server refused this order. Only student accounts can order. '
              'If you are a student, ask the FoodRush admin to check the '
              'published security rules.',
        'unavailable' || 'deadline-exceeded' =>
          'Couldn\'t reach the server. Check your connection and try again.',
        'aborted' => 'Someone ordered at the same moment. Please try again.',
        _ => 'Order failed: ${e.message ?? e.code}',
      };
    }
    // placeOrder's own checks (closed stall, out of stock, ...) are already
    // written for people.
    // On web, an exception thrown inside a Firestore transaction comes back
    // wrapped ("Error: Dart exception: Exception: ..."): show just the text.
    return '$e'.replaceFirst(
      RegExp(r'^((Error|Dart exception|Exception|FirebaseError): ?)+'),
      '',
    );
  }

  Widget _row(String label, String value, {bool bold = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Text(
            label,
            style: TextStyle(
              color: FrColors.muted,
              fontWeight: bold ? FontWeight.w800 : null,
            ),
          ),
          const Spacer(),
          Text(
            value,
            style: TextStyle(
              fontWeight: bold ? FontWeight.w900 : FontWeight.w700,
              color: color,
              fontSize: bold ? 17 : 14.5,
            ),
          ),
        ],
      ),
    );
  }
}
