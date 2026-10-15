import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/constants.dart';
import '../models/product.dart';

class CartLine {
  final Product product;
  final int qty;
  const CartLine({required this.product, required this.qty});
  double get lineTotal => product.price * qty;
}

/// Simple in-memory cart. Enforces the foodpanda rule: one vendor per cart.
class CartController extends Notifier<List<CartLine>> {
  @override
  List<CartLine> build() => const [];

  String? get vendorId => state.isEmpty ? null : state.first.product.vendorId;
  double get subtotal =>
      state.fold(0, (sum, l) => sum + l.lineTotal);
  int get itemCount => state.fold(0, (sum, l) => sum + l.qty);

  /// Most of one item a single order may hold: [kMaxCartQty], or what the
  /// stall has left for stock-limited items.
  static int maxQtyFor(Product p) =>
      p.stockQty == null || p.stockQty! > kMaxCartQty ? kMaxCartQty : p.stockQty!;

  /// Distinct items per order (the rules allow 50; this is plenty).
  static const maxLines = 30;

  /// Returns an error string if the item can't be added, else null.
  String? add(Product product, {int qty = 1}) {
    if (state.isNotEmpty && vendorId != product.vendorId) {
      return 'Your cart has items from another stall. Clear it first to order from this one.';
    }
    if (qty <= 0) return null;
    final list = [...state];
    final i = list.indexWhere((l) => l.product.id == product.id);
    final max = maxQtyFor(product);
    final current = i >= 0 ? list[i].qty : 0;
    if (max <= 0) return '${product.name} is sold out.';
    if (current >= max) {
      return 'You can order up to $max of ${product.name}.';
    }
    if (i < 0 && list.length >= maxLines) {
      return 'That\'s a lot of different items! Max $maxLines per order.';
    }
    final next = (current + qty).clamp(1, max);
    if (i >= 0) {
      list[i] = CartLine(product: product, qty: next);
    } else {
      list.add(CartLine(product: product, qty: next));
    }
    state = list;
    return null;
  }

  /// Sets a line's quantity, clamped to [maxQtyFor]; 0 or less removes it.
  void setQty(String productId, int qty) {
    if (qty <= 0) {
      remove(productId);
      return;
    }
    final list = [...state];
    final i = list.indexWhere((l) => l.product.id == productId);
    if (i >= 0) {
      final p = list[i].product;
      list[i] = CartLine(product: p, qty: qty.clamp(1, maxQtyFor(p)));
    }
    state = list;
  }

  void remove(String productId) {
    state = state.where((l) => l.product.id != productId).toList();
  }

  void clear() => state = const [];
}

final cartProvider =
    NotifierProvider<CartController, List<CartLine>>(CartController.new);
