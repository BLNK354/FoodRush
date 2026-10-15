import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/i18n.dart';
import '../../core/theme.dart';
import '../../providers/cart_provider.dart';
import '../../shared/premium.dart';
import '../../shared/widgets.dart';

class CartScreen extends ConsumerWidget {
  const CartScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lines = ref.watch(cartProvider);

    if (lines.isEmpty) {
      return FrPage(
        title: tr('Your cart'),
        children: [
          const SizedBox(height: 60),
          EmptyState(
            icon: Icons.shopping_bag_outlined,
            title: tr('Your cart is empty'),
            message: tr('Browse the stalls and add something tasty.'),
            action: FilledButton.icon(
              onPressed: () => context.go('/shop'),
              icon: const Icon(Icons.storefront_rounded),
              label: Text(tr('Back to shop')),
            ),
          ),
        ],
      );
    }

    final subtotal = lines.fold(0.0, (s, l) => s + l.lineTotal);
    final cart = ref.read(cartProvider.notifier);

    return FrPage(
      title: tr('Your cart'),
      subtitle: tr('Review your order before checkout.'),
      children: [
        PremiumCard(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            children: [
              for (var i = 0; i < lines.length; i++) ...[
                if (i > 0)
                  Divider(height: 1, indent: 20, endIndent: 20),
                _CartLineTile(
                  line: lines[i],
                  atLimit: cart.atLimit(lines[i]),
                  onMinus: () => cart.setQty(lines[i].key, lines[i].qty - 1),
                  onPlus: () => cart.setQty(lines[i].key, lines[i].qty + 1),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),
        PremiumCard(
          gradient: FrGradients.hero,
          child: Row(
            children: [
              TextButton.icon(
                onPressed: () {
                  cart.clear();
                  showSnack(context, tr('Cart cleared'));
                },
                icon: const Icon(Icons.delete_outline_rounded, size: 18),
                label: Text(tr('Clear cart')),
              ),
              const Spacer(),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(tr('Subtotal'),
                      style: TextStyle(
                          color: FrColors.muted,
                          fontWeight: FontWeight.w600,
                          fontSize: 13)),
                  AnimatedNumber(
                    value: subtotal,
                    format: (v) => peso(v.roundToDouble()),
                    style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -1),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        GradientButton(
          onPressed: () => context.go('/checkout'),
          icon: Icons.arrow_forward_rounded,
          label: tr('Proceed to checkout'),
        ),
        const SizedBox(height: 32),
      ],
    );
  }
}

class _CartLineTile extends StatelessWidget {
  final CartLine line;
  final bool atLimit;
  final VoidCallback onMinus;
  final VoidCallback onPlus;

  const _CartLineTile({
    required this.line,
    required this.atLimit,
    required this.onMinus,
    required this.onPlus,
  });

  @override
  Widget build(BuildContext context) {
    final name = line.product.name;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              gradient: FrGradients.sunset,
              borderRadius: BorderRadius.circular(FrRadius.md),
              boxShadow: [
                BoxShadow(
                  color: FrColors.primary.withValues(alpha: 0.25),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Text(name.isEmpty ? '?' : name[0].toUpperCase(),
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 20)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(line.label,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontWeight: FontWeight.w800, fontSize: 15)),
                const SizedBox(height: 2),
                Text('${peso(line.unitPrice)} each',
                    style: TextStyle(color: FrColors.muted, fontSize: 12.5)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Stepper pill.
          Container(
            decoration: BoxDecoration(
              color: FrColors.surfaceAlt,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.remove_rounded, size: 18),
                  onPressed: onMinus,
                ),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 220),
                  transitionBuilder: (c, a) => ScaleTransition(
                      scale: a, child: FadeTransition(opacity: a, child: c)),
                  child: Text('${line.qty}',
                      key: ValueKey(line.qty),
                      style: const TextStyle(
                          fontWeight: FontWeight.w900, fontSize: 15)),
                ),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.add_rounded, size: 18),
                  tooltip: atLimit
                      ? 'Max ${CartController.maxQtyFor(line.product)} per order'
                      : 'Add one',
                  onPressed: atLimit ? null : onPlus,
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 70,
            child: Text(
              peso(line.lineTotal),
              textAlign: TextAlign.end,
              style:
                  const TextStyle(fontWeight: FontWeight.w900, fontSize: 15.5),
            ),
          ),
        ],
      ),
    );
  }
}
