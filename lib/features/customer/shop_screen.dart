import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/i18n.dart';
import '../../core/theme.dart';
import '../../models/misc.dart';
import '../../models/user.dart';
import '../../providers/auth_controller.dart';
import '../../providers/repository.dart';
import '../../shared/validation.dart';
import '../../shared/home_banners.dart';
import '../../shared/install_app_card.dart';
import '../../shared/premium.dart';
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
  final _homeContent = Repository.instance.streamHomeContent();

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
      _filtered =
          _all
              .where(
                (v) =>
                    _query.isEmpty ||
                    v.name.toLowerCase().contains(_query) ||
                    (v.description ?? '').toLowerCase().contains(_query),
              )
              .toList()
            ..sort((a, b) {
              // Open stalls first, then favorites, then alphabetical.
              final open = (b.isOpenNow ? 1 : 0).compareTo(a.isOpenNow ? 1 : 0);
              if (open != 0) return open;
              final fav = (_favorites.contains(b.id) ? 1 : 0).compareTo(
                _favorites.contains(a.id) ? 1 : 0,
              );
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
      if (mounted) {
        showSnack(context, 'Could not update favorites: $e', error: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = ref.watch(
      authControllerProvider.select((a) => a.profile?.fullName ?? ''),
    );
    final first = name.trim().split(' ').first;
    final openCount = _all.where((v) => v.isOpenNow).length;
    return FrPage(
      title: tr('Shop'),
      showHeader: false,
      children: [
        StreamBuilder<HomeContent>(
          stream: _homeContent,
          builder: (context, snap) => ShopHero(
            firstName: first,
            openCount: openCount,
            title: snap.data?.heroTitle,
            subtitle: snap.data?.heroSubtitle,
          ),
        ),
        const SizedBox(height: 20),
        const HomeBannerCarousel(),
        const InstallAppCard(),
        DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(FrRadius.lg),
            boxShadow: FrShadows.soft,
          ),
          child: TextField(
            inputFormatters: [LengthLimitingTextInputFormatter(Limits.search)],
            decoration: InputDecoration(
              hintText: tr('Search stalls or food…'),
              prefixIcon: const Icon(Icons.search_rounded),
              fillColor: FrColors.surface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(FrRadius.lg),
                borderSide: BorderSide(color: FrColors.hairline),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(FrRadius.lg),
                borderSide: BorderSide(color: FrColors.hairline),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(FrRadius.lg),
                borderSide: const BorderSide(
                  color: FrColors.primary,
                  width: 1.6,
                ),
              ),
            ),
            onChanged: (v) {
              _query = v.trim().toLowerCase();
              _applyFilter();
            },
          ),
        ),
        const SizedBox(height: 26),
        SectionHeader(
          tr('Stalls on campus'),
          trailing: _all.isEmpty
              ? null
              : Text(
                  '${_filtered.length}',
                  style: TextStyle(
                    color: FrColors.muted,
                    fontWeight: FontWeight.w700,
                  ),
                ),
        ),
        FutureBuilder<List<Vendor>>(
          future: _future,
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting &&
                _all.isEmpty) {
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
                title: tr('Could not load stalls'),
                message: '${snap.error}',
                action: FilledButton(
                  onPressed: _reload,
                  child: Text(tr('Retry')),
                ),
              );
            }
            if (_filtered.isEmpty) {
              return EmptyState(
                icon: Icons.storefront_outlined,
                title: _query.isEmpty
                    ? 'No stalls yet'
                    : 'No stalls match "$_query"',
                message: tr(
                  'Check back soon — new stalls are added as they are verified.',
                ),
              );
            }
            return LayoutBuilder(
              builder: (context, c) {
                final cols = c.maxWidth > 1000 ? 3 : (c.maxWidth > 680 ? 2 : 1);
                return GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  clipBehavior: Clip.none,
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: cols,
                    mainAxisSpacing: 18,
                    crossAxisSpacing: 18,
                    mainAxisExtent: 132,
                  ),
                  itemCount: _filtered.length,
                  itemBuilder: (context, i) => FadeSlideIn(
                    key: ValueKey(_filtered[i].id),
                    index: i,
                    child: _StallCard(
                      vendor: _filtered[i],
                      isFavorite: _favorites.contains(_filtered[i].id),
                      onFavorite: () => _toggleFav(_filtered[i]),
                    ),
                  ),
                );
              },
            );
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
    final closed = !vendor.isOpenNow;
    final hours = vendor.hoursLabel(DateTime.now());
    return TiltCard(
      onTap: () => context.go('/stall/${vendor.id}'),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // Logo: glossy 3D tile.
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                gradient: vendor.logoUrl == null ? FrGradients.sunset : null,
                borderRadius: BorderRadius.circular(FrRadius.lg),
                boxShadow: [
                  BoxShadow(
                    color: FrColors.primary.withValues(
                      alpha: closed ? 0.1 : 0.28,
                    ),
                    blurRadius: 16,
                    offset: const Offset(0, 7),
                  ),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: vendor.logoUrl != null
                  ? FrImage(vendor.logoUrl, fit: BoxFit.cover)
                  : Stack(
                      alignment: Alignment.center,
                      children: [
                        Positioned(
                          top: 0,
                          left: 0,
                          right: 0,
                          height: 36,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.white.withValues(alpha: 0.3),
                                  Colors.white.withValues(alpha: 0),
                                ],
                              ),
                            ),
                          ),
                        ),
                        Text(
                          vendor.name.isEmpty
                              ? '?'
                              : vendor.name[0].toUpperCase(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 30,
                            fontWeight: FontWeight.w900,
                            shadows: [
                              Shadow(
                                color: Color(0x40000000),
                                blurRadius: 6,
                                offset: Offset(0, 2),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
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
                            fontWeight: FontWeight.w800,
                            fontSize: 15.5,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.fromLTRB(2, 2, 9, 2),
                        decoration: BoxDecoration(
                          color: (closed ? FrColors.muted : FrColors.success)
                              .withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            closed
                                ? Padding(
                                    padding: const EdgeInsets.all(6),
                                    child: Container(
                                      width: 6,
                                      height: 6,
                                      decoration: BoxDecoration(
                                        color: FrColors.muted,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                  )
                                : PulseDot(color: FrColors.success, size: 6),
                            Text(
                              closed ? tr('Closed') : tr('Open'),
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: closed
                                    ? FrColors.muted
                                    : FrColors.success,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 10,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      RatingBadge(
                        rating: vendor.rating,
                        count: vendor.ratingCount,
                      ),
                      if (hours != null)
                        Text(
                          hours,
                          style: TextStyle(
                            color: FrColors.muted,
                            fontSize: 12.5,
                          ),
                        ),
                    ],
                  ),
                  if (vendor.description != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      vendor.description!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: FrColors.muted, fontSize: 13),
                    ),
                  ],
                  if (vendor.pickupPoint != null) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.place, size: 14, color: FrColors.muted),
                        const SizedBox(width: 3),
                        Flexible(
                          child: Text(
                            vendor.pickupPoint!,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: FrColors.muted,
                              fontSize: 12.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            IconButton(
              icon: AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                transitionBuilder: (c, a) => ScaleTransition(
                  scale: CurvedAnimation(parent: a, curve: Curves.elasticOut),
                  child: c,
                ),
                child: Icon(
                  isFavorite
                      ? Icons.favorite_rounded
                      : Icons.favorite_border_rounded,
                  key: ValueKey(isFavorite),
                  color: isFavorite ? FrColors.primary : FrColors.muted,
                ),
              ),
              onPressed: onFavorite,
              tooltip: isFavorite ? tr('Remove favorite') : tr('Add favorite'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Warm greeting banner with the floating 3D food scene. [title] and
/// [subtitle] come from the admin's Content page; blank keeps the defaults.
/// Public so the Content page can preview it.
class ShopHero extends StatelessWidget {
  final String firstName;
  final int openCount;
  final String? title;
  final String? subtitle;
  const ShopHero({
    super.key,
    required this.firstName,
    required this.openCount,
    this.title,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final hour = DateTime.now().hour;
    final greeting = hour < 11
        ? tr('Good morning')
        : hour < 15
        ? tr('Lunch time')
        : tr('Good afternoon');
    return LayoutBuilder(
      builder: (context, box) {
        final wide = box.maxWidth > 640;
        final copy = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              firstName.isEmpty ? greeting : '$greeting, $firstName',
              style: TextStyle(
                color: FrColors.primary,
                fontWeight: FontWeight.w800,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              (title ?? '').trim().isNotEmpty
                  ? title!.trim()
                  : tr('Hungry? Skip the line.'),
              style: TextStyle(
                fontSize: wide ? 38 : 30,
                height: 1.05,
                fontWeight: FontWeight.w900,
                letterSpacing: wide ? -1.6 : -1.1,
                color: FrColors.ink,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              (subtitle ?? '').trim().isNotEmpty
                  ? subtitle!.trim()
                  : tr('Stalls on campus — order ahead, pick up when it\'s ready.'),
              style: TextStyle(
                color: FrColors.muted,
                fontSize: 14,
                height: 1.4,
              ),
            ),
            if (openCount > 0) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.fromLTRB(4, 4, 12, 4),
                decoration: BoxDecoration(
                  color: FrColors.surface,
                  borderRadius: BorderRadius.circular(999),
                  boxShadow: FrShadows.soft,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    PulseDot(color: FrColors.success, size: 7),
                    Text(
                      tr('{n} open now', {'n': openCount}),
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 12.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        );
        return Container(
          decoration: BoxDecoration(
            gradient: FrGradients.hero,
            borderRadius: BorderRadius.circular(FrRadius.xl + 6),
            border: Border.all(color: FrColors.hairline),
            boxShadow: FrShadows.soft,
          ),
          clipBehavior: Clip.antiAlias,
          padding: EdgeInsets.fromLTRB(wide ? 32 : 22, 26, wide ? 12 : 22, 26),
          child: wide
              ? Row(
                  children: [
                    Expanded(flex: 6, child: copy),
                    const Expanded(
                      flex: 5,
                      child: FloatingFoodScene(height: 230),
                    ),
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const FloatingFoodScene(height: 150),
                    const SizedBox(height: 8),
                    copy,
                  ],
                ),
        );
      },
    );
  }
}
