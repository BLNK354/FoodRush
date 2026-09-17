import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme.dart';
import '../../models/user.dart';
import '../../providers/repository.dart';
import '../../shared/widgets.dart';

class ShopScreen extends ConsumerStatefulWidget {
  const ShopScreen({super.key});

  @override
  ConsumerState<ShopScreen> createState() => _ShopScreenState();
}

class _ShopScreenState extends ConsumerState<ShopScreen> {
  Future<List<Vendor>>? _future;
  List<Vendor> _all = [];
  List<Vendor> _filtered = [];
  Set<String> _favorites = {};
  String _query = '';

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    setState(() {
      _future = Repository.instance.listApprovedVendors();
    });
    final favs = await Repository.instance.listMyFavoriteVendorIds();
    if (!mounted) return;
    setState(() => _favorites = favs.toSet());
    final stalls = await _future!;
    if (!mounted) return;
    setState(() {
      _all = stalls;
      _applyFilter();
    });
  }

  void _applyFilter() {
    setState(() {
      _filtered = _all
          .where((v) =>
              _query.isEmpty ||
              v.name.toLowerCase().contains(_query) ||
              (v.description ?? '').toLowerCase().contains(_query))
          .toList()
        ..sort((a, b) {
          // Open stalls first, then favorites, then alphabetical.
          final open = (b.isOpen ? 1 : 0).compareTo(a.isOpen ? 1 : 0);
          if (open != 0) return open;
          final fav = (_favorites.contains(b.id) ? 1 : 0)
              .compareTo(_favorites.contains(a.id) ? 1 : 0);
          if (fav != 0) return fav;
          return a.name.toLowerCase().compareTo(b.name.toLowerCase());
        });
    });
  }

  Future<void> _toggleFav(Vendor v) async {
    final isFav = _favorites.contains(v.id);
    setState(() {
      isFav ? _favorites.remove(v.id) : _favorites.add(v.id);
    });
    _applyFilter();
    try {
      await Repository.instance.toggleFavorite(v.id, !isFav);
    } catch (e) {
      if (mounted) showSnack(context, 'Could not update favorites: $e', error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FrPage(
      title: 'Shop',
      subtitle: 'Stalls on campus — order ahead, pick up when it\'s ready.',
      children: [
        TextField(
          decoration: const InputDecoration(
            hintText: 'Search stalls or food…',
            prefixIcon: Icon(Icons.search),
          ),
          onChanged: (v) {
            _query = v.trim().toLowerCase();
            _applyFilter();
          },
        ),
        const SizedBox(height: 20),
        FutureBuilder<List<Vendor>>(
          future: _future,
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting && _all.isEmpty) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(48),
                  child: CircularProgressIndicator(),
                ),
              );
            }
            if (snap.hasError) {
              return EmptyState(
                icon: Icons.error_outline,
                title: 'Could not load stalls',
                message: '${snap.error}',
                action: FilledButton(onPressed: _reload, child: const Text('Retry')),
              );
            }
            if (_filtered.isEmpty) {
              return EmptyState(
                icon: Icons.storefront_outlined,
                title: _query.isEmpty ? 'No stalls yet' : 'No stalls match "$_query"',
                message: 'Check back soon — new stalls are added as they are verified.',
              );
            }
            return LayoutBuilder(builder: (context, c) {
              final cols = c.maxWidth > 900 ? 3 : (c.maxWidth > 560 ? 2 : 1);
              return GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: cols,
                  mainAxisSpacing: 16,
                  crossAxisSpacing: 16,
                  childAspectRatio: cols == 1 ? 2.4 : 2.0,
                ),
                itemCount: _filtered.length,
                itemBuilder: (context, i) => _StallCard(
                  vendor: _filtered[i],
                  isFavorite: _favorites.contains(_filtered[i].id),
                  onFavorite: () => _toggleFav(_filtered[i]),
                ),
              );
            });
          },
        ),
        const SizedBox(height: 32),
      ],
    );
  }
}

class _StallCard extends StatelessWidget {
  final Vendor vendor;
  final bool isFavorite;
  final VoidCallback onFavorite;

  const _StallCard({
    required this.vendor,
    required this.isFavorite,
    required this.onFavorite,
  });

  @override
  Widget build(BuildContext context) {
    final closed = !vendor.isOpen;
    return Card(
      child: InkWell(
        onTap: () => context.go('/stall/${vendor.id}'),
        borderRadius: BorderRadius.circular(FrRadius.lg),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Logo
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: FrColors.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(FrRadius.md),
                ),
                clipBehavior: Clip.antiAlias,
                child: vendor.logoUrl != null
                    ? FrImage(vendor.logoUrl, fit: BoxFit.cover)
                    : const Icon(Icons.storefront, color: FrColors.primary),
              ),
              const SizedBox(width: 14),
              // Text
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            vendor.name,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontWeight: FontWeight.w800, fontSize: 15.5),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: (closed ? FrColors.muted : FrColors.success)
                                .withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(FrRadius.sm),
                          ),
                          child: Text(
                            closed ? 'Closed' : 'Open',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: closed ? FrColors.muted : FrColors.success,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (vendor.description != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        vendor.description!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: FrColors.muted, fontSize: 13),
                      ),
                    ],
                    if (vendor.pickupPoint != null) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.place, size: 14, color: FrColors.muted),
                          const SizedBox(width: 3),
                          Flexible(
                            child: Text(
                              vendor.pickupPoint!,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  color: FrColors.muted, fontSize: 12.5),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              IconButton(
                icon: Icon(
                  isFavorite ? Icons.favorite : Icons.favorite_border,
                  color: isFavorite ? FrColors.primary : FrColors.muted,
                ),
                onPressed: onFavorite,
                tooltip: isFavorite ? 'Remove favorite' : 'Add favorite',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
