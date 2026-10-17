import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/i18n.dart';
import '../core/constants.dart';
import '../core/theme.dart';
import '../providers/auth_controller.dart';
import '../providers/cart_provider.dart';
import 'premium.dart';
import 'responsive.dart';

// ---------------------------------------------------------------------------
// Customer shell — mobile-style bottom nav; desktop shows a slim top bar.
// ---------------------------------------------------------------------------

class _CustomerDest {
  final String path;
  final IconData icon;
  final IconData selectedIcon;
  final String label;
  const _CustomerDest(this.path, this.icon, this.selectedIcon, this.label);
}

const _customerDests = [
  _CustomerDest('/shop', Icons.storefront_outlined, Icons.storefront, 'Shop'),
  _CustomerDest('/orders', Icons.receipt_long_outlined, Icons.receipt_long, 'Orders'),
  _CustomerDest('/cart', Icons.shopping_cart_outlined, Icons.shopping_cart, 'Cart'),
];

class CustomerShell extends ConsumerWidget {
  final Widget child;
  const CustomerShell({super.key, required this.child});

  int _index(String loc) {
    if (loc.startsWith('/stall') || loc.startsWith('/checkout')) return 0;
    final i = _customerDests.indexWhere((d) => loc.startsWith(d.path));
    return i < 0 ? 0 : i;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loc = GoRouterState.of(context).matchedLocation;
    final wide = !FrBreakpoints.isCompact(MediaQuery.sizeOf(context).width);
    final auth = ref.watch(authControllerProvider);
    final cartCount = ref.watch(cartProvider).fold(0, (s, l) => s + l.qty);
    final index = _index(loc);
    final initial = auth.profile?.fullName.isNotEmpty == true
        ? auth.profile!.fullName[0].toUpperCase()
        : '?';

    final appBar = PreferredSize(
      preferredSize: const Size.fromHeight(64),
      child: GlassPanel(
        blur: 20,
        child: SafeArea(
          bottom: false,
          child: SizedBox(
            height: 64,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  const BrandMark(size: 36),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        GradientText(Brand.current.appName,
                            style: const TextStyle(
                                fontSize: 21,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -0.8)),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(kUniversityName,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  color: FrColors.muted,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700)),
                        ),
                      ],
                    ),
                  ),
                  Tooltip(
                    message: tr('My profile'),
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: () => context.go('/profile'),
                      child: Container(
                        width: 38,
                        height: 38,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: FrGradients.sunset,
                        ),
                        child: Text(initial,
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w900)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  IconButton(
                    tooltip: tr('Sign out'),
                    icon: Icon(Icons.logout_rounded, color: FrColors.muted),
                    onPressed: () =>
                        ref.read(authControllerProvider.notifier).signOut(),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    return Scaffold(
      extendBodyBehindAppBar: false,
      extendBody: false,
      appBar: appBar,
      body: Row(
        children: [
          if (wide)
            NavigationRail(
              selectedIndex: index,
              onDestinationSelected: (i) => context.go(_customerDests[i].path),
              labelType: NavigationRailLabelType.all,
              destinations: [
                for (final d in _customerDests)
                  NavigationRailDestination(
                    icon: _CartBadge(
                        show: d.path == '/cart',
                        count: cartCount,
                        child: Icon(d.icon)),
                    selectedIcon: _CartBadge(
                        show: d.path == '/cart',
                        count: cartCount,
                        child: Icon(d.selectedIcon)),
                    label: Text(tr(d.label)),
                  ),
              ],
            ),
          Expanded(child: child),
        ],
      ),
      bottomNavigationBar: wide
          ? null
          : _FloatingNavBar(
              index: index,
              cartCount: cartCount,
              onSelect: (i) => context.go(_customerDests[i].path),
            ),
    );
  }
}

/// Count bubble on the cart icon; pops when the number changes.
class _CartBadge extends StatelessWidget {
  final bool show;
  final int count;
  final Widget child;
  const _CartBadge(
      {required this.show, required this.count, required this.child});

  @override
  Widget build(BuildContext context) {
    if (!show || count == 0) return child;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        child,
        Positioned(
          right: -9,
          top: -7,
          child: TweenAnimationBuilder<double>(
            key: ValueKey(count),
            tween: Tween(begin: 0.4, end: 1),
            duration: const Duration(milliseconds: 420),
            curve: Curves.elasticOut,
            builder: (context, s, child) =>
                Transform.scale(scale: s, child: child),
            child: Container(
              constraints: const BoxConstraints(minWidth: 18),
              height: 18,
              padding: const EdgeInsets.symmetric(horizontal: 5),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                gradient: FrGradients.brand,
                borderRadius: BorderRadius.circular(9),
                border: Border.all(color: FrColors.surface, width: 1.5),
              ),
              child: Text('$count',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w900)),
            ),
          ),
        ),
      ],
    );
  }
}

/// Phone navigation: a floating frosted pill with a sliding gradient
/// indicator under the selected tab.
class _FloatingNavBar extends StatelessWidget {
  final int index;
  final int cartCount;
  final ValueChanged<int> onSelect;
  const _FloatingNavBar(
      {required this.index, required this.cartCount, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      minimum: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(26),
          boxShadow: FrShadows.raised,
        ),
        child: GlassPanel(
          borderRadius: BorderRadius.circular(26),
          padding: const EdgeInsets.all(6),
          child: SizedBox(
            height: 58,
            child: LayoutBuilder(builder: (context, box) {
              final w = box.maxWidth / _customerDests.length;
              return Stack(
                children: [
                  AnimatedPositioned(
                    duration: const Duration(milliseconds: 380),
                    curve: Curves.easeOutBack,
                    left: w * index,
                    top: 0,
                    bottom: 0,
                    width: w,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: FrGradients.brand,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: FrColors.primary.withValues(alpha: 0.35),
                            blurRadius: 14,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      for (var i = 0; i < _customerDests.length; i++)
                        Expanded(
                          child: Semantics(
                            selected: i == index,
                            button: true,
                            label: tr(_customerDests[i].label),
                            excludeSemantics: true,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(20),
                              onTap: () => onSelect(i),
                              child: _NavItem(
                                dest: _customerDests[i],
                                selected: i == index,
                                badge: _customerDests[i].path == '/cart'
                                    ? cartCount
                                    : 0,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              );
            }),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final _CustomerDest dest;
  final bool selected;
  final int badge;
  const _NavItem(
      {required this.dest, required this.selected, required this.badge});

  @override
  Widget build(BuildContext context) {
    final color = selected ? Colors.white : FrColors.muted;
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        AnimatedScale(
          scale: selected ? 1.1 : 1,
          duration: const Duration(milliseconds: 250),
          child: _CartBadge(
            show: badge > 0,
            count: badge,
            child: Icon(selected ? dest.selectedIcon : dest.icon,
                color: color, size: 23),
          ),
        ),
        const SizedBox(height: 3),
        AnimatedDefaultTextStyle(
          duration: const Duration(milliseconds: 200),
          style: TextStyle(
            fontFamily: Theme.of(context).textTheme.bodyMedium?.fontFamily,
            color: color,
            fontSize: 11.5,
            fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
          ),
          child: Text(tr(dest.label), overflow: TextOverflow.ellipsis),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Vendor + admin shells — collapsible navigation rail.
// ---------------------------------------------------------------------------

class SideDest {
  final String path;
  final IconData icon;
  final IconData selectedIcon;
  final String label;
  const SideDest(this.path, this.icon, this.selectedIcon, this.label);
}

const _vendorDests = [
  SideDest('/vendor', Icons.dashboard_outlined, Icons.dashboard, 'Dashboard'),
  SideDest('/vendor/orders', Icons.receipt_long_outlined, Icons.receipt_long, 'Orders'),
  SideDest('/vendor/menu', Icons.restaurant_menu_outlined, Icons.restaurant_menu, 'Menu'),
  SideDest('/vendor/promotions', Icons.local_offer_outlined, Icons.local_offer, 'Promos'),
  SideDest('/vendor/reports', Icons.insights_outlined, Icons.insights, 'Reports'),
  SideDest('/vendor/settings', Icons.settings_outlined, Icons.settings, 'Settings'),
];

const _adminDests = [
  SideDest('/admin', Icons.dashboard_outlined, Icons.dashboard, 'Overview'),
  SideDest('/admin/users', Icons.people_outlined, Icons.people, 'Users'),
  SideDest('/admin/vendors', Icons.storefront_outlined, Icons.storefront, 'Stalls'),
  SideDest('/admin/orders', Icons.receipt_long_outlined, Icons.receipt_long, 'Orders'),
  SideDest('/admin/promotions', Icons.local_offer_outlined, Icons.local_offer, 'Promos'),
  SideDest('/admin/content', Icons.palette_outlined, Icons.palette, 'Content'),
  SideDest('/admin/reports', Icons.insights_outlined, Icons.insights, 'Reports'),
];

class StaffShell extends ConsumerWidget {
  final Widget child;
  final List<SideDest> dests;
  final String title;

  const StaffShell({
    super.key,
    required this.child,
    required this.dests,
    required this.title,
  });

  int _index(String loc) {
    int best = 0;
    int bestLen = 0;
    for (var i = 0; i < dests.length; i++) {
      if (loc.startsWith(dests[i].path) && dests[i].path.length > bestLen) {
        best = i;
        bestLen = dests[i].path.length;
      }
    }
    return best;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loc = GoRouterState.of(context).matchedLocation;
    final wide = !FrBreakpoints.isCompact(MediaQuery.sizeOf(context).width);

    // Phones: full-width content with a drawer — a desktop rail would eat
    // ~80px of a 390px screen and force mid-word wrapping everywhere.
    if (!wide) {
      final current = dests[_index(loc)].label;
      return Scaffold(
        appBar: AppBar(
          title: Text(current),
          actions: [
            IconButton(
              tooltip: tr('My profile'),
              icon: const Icon(Icons.account_circle_outlined),
              onPressed: () => context.go('/profile'),
            ),
            IconButton(
              tooltip: tr('Sign out'),
              icon: const Icon(Icons.logout),
              onPressed: () =>
                  ref.read(authControllerProvider.notifier).signOut(),
            ),
          ],
        ),
        drawer: Drawer(
          child: SafeArea(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: FrColors.primary,
                        child: Text(title,
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800)),
                      ),
                      const SizedBox(width: 12),
                      Text('FoodRush $title',
                          style: const TextStyle(
                              fontWeight: FontWeight.w800, fontSize: 16)),
                    ],
                  ),
                ),
                const Divider(),
                for (var i = 0; i < dests.length; i++)
                  ListTile(
                    leading: Icon(dests[i].icon),
                    title: Text(dests[i].label),
                    selected: _index(loc) == i,
                    onTap: () {
                      Navigator.of(context).pop();
                      context.go(dests[i].path);
                    },
                  ),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.account_circle_outlined),
                  title: Text(tr('My profile')),
                  onTap: () {
                    Navigator.of(context).pop();
                    context.go('/profile');
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.logout),
                  title: Text(tr('Sign out')),
                  onTap: () =>
                      ref.read(authControllerProvider.notifier).signOut(),
                ),
              ],
            ),
          ),
        ),
        body: child,
      );
    }

    return Scaffold(
      body: Row(
        children: [
          NavigationRail(
            extended: true,
            selectedIndex: _index(loc),
            onDestinationSelected: (i) => context.go(dests[i].path),
            leading: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: CircleAvatar(
                backgroundColor: FrColors.primary,
                child: Text(
                  title,
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w800),
                ),
              ),
            ),
            trailing: Expanded(
              child: Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: tr('My profile'),
                        icon: Icon(Icons.account_circle_outlined,
                            color: FrColors.muted),
                        onPressed: () => context.go('/profile'),
                      ),
                      IconButton(
                        tooltip: tr('Sign out'),
                        icon: Icon(Icons.logout, color: FrColors.muted),
                        onPressed: () =>
                            ref.read(authControllerProvider.notifier).signOut(),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            destinations: [
              for (final d in dests)
                NavigationRailDestination(
                  icon: Icon(d.icon),
                  selectedIcon: Icon(d.selectedIcon),
                  label: Text(d.label),
                ),
            ],
          ),
          Expanded(child: child),
        ],
      ),
    );
  }
}

class VendorShell extends ConsumerWidget {
  final Widget child;
  const VendorShell({super.key, required this.child});

  /// Staff only get the day-to-day pages.
  static const _staffPaths = {'/vendor', '/vendor/orders', '/vendor/menu'};

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isStaff = ref.watch(authControllerProvider.select((a) => a.role)) == kRoleStaff;
    return StaffShell(
      title: isStaff ? 'S' : 'V',
      dests: isStaff
          ? [for (final d in _vendorDests) if (_staffPaths.contains(d.path)) d]
          : _vendorDests,
      child: child,
    );
  }
}

class AdminShell extends StatelessWidget {
  final Widget child;
  const AdminShell({super.key, required this.child});

  @override
  Widget build(BuildContext context) => StaffShell(
        title: 'A',
        dests: _adminDests,
        child: child,
      );
}
