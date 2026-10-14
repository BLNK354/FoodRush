import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme.dart';
import '../../models/misc.dart';
import '../../models/product.dart';
import '../../models/user.dart';
import '../../providers/cart_provider.dart';
import '../../providers/repository.dart';
import '../../shared/widgets.dart';

class StallMenuScreen extends ConsumerStatefulWidget {
  final String vendorId;
  const StallMenuScreen({super.key, required this.vendorId});

  @override
  ConsumerState<StallMenuScreen> createState() => _StallMenuScreenState();
}

class _StallMenuScreenState extends ConsumerState<StallMenuScreen> {
  Vendor? _vendor;
  List<Product> _products = [];
  Map<String, List<Product>> _byCategory = {};
  bool _loading = true;
  String? _error;
  List<Review> _reviews = [];
  int? _ordersAhead;
  String _query = '';

  /// Menu sections narrowed by the search box (empty sections dropped).
  Map<String, List<Product>> get _visibleSections {
    if (_query.isEmpty) return _byCategory;
    bool hit(Product p) =>
        p.name.toLowerCase().contains(_query) ||
        (p.description ?? '').toLowerCase().contains(_query);
    return {
      for (final e in _byCategory.entries)
        if (e.value.any(hit)) e.key: e.value.where(hit).toList(),
    };
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final vendor = await Repository.instance.getVendor(widget.vendorId);
      final products =
          await Repository.instance.listProducts(widget.vendorId);
      final cats = await Repository.instance.listCategories(widget.vendorId);
      // Extras: the page still works if either fails.
      final reviews = await Repository.instance
          .listVendorReviews(widget.vendorId)
          .catchError((Object _) => <Review>[]);
      final ahead = await Repository.instance
          .ordersAhead(widget.vendorId)
          .then<int?>((n) => n, onError: (Object _) => null);
      if (!mounted) return;
      setState(() {
        _vendor = vendor;
        _reviews = reviews;
        _ordersAhead = ahead;
        _products = products.where((p) => p.isAvailable).toList();
        _byCategory = {};
        for (final c in cats) {
          _byCategory[c.name] =
              _products.where((p) => p.categoryId == c.id).toList();
        }
        final uncategorized =
            _products.where((p) => p.categoryId == null).toList();
        if (uncategorized.isNotEmpty) _byCategory['Menu'] = uncategorized;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = '$e';
      });
    }
  }

  Future<void> _addToCart(Product p) async {
    if (_vendor?.isOpenNow != true) {
      showSnack(context, 'This stall is currently closed.', error: true);
      return;
    }
    final err = ref.read(cartProvider.notifier).add(p);
    if (!mounted) return;
    if (err != null) {
      showSnack(context, err, error: true);
      return;
    }
    showSnack(context, '${p.name} added to cart');
  }

  @override
  Widget build(BuildContext context) {
    final cartCount = ref.watch(cartProvider).fold(0, (s, l) => s + l.qty);

    Widget body;
    if (_loading) {
      body = const Center(child: Padding(
        padding: EdgeInsets.all(48), child: CircularProgressIndicator()));
    } else if (_error != null) {
      body = EmptyState(
        icon: Icons.error_outline,
        title: 'Could not load this stall',
        message: _error,
        action: FilledButton(onPressed: _load, child: const Text('Retry')),
      );
    } else if (_vendor == null) {
      body = const EmptyState(
        icon: Icons.storefront_outlined,
        title: 'Stall not found',
      );
    } else {
      body = _buildMenu(context);
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: cartCount > 0
          ? FloatingActionButton.extended(
              backgroundColor: FrColors.primary,
              foregroundColor: Colors.white,
              onPressed: () => context.go('/cart'),
              icon: const Icon(Icons.shopping_cart),
              label: Text('Cart · $cartCount'),
            )
          : null,
      body: body,
    );
  }

  Widget _buildMenu(BuildContext context) {
    final v = _vendor!;
    final hours = v.hoursLabel(DateTime.now());
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1100),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          color: FrColors.primary.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(FrRadius.lg),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: v.logoUrl != null
                            ? FrImage(v.logoUrl)
                            : const Icon(Icons.storefront,
                                color: FrColors.primary, size: 36),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(v.name,
                                      style: const TextStyle(
                                          fontSize: 22,
                                          fontWeight: FontWeight.w900)),
                                ),
                                const SizedBox(width: 10),
                                StatusChip(
                                  v.isOpenNow ? 'Open' : 'Closed',
                                  color: v.isOpenNow
                                      ? FrColors.success
                                      : FrColors.muted,
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Wrap(
                              spacing: 14,
                              runSpacing: 4,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                RatingBadge(
                                    rating: v.rating,
                                    count: v.ratingCount,
                                    size: 14),
                                if (hours != null)
                                  _Meta(Icons.schedule, hours),
                                if (v.isOpenNow && _ordersAhead != null)
                                  _Meta(Icons.timer_outlined,
                                      waitLabel(v, _ordersAhead!)),
                              ],
                            ),
                            if (v.description != null) ...[
                              const SizedBox(height: 4),
                              Text(v.description!,
                                  style: TextStyle(
                                      color: FrColors.muted, fontSize: 13.5)),
                            ],
                            if (v.pickupPoint != null) ...[
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  Icon(Icons.place,
                                      size: 15, color: FrColors.muted),
                                  const SizedBox(width: 4),
                                  Text('Pickup: ${v.pickupPoint}',
                                      style: TextStyle(
                                          color: FrColors.muted,
                                          fontSize: 13)),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => context.go('/shop'),
                        icon: const Icon(Icons.close),
                        tooltip: 'Back to shop',
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              if (!v.isOpenNow)
                Container(
                  padding: const EdgeInsets.all(14),
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: FrColors.warning.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(FrRadius.md),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.schedule, color: FrColors.warning),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'This stall is closed right now. You can browse '
                          'the menu but cannot order.'
                          '${hours == null ? '' : ' $hours.'}',
                        ),
                      ),
                    ],
                  ),
                ),

              if (_products.length > 4) ...[
                TextField(
                  decoration: const InputDecoration(
                    hintText: 'Search this menu…',
                    prefixIcon: Icon(Icons.search),
                  ),
                  onChanged: (v) =>
                      setState(() => _query = v.trim().toLowerCase()),
                ),
                const SizedBox(height: 20),
              ],
              if (_query.isNotEmpty && _visibleSections.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Text('Nothing on this menu matches "$_query".',
                      style: TextStyle(color: FrColors.muted)),
                ),

              // Sections by category
              for (final entry in _visibleSections.entries) ...[
                SectionHeader(entry.key),
                if (entry.value.isEmpty)
                  Padding(
                    padding: EdgeInsets.only(bottom: 16),
                    child: Text('Nothing here yet.',
                        style: TextStyle(color: FrColors.muted)),
                  )
                else
                  LayoutBuilder(builder: (context, c) {
                    final cols = c.maxWidth > 900
                        ? 3
                        : (c.maxWidth > 560 ? 2 : 1);
                    return GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate:
                          SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: cols,
                        mainAxisSpacing: 14,
                        crossAxisSpacing: 14,
                        childAspectRatio: cols == 1 ? 3.2 : 2.6,
                      ),
                      itemCount: entry.value.length,
                      itemBuilder: (context, i) =>
                          _ProductCard(
                        product: entry.value[i],
                        stallOpen: v.isOpenNow,
                        onAdd: () => _addToCart(entry.value[i]),
                      ),
                    );
                  }),
                const SizedBox(height: 12),
              ],
              const SizedBox(height: 12),
              _ReviewsSection(vendor: v, reviews: _reviews),
              const SizedBox(height: 64),
            ],
          ),
        ),
      ),
    );
  }
}

/// Icon + muted text, for the stall header's meta row.
class _Meta extends StatelessWidget {
  final IconData icon;
  final String text;
  const _Meta(this.icon, this.text);

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: FrColors.muted),
          const SizedBox(width: 4),
          Text(text,
              style: TextStyle(color: FrColors.muted, fontSize: 13)),
        ],
      );
}

class _ReviewsSection extends StatelessWidget {
  final Vendor vendor;
  final List<Review> reviews;
  const _ReviewsSection({required this.vendor, required this.reviews});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader('Reviews'),
        if (reviews.isEmpty)
          Padding(
            padding: EdgeInsets.only(bottom: 16),
            child: Text(
                'No reviews yet. Students can rate a stall after picking up.',
                style: TextStyle(color: FrColors.muted)),
          )
        else
          for (final r in reviews)
            Card(
              margin: const EdgeInsets.only(bottom: 10),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        for (var i = 1; i <= 5; i++)
                          Icon(
                            i <= r.rating
                                ? Icons.star_rounded
                                : Icons.star_outline_rounded,
                            size: 18,
                            color: FrColors.warning,
                          ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _reviewer(r),
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontWeight: FontWeight.w700, fontSize: 13),
                          ),
                        ),
                        if (r.createdAt != null)
                          Text(
                            '${r.createdAt!.month}/${r.createdAt!.day}/${r.createdAt!.year}',
                            style: TextStyle(
                                color: FrColors.muted, fontSize: 12),
                          ),
                      ],
                    ),
                    if (r.comment != null) ...[
                      const SizedBox(height: 6),
                      Text(r.comment!),
                    ],
                    if (r.reply != null) ...[
                      const SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: FrColors.muted.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(FrRadius.sm),
                        ),
                        child: Text('Reply from ${vendor.name}: ${r.reply}',
                            style: const TextStyle(fontSize: 13)),
                      ),
                    ],
                  ],
                ),
              ),
            ),
      ],
    );
  }

  /// First name + last initial: enough to feel real, not a full identity.
  static String _reviewer(Review r) {
    final parts = (r.customerName ?? '').trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return 'Student';
    if (parts.length == 1) return parts.first;
    return '${parts.first} ${parts.last[0]}.';
  }
}

class _ProductCard extends StatelessWidget {
  final Product product;
  final bool stallOpen;
  final VoidCallback onAdd;

  const _ProductCard({
    required this.product,
    required this.stallOpen,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(product.name,
                            style: const TextStyle(
                                fontWeight: FontWeight.w800, fontSize: 15)),
                        if (product.description != null) ...[
                          const SizedBox(height: 3),
                          Text(
                            product.description!,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                color: FrColors.muted, fontSize: 12.5),
                          ),
                        ],
                        if (product.stockQty != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              product.stockQty! <= 5
                                  ? 'Only ${product.stockQty} left!'
                                  : '${product.stockQty} in stock',
                              style: TextStyle(
                                fontSize: 11.5,
                                color: product.stockQty! <= 5
                                    ? FrColors.danger
                                    : FrColors.muted,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: FrColors.cream,
                      borderRadius: BorderRadius.circular(FrRadius.md),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: product.imageUrl != null
                        ? FrImage(product.imageUrl)
                        : const Icon(Icons.fastfood,
                            color: FrColors.secondary),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Text(peso(product.price),
                    style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                        color: FrColors.primary)),
                const Spacer(),
                FilledButton.tonal(
                  onPressed: stallOpen ? onAdd : null,
                  style: FilledButton.styleFrom(
                    backgroundColor: FrColors.primary,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(0, 38),
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                  ),
                  child: const Text('Add',
                      style: TextStyle(fontWeight: FontWeight.w800)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
