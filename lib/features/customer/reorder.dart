import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/order.dart';
import '../../providers/cart_provider.dart';
import '../../providers/repository.dart';
import '../../shared/widgets.dart';

/// "Order again": refills the cart from a past order at today's menu prices,
/// skipping items that are gone, unavailable or out of stock, then opens the
/// cart so the student can review before checking out.
bool _reordering = false; // ignore double-taps while one is running

Future<void> reorder(BuildContext context, WidgetRef ref, Order order) async {
  if (_reordering) return;
  _reordering = true;
  try {
    await _reorder(context, ref, order);
  } finally {
    _reordering = false;
  }
}

Future<void> _reorder(BuildContext context, WidgetRef ref, Order order) async {
  final cart = ref.read(cartProvider.notifier);
  if (cart.vendorId != null && cart.vendorId != order.vendorId) {
    final ok = await confirmDialog(
      context,
      title: 'Replace your cart?',
      message: 'Your cart has items from another stall. Ordering again from '
          '${order.vendorName ?? 'this stall'} will clear it.',
      confirmLabel: 'Replace cart',
    );
    if (!ok || !context.mounted) return;
    cart.clear();
  }

  try {
    final vendor = await Repository.instance.getVendor(order.vendorId);
    if (!context.mounted) return;
    if (vendor == null) {
      showSnack(context, 'That stall no longer exists.', error: true);
      return;
    }
    final products = {
      for (final p in await Repository.instance.listProducts(order.vendorId))
        p.id: p,
    };
    if (!context.mounted) return;

    final skipped = <String>[];
    var added = 0;
    for (final it in order.items) {
      final p = products[it.productId];
      if (p == null || !p.isAvailable || p.stockQty == 0) {
        skipped.add(it.name);
        continue;
      }
      final qty = p.stockQty == null ? it.qty : it.qty.clamp(1, p.stockQty!);
      if (cart.add(p, qty: qty) == null) added++;
    }

    if (added == 0) {
      showSnack(context, 'None of those items are available right now.',
          error: true);
      return;
    }
    context.go('/cart');
    showSnack(
      context,
      skipped.isEmpty
          ? 'Added to your cart at today\'s prices.'
          : 'Added what\'s available. Not available: ${skipped.join(', ')}.',
    );
    if (!vendor.isOpenNow) {
      showSnack(context,
          '${vendor.name} is closed right now. You can order when it opens.');
    }
  } catch (e) {
    if (context.mounted) showSnack(context, 'Could not reorder: $e', error: true);
  }
}
