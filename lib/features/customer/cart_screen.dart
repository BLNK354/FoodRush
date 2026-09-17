import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme.dart';
import '../../providers/cart_provider.dart';
import '../../shared/widgets.dart';

class CartScreen extends ConsumerWidget {
  const CartScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lines = ref.watch(cartProvider);

    if (lines.isEmpty) {
      return const FrPage(
        title: 'Your cart',
        children: [
          SizedBox(height: 60),
          EmptyState(
            icon: Icons.shopping_cart_outlined,
            title: 'Your cart is empty',
            message: 'Browse the stalls and add something tasty.',
            action: null,
          ),
        ],
      );
    }

    final subtotal = lines.fold(0.0, (s, l) => s + l.lineTotal);

    return FrPage(
      title: 'Your cart',
      subtitle: 'Review your order before checkout.',
      children: [
        Card(
          child: Column(
            children: [
              for (final line in lines)
                ListTile(
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  title: Text(line.product.name,
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: Text('${peso(line.product.price)} each'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.remove_circle_outline),
                        onPressed: () => ref
                            .read(cartProvider.notifier)
                            .setQty(line.product.id, line.qty - 1),
                      ),
                      Text('${line.qty}',
                          style: const TextStyle(
                              fontWeight: FontWeight.w800, fontSize: 16)),
                      IconButton(
                        icon: const Icon(Icons.add_circle_outline),
                        onPressed: () => ref
                            .read(cartProvider.notifier)
                            .setQty(line.product.id, line.qty + 1),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 76,
                        child: Text(
                          peso(line.lineTotal),
                          textAlign: TextAlign.end,
                          style: const TextStyle(
                              fontWeight: FontWeight.w800, fontSize: 15),
                        ),
                      ),
                    ],
                  ),
                ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  TextButton.icon(
                    onPressed: () {
                      ref.read(cartProvider.notifier).clear();
                      showSnack(context, 'Cart cleared');
                    },
                    icon: const Icon(Icons.delete_outline, size: 18),
                    label: const Text('Clear cart'),
                  ),
                  const Spacer(),
                  const Text('Subtotal',
                      style: TextStyle(color: FrColors.muted)),
                  const SizedBox(width: 12),
                  Text(peso(subtotal),
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.w900)),
                ],
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 24),
      FilledButton.icon(
        onPressed: () => context.go('/checkout'),
        icon: const Icon(Icons.arrow_forward),
        label: const Text('Proceed to checkout'),
      ),
      const SizedBox(height: 32),
      ],
    );
  }
}
