import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/i18n.dart';
import '../../core/theme.dart';
import '../../models/misc.dart';
import '../../models/product.dart';
import '../../core/constants.dart';
import '../../models/user.dart';
import '../../providers/auth_controller.dart';
import '../../providers/cart_provider.dart';
import '../../providers/repository.dart';
import '../../shared/validation.dart';
import '../../shared/premium.dart';
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
  int? _myStamps; // null = stall has no stamp card (or not loaded)
  String _query = '';

  /// Menu sections narrowed by the search box (empty sections dropped).
  /// Only show products carrying ALL of these tags (e.g. halal + spicy).
  final Set<String> _tagFilter = {};

  Map<String, List<Product>> get _visibleSections {
    if (_query.isEmpty && _tagFilter.isEmpty) return _byCategory;
    bool hit(Product p) =>
        _tagFilter.every(p.tags.contains) &&
        (p.name.toLowerCase().contains(_query) ||
            (p.description ?? '').toLowerCase().contains(_query));
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
      final products = await Repository.instance.listProducts(widget.vendorId);
      final cats = await Repository.instance.listCategories(widget.vendorId);
      // Extras: the page still works if either fails.
      final reviews = await Repository.instance
          .listVendorReviews(widget.vendorId)
          .catchError((Object _) => <Review>[]);
      final ahead = await Repository.instance
          .ordersAhead(widget.vendorId)
          .then<int?>((n) => n, onError: (Object _) => null);
      final stamps =
          vendor?.hasLoyalty == true &&
              ref.read(authControllerProvider).role == kRoleCustomer
          ? await Repository.instance
                .getLoyaltyCard(widget.vendorId)
                .then<int?>((c) => c?.stamps ?? 0, onError: (Object _) => null)
          : null;
      if (!mounted) return;
      setState(() {
        _vendor = vendor;
        _reviews = reviews;
        _ordersAhead = ahead;
        _myStamps = stamps;
        _products = products.where((p) => p.isAvailable).toList();
        _byCategory = {};
        for (final c in cats) {
          _byCategory[c.name] = _products
              .where((p) => p.categoryId == c.id)
              .toList();
        }
        final uncategorized = _products
            .where((p) => p.categoryId == null)
            .toList();
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
    final role = ref.read(authControllerProvider).role;
    if (role != kRoleCustomer) {
      showSnack(
        context,
        'Only student accounts can order. You\'re signed in as '
        '${role == kRoleAdmin ? 'an admin' : 'a stall owner'}. Use a student '
        'account to place orders.',
        error: true,
      );
      return;
    }
    if (_vendor?.isOpenNow != true) {
      showSnack(context, tr('This stall is currently closed.'), error: true);
      return;
    }
    final cart = ref.read(cartProvider.notifier);
    var addons = const <Addon>[];
    var qty = 1;
    if (p.addons.isNotEmpty) {
      final room = CartController.maxQtyFor(p) - cart.qtyOfProduct(p.id);
      if (room <= 0) {
        showSnack(
          context,
          'You can order up to ${CartController.maxQtyFor(p)} of ${p.name}.',
          error: true,
        );
        return;
      }
      final picked = await showModalBottomSheet<(List<Addon>, int)>(
        context: context,
        isScrollControlled: true,
        builder: (_) => _AddonPicker(product: p, maxQty: room),
      );
      if (picked == null || !mounted) return;
      (addons, qty) = picked;
    }
    final err = cart.add(p, qty: qty, addons: addons);
    if (!mounted) return;
    if (err != null) {
      showSnack(context, err, error: true);
      return;
    }
    showSnack(context, tr('{name} added to cart', {'name': p.name}));
  }

  @override
  Widget build(BuildContext context) {
    final cartCount = ref.watch(cartProvider).fold(0, (s, l) => s + l.qty);

    Widget body;
    if (_loading) {
      body = const Center(
        child: Padding(
          padding: EdgeInsets.all(48),
          child: CircularProgressIndicator(),
        ),
      );
    } else if (_error != null) {
      body = EmptyState(
        icon: Icons.error_outline,
        title: 'Could not load this stall',
        message: _error,
        action: FilledButton(onPressed: _load, child: Text(tr('Retry'))),
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
      floatingActionButton: AnimatedSwitcher(
        duration: const Duration(milliseconds: 350),
        transitionBuilder: (c, a) => ScaleTransition(
          scale: CurvedAnimation(parent: a, curve: Curves.easeOutBack),
          child: c,
        ),
        child: cartCount > 0
            ? GradientButton(
                key: const ValueKey('cart'),
                expand: false,
                height: 56,
                icon: Icons.shopping_bag_outlined,
                label: tr('Cart · {n}', {'n': cartCount}),
                onPressed: () => context.go('/cart'),
              )
            : const SizedBox.shrink(),
      ),
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
              FadeSlideIn(
                child: PremiumCard(
                  gradient: FrGradients.hero,
                  padding: const EdgeInsets.all(22),
                  child: Row(
                    children: [
                      Container(
                        width: 84,
                        height: 84,
                        decoration: BoxDecoration(
                          gradient: v.logoUrl == null
                              ? FrGradients.sunset
                              : null,
                          borderRadius: BorderRadius.circular(FrRadius.xl),
                          boxShadow: [
                            BoxShadow(
                              color: FrColors.primary.withValues(alpha: 0.3),
                              blurRadius: 20,
                              offset: const Offset(0, 9),
                            ),
                          ],
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: v.logoUrl != null
                            ? FrImage(v.logoUrl)
                            : const Icon(
                                Icons.storefront_rounded,
                                color: Colors.white,
                                size: 40,
                              ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    v.name,
                                    style: const TextStyle(
                                      fontSize: 26,
                                      letterSpacing: -0.9,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                StatusChip(
                                  v.isOpenNow ? tr('Open') : tr('Closed'),
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
                                  size: 14,
                                ),
                                if (hours != null) _Meta(Icons.schedule, hours),
                                if (v.isOpenNow && _ordersAhead != null)
                                  _Meta(
                                    Icons.timer_outlined,
                                    waitLabel(v, _ordersAhead!),
                                  ),
                              ],
                            ),
                            if (v.description != null) ...[
                              const SizedBox(height: 4),
                              Text(
                                v.description!,
                                style: TextStyle(
                                  color: FrColors.muted,
                                  fontSize: 13.5,
                                ),
                              ),
                            ],
                            if (v.pickupPoint != null) ...[
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  Icon(
                                    Icons.place,
                                    size: 15,
                                    color: FrColors.muted,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    tr('Pickup: {place}', {
                                      'place': v.pickupPoint,
                                    }),
                                    style: TextStyle(
                                      color: FrColors.muted,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                      IconButton.filledTonal(
                        style: IconButton.styleFrom(
                          backgroundColor: FrColors.surface,
                        ),
                        onPressed: () => context.go('/shop'),
                        icon: const Icon(Icons.close_rounded),
                        tooltip: tr('Back to shop'),
                      ),
                    ],
                  ),
                ),
              ),
              if (_myStamps != null) ...[
                const SizedBox(height: 12),
                _StampCard(stall: v, stamps: _myStamps!),
              ],
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
                  inputFormatters: [
                    LengthLimitingTextInputFormatter(Limits.search),
                  ],
                  decoration: InputDecoration(
                    hintText: tr('Search this menu…'),
                    prefixIcon: Icon(Icons.search),
                  ),
                  onChanged: (v) =>
                      setState(() => _query = v.trim().toLowerCase()),
                ),
                const SizedBox(height: 20),
              ],
              if (_products.any((p) => p.tags.isNotEmpty)) ...[
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final t in kProductTags)
                      if (_products.any((p) => p.tags.contains(t)))
                        FilterChip(
                          avatar: Icon(tagIcon(t), size: 16),
                          label: Text(tagLabel(t)),
                          selected: _tagFilter.contains(t),
                          onSelected: (on) => setState(
                            () => on ? _tagFilter.add(t) : _tagFilter.remove(t),
                          ),
                        ),
                  ],
                ),
                const SizedBox(height: 16),
              ],
              if ((_query.isNotEmpty || _tagFilter.isNotEmpty) &&
                  _visibleSections.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Text(
                    _query.isEmpty
                        ? 'Nothing on this menu has those tags.'
                        : 'Nothing on this menu matches "$_query".',
                    style: TextStyle(color: FrColors.muted),
                  ),
                ),

              // Sections by category
              for (final entry in _visibleSections.entries) ...[
                SectionHeader(entry.key),
                if (entry.value.isEmpty)
                  Padding(
                    padding: EdgeInsets.only(bottom: 16),
                    child: Text(
                      tr('Nothing here yet.'),
                      style: TextStyle(color: FrColors.muted),
                    ),
                  )
                else
                  LayoutBuilder(
                    builder: (context, c) {
                      final cols = c.maxWidth > 900
                          ? 3
                          : (c.maxWidth > 560 ? 2 : 1);
                      return GridView.builder(
                        shrinkWrap: true,
                        clipBehavior: Clip.none,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: cols,
                          mainAxisSpacing: 14,
                          crossAxisSpacing: 14,
                          // Fixed height: an aspect ratio left narrow tiles too
                          // short for name + 2-line description + stock + button.
                          mainAxisExtent: 176,
                        ),
                        itemCount: entry.value.length,
                        itemBuilder: (context, i) => FadeSlideIn(
                          key: ValueKey(entry.value[i].id),
                          index: i,
                          child: _ProductCard(
                            product: entry.value[i],
                            stallOpen: v.isOpenNow,
                            onAdd: () => _addToCart(entry.value[i]),
                          ),
                        ),
                      );
                    },
                  ),
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

/// The student's stamp card at this stall.
class _StampCard extends StatelessWidget {
  final Vendor stall;
  final int stamps;
  const _StampCard({required this.stall, required this.stamps});

  @override
  Widget build(BuildContext context) {
    final need = stall.loyaltyStamps;
    final full = stamps >= need;
    return PremiumCard(
      padding: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.loyalty_rounded, color: FrColors.secondary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    full
                        ? tr('Card full! Ask for {reward} at pickup.', {
                            'reward': stall.loyaltyReward,
                          })
                        : tr(
                            '{have}/{need} stamps · {left} more for {reward}',
                            {
                              'have': stamps,
                              'need': need,
                              'left': need - stamps,
                              'reward': stall.loyaltyReward,
                            },
                          ),
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (var i = 0; i < need; i++)
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: 1),
                    duration: Duration(milliseconds: 300 + 60 * i),
                    curve: Curves.easeOutBack,
                    builder: (context, s, child) =>
                        Transform.scale(scale: s, child: child),
                    child: Container(
                      width: 26,
                      height: 26,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: i < stamps ? FrGradients.sunset : null,
                        color: i < stamps ? null : FrColors.surfaceAlt,
                        border: i < stamps
                            ? null
                            : Border.all(color: FrColors.line),
                        boxShadow: i < stamps
                            ? [
                                BoxShadow(
                                  color: FrColors.secondary.withValues(
                                    alpha: 0.35,
                                  ),
                                  blurRadius: 8,
                                  offset: const Offset(0, 3),
                                ),
                              ]
                            : null,
                      ),
                      child: i < stamps
                          ? const Icon(
                              Icons.check_rounded,
                              size: 15,
                              color: Colors.white,
                            )
                          : null,
                    ),
                  ),
              ],
            ),
          ],
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
      Text(text, style: TextStyle(color: FrColors.muted, fontSize: 13)),
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
        SectionHeader(tr('Reviews')),
        if (reviews.isEmpty)
          Padding(
            padding: EdgeInsets.only(bottom: 16),
            child: Text(
              tr('No reviews yet. Students can rate a stall after picking up.'),
              style: TextStyle(color: FrColors.muted),
            ),
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
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                          ),
                        ),
                        if (r.createdAt != null)
                          Text(
                            '${r.createdAt!.month}/${r.createdAt!.day}/${r.createdAt!.year}',
                            style: TextStyle(
                              color: FrColors.muted,
                              fontSize: 12,
                            ),
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
                        child: Text(
                          'Reply from ${vendor.name}: ${r.reply}',
                          style: const TextStyle(fontSize: 13),
                        ),
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

/// Bottom sheet to choose add-ons and quantity; pops with (addons, qty).
class _AddonPicker extends StatefulWidget {
  final Product product;
  final int maxQty;
  const _AddonPicker({required this.product, required this.maxQty});

  @override
  State<_AddonPicker> createState() => _AddonPickerState();
}

class _AddonPickerState extends State<_AddonPicker> {
  final _chosen = <Addon>{};
  int _qty = 1;

  double get _unit =>
      widget.product.price + _chosen.fold(0.0, (s, a) => s + a.price);

  @override
  Widget build(BuildContext context) {
    final p = widget.product;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              p.name,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            Text(
              '${peso(p.price)} · pick any extras',
              style: TextStyle(color: FrColors.muted),
            ),
            const SizedBox(height: 8),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final a in p.addons)
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      value: _chosen.contains(a),
                      onChanged: (on) => setState(
                        () => on == true ? _chosen.add(a) : _chosen.remove(a),
                      ),
                      title: Text(a.name),
                      secondary: Text(
                        a.price == 0 ? 'Free' : '+${peso(a.price)}',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                IconButton(
                  tooltip: 'One less',
                  onPressed: _qty > 1 ? () => setState(() => _qty--) : null,
                  icon: const Icon(Icons.remove_circle_outline),
                ),
                Text(
                  '$_qty',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                IconButton(
                  tooltip: 'One more',
                  onPressed: _qty < widget.maxQty
                      ? () => setState(() => _qty++)
                      : null,
                  icon: const Icon(Icons.add_circle_outline),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton(
                    onPressed: () => Navigator.pop(context, (
                      [
                        for (final a in p.addons)
                          if (_chosen.contains(a)) a,
                      ],
                      _qty,
                    )),
                    child: Text('Add · ${peso(_unit * _qty)}'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
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
    return TiltCard(
      maxTilt: 0.07,
      child: Padding(
        padding: const EdgeInsets.all(16),
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
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                product.name,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 15,
                                ),
                              ),
                            ),
                            for (final t in product.tags)
                              Padding(
                                padding: const EdgeInsets.only(left: 4),
                                child: Tooltip(
                                  message: tagLabel(t),
                                  child: Icon(
                                    tagIcon(t),
                                    size: 15,
                                    color: t == 'spicy'
                                        ? FrColors.danger
                                        : t == 'bestseller'
                                        ? FrColors.warning
                                        : FrColors.success,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        if (product.description != null) ...[
                          const SizedBox(height: 3),
                          Text(
                            product.description!,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: FrColors.muted,
                              fontSize: 12.5,
                            ),
                          ),
                        ],
                        if (product.stockQty != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              product.stockQty! <= 5
                                  ? tr('Only {n} left!', {
                                      'n': product.stockQty,
                                    })
                                  : tr('{n} in stock', {'n': product.stockQty}),
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
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      gradient: product.imageUrl == null
                          ? LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                FrColors.secondary.withValues(alpha: 0.18),
                                FrColors.primary.withValues(alpha: 0.12),
                              ],
                            )
                          : null,
                      borderRadius: BorderRadius.circular(FrRadius.lg),
                      boxShadow: product.imageUrl == null
                          ? null
                          : [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.12),
                                blurRadius: 12,
                                offset: const Offset(0, 5),
                              ),
                            ],
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: product.imageUrl != null
                        ? FrImage(product.imageUrl)
                        : Icon(Icons.fastfood, color: FrColors.secondary),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Text(
                  peso(product.price),
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                    color: FrColors.primary,
                  ),
                ),
                if (product.addons.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(left: 6),
                    child: Text(
                      tr('+ extras'),
                      style: TextStyle(color: FrColors.muted, fontSize: 11.5),
                    ),
                  ),
                const Spacer(),
                GradientButton(
                  expand: false,
                  height: 40,
                  icon: Icons.add_rounded,
                  label: tr('Add'),
                  onPressed: stallOpen ? onAdd : null,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
