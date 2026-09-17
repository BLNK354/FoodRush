import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants.dart';
import '../../core/theme.dart';
import '../../providers/cart_provider.dart';
import '../../providers/repository.dart';
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
        _vendorName = v.name;
        _pickupPoint = v.pickupPoint;
      });
    } catch (_) {}
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
    if (cart.isEmpty) return;
    setState(() => _placing = true);

    final vendorId = ref.read(cartProvider.notifier).vendorId!;
    try {
      final result = await Repository.instance.placeOrder(
        vendorId: vendorId,
        items: cart
            .map((l) => {'product_id': l.product.id, 'qty': l.qty})
            .toList(),
        paymentMethod: _payment,
        promoCode: _promo.text.trim(),
        note: _note.text.trim(),
      );

      ref.read(cartProvider.notifier).clear();
      if (!mounted) return;
      final orderId = result['orderId'] as String;
      context.go('/orders/$orderId?new=1');
    } catch (e) {
      if (!mounted) return;
      setState(() => _placing = false);
      showSnack(context, 'Order failed: $e', error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final lines = ref.watch(cartProvider);
    if (lines.isEmpty) {
      return const FrPage(title: 'Checkout', children: [
        SizedBox(height: 60),
        EmptyState(icon: Icons.receipt_long, title: 'Nothing to check out'),
      ]);
    }

    final subtotal = lines.fold(0.0, (s, l) => s + l.lineTotal);
    final total = subtotal - _discount;
    final isGcash = _payment == kPayGcash;

    return FrPage(
      title: 'Checkout',
      subtitle: 'Pickup only — no deliveries on FoodRush.',
      children: [
        // Order summary
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(children: [
                  const Icon(Icons.storefront, size: 18, color: FrColors.primary),
                  const SizedBox(width: 8),
                  Text(_vendorName ?? 'Loading…',
                      style: const TextStyle(fontWeight: FontWeight.w800)),
                ]),
                const SizedBox(height: 10),
                ...lines.map((l) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      child: Row(
                        children: [
                          Expanded(child: Text('${l.qty} × ${l.product.name}')),
                          Text(peso(l.lineTotal)),
                        ],
                      ),
                    )),
                const Divider(height: 24),
                _row('Subtotal', peso(subtotal)),
                if (_discount > 0)
                  _row('Discount', '-${peso(_discount)}',
                      color: FrColors.success),
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
                  child: const Icon(Icons.takeout_dining,
                      color: FrColors.info),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Pickup at the stall',
                          style: TextStyle(fontWeight: FontWeight.w800)),
                      const SizedBox(height: 2),
                      Text(
                        _pickupPoint ?? kDefaultPickupNote,
                        style: const TextStyle(
                            color: FrColors.muted, fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),

        // Payment method
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('Payment method',
                    style: TextStyle(fontWeight: FontWeight.w800)),
                const SizedBox(height: 12),
                RadioGroup<String>(
                  groupValue: _payment,
                  onChanged: (v) => setState(() => _payment = v!),
                  child: const Column(
                    children: [
                      RadioListTile<String>(
                        value: kPayGcash,
                        title: Text('GCash — pay now, upload receipt'),
                        subtitle: Text(
                            'You will be shown the stall\'s GCash number after ordering.',
                            style: TextStyle(fontSize: 12.5)),
                        contentPadding: EdgeInsets.zero,
                      ),
                      RadioListTile<String>(
                        value: kPayCash,
                        title: Text('Cash — pay at pickup'),
                        subtitle: Text(
                            'Exact amount appreciated. Your order is accepted right away.',
                            style: TextStyle(fontSize: 12.5)),
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
                const Text('Promo code',
                    style: TextStyle(fontWeight: FontWeight.w800)),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: FrTextField(
                        controller: _promo,
                        label: 'Enter code',
                      ),
                    ),
                    const SizedBox(width: 10),
                    OutlinedButton(
                      onPressed: _applyPromo,
                      child: const Text('Apply'),
                    ),
                  ],
                ),
                if (_promoError != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(_promoError!,
                        style: const TextStyle(
                            color: FrColors.danger, fontSize: 12.5)),
                  ),
                const SizedBox(height: 16),
                FrTextField(
                  controller: _note,
                  label: 'Note for the stall (optional)',
                  maxLines: 2,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),

        FilledButton(
          onPressed: _placing ? null : _placeOrder,
          style: FilledButton.styleFrom(minimumSize: const Size(0, 54)),
          child: _placing
              ? const SizedBox(
                  height: 22,
                  width: 22,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white))
              : Text(
                  isGcash
                      ? 'Place order — ${peso(total)} via GCash'
                      : 'Place order — ${peso(total)} cash at pickup',
                  style: const TextStyle(fontSize: 15)),
        ),
        const SizedBox(height: 40),
      ],
    );
  }

  Widget _row(String label, String value, {bool bold = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Text(label,
              style: TextStyle(
                  color: FrColors.muted,
                  fontWeight: bold ? FontWeight.w800 : null)),
          const Spacer(),
          Text(value,
              style: TextStyle(
                  fontWeight: bold ? FontWeight.w900 : FontWeight.w700,
                  color: color,
                  fontSize: bold ? 17 : 14.5)),
        ],
      ),
    );
  }
}
