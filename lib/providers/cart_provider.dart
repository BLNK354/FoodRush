import 'package:flutter_riverpod/flutter_riverpod.dart';

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

  /// Returns an error string if adding would mix vendors, else null.
  String? add(Product product, {int qty = 1}) {
    if (state.isNotEmpty && vendorId != product.vendorId) {
      return 'Your cart has items from another stall. Clear it first to order from this one.';
    }
    final list = [...state];
    final i = list.indexWhere((l) => l.product.id == product.id);
    if (i >= 0) {
      list[i] = CartLine(product: product, qty: list[i].qty + qty);
    } else {
      list.add(CartLine(product: product, qty: qty));
    }
    state = list;
    return null;
  }

  void setQty(String productId, int qty) {
    if (qty <= 0) {
      remove(productId);
      return;
    }
    final list = [...state];
    final i = list.indexWhere((l) => l.product.id == productId);
    if (i >= 0) list[i] = CartLine(product: list[i].product, qty: qty);
    state = list;
  }

  void remove(String productId) {
    state = state.where((l) => l.product.id != productId).toList();
  }

  void clear() => state = const [];
}

final cartProvider =
    NotifierProvider<CartController, List<CartLine>>(CartController.new);
