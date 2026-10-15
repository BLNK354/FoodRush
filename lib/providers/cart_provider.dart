import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/constants.dart';
import '../models/product.dart';

class CartLine {
  final Product product;
  final int qty;

  /// Chosen add-ons (each line is one product + one add-on combination).
  final List<Addon> addons;

  const CartLine({required this.product, required this.qty, this.addons = const []});

  /// Identifies the line: "Adobo + Extra rice" and plain "Adobo" are separate.
  String get key => lineKey(product.id, addons);

  static String lineKey(String productId, List<Addon> addons) =>
      ([productId, ...(addons.map((a) => a.name).toList()..sort())]).join('|');

  double get unitPrice =>
      product.price + addons.fold(0.0, (s, a) => s + a.price);
  double get lineTotal => unitPrice * qty;

  /// "Adobo (+ Extra rice)".
  String get label => addons.isEmpty
      ? product.name
      : '${product.name} (+ ${addons.map((a) => a.name).join(', ')})';

  CartLine withQty(int q) => CartLine(product: product, qty: q, addons: addons);
}

/// Simple in-memory cart. Enforces the foodpanda rule: one vendor per cart.
class CartController extends Notifier<List<CartLine>> {
  @override
  List<CartLine> build() => const [];

  String? get vendorId => state.isEmpty ? null : state.first.product.vendorId;
  double get subtotal => state.fold(0, (sum, l) => sum + l.lineTotal);
  int get itemCount => state.fold(0, (sum, l) => sum + l.qty);

  /// Most of one product a single order may hold: [kMaxCartQty], or what the
  /// stall has left for stock-limited items (shared by all its add-on lines).
  static int maxQtyFor(Product p) =>
      p.stockQty == null || p.stockQty! > kMaxCartQty ? kMaxCartQty : p.stockQty!;

  /// Distinct lines per order (the rules allow 50; this is plenty).
  static const maxLines = 30;

  /// How many of [productId] the cart holds across all add-on combinations.
  int qtyOfProduct(String productId) => state
      .where((l) => l.product.id == productId)
      .fold(0, (s, l) => s + l.qty);

  /// Returns an error string if the item can't be added, else null.
  String? add(Product product, {int qty = 1, List<Addon> addons = const []}) {
    if (state.isNotEmpty && vendorId != product.vendorId) {
      return 'Your cart has items from another stall. Clear it first to order from this one.';
    }
    if (qty <= 0) return null;
    final max = maxQtyFor(product);
    if (max <= 0) return '${product.name} is sold out.';
    final already = qtyOfProduct(product.id);
    if (already >= max) return 'You can order up to $max of ${product.name}.';
    final list = [...state];
    final key = CartLine.lineKey(product.id, addons);
    final i = list.indexWhere((l) => l.key == key);
    if (i < 0 && list.length >= maxLines) {
      return 'That\'s a lot of different items! Max $maxLines per order.';
    }
    final room = max - already;
    final add = qty > room ? room : qty;
    if (i >= 0) {
      list[i] = list[i].withQty(list[i].qty + add);
    } else {
      list.add(CartLine(product: product, qty: add, addons: addons));
    }
    state = list;
    return add < qty ? 'You can order up to $max of ${product.name}.' : null;
  }

  /// Sets a line's quantity within the product's limit; 0 or less removes it.
  void setQty(String lineKey, int qty) {
    if (qty <= 0) {
      remove(lineKey);
      return;
    }
    final list = [...state];
    final i = list.indexWhere((l) => l.key == lineKey);
    if (i < 0) return;
    final line = list[i];
    final others = qtyOfProduct(line.product.id) - line.qty;
    final cap = maxQtyFor(line.product) - others;
    list[i] = line.withQty(qty.clamp(1, cap < 1 ? 1 : cap));
    state = list;
  }

  /// True when no more of this line's product fits the order.
  bool atLimit(CartLine line) =>
      qtyOfProduct(line.product.id) >= maxQtyFor(line.product);

  void remove(String lineKey) {
    state = state.where((l) => l.key != lineKey).toList();
  }

  void clear() => state = const [];
}

final cartProvider =
    NotifierProvider<CartController, List<CartLine>>(CartController.new);
