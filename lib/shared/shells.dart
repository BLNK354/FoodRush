import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/constants.dart';
import '../core/theme.dart';
import '../providers/auth_controller.dart';
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

    final appBar = AppBar(
      title: Text('FoodRush · $kUniversityName',
          style: const TextStyle(color: FrColors.primary)),
      actions: [
        IconButton(
          tooltip: 'Sign out',
          icon: const Icon(Icons.logout),
          onPressed: () => ref.read(authControllerProvider.notifier).signOut(),
        ),
      ],
    );

    return Scaffold(
      appBar: appBar,
      body: Row(
        children: [
          if (wide)
            NavigationRail(
              selectedIndex: _index(loc),
              onDestinationSelected: (i) => context.go(_customerDests[i].path),
              labelType: NavigationRailLabelType.all,
              leading: auth.profile == null
                  ? null
                  : Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: CircleAvatar(
                        backgroundColor: FrColors.primary.withValues(alpha: 0.12),
                        child: Text(
                          auth.profile!.fullName.isNotEmpty
                              ? auth.profile!.fullName[0].toUpperCase()
                              : '?',
                          style: const TextStyle(
                              color: FrColors.primary,
                              fontWeight: FontWeight.w800),
                        ),
                      ),
                    ),
              destinations: [
                for (final d in _customerDests)
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
      bottomNavigationBar: wide
          ? null
          : NavigationBar(
              selectedIndex: _index(loc),
              onDestinationSelected: (i) => context.go(_customerDests[i].path),
              destinations: [
                for (final d in _customerDests)
                  NavigationDestination(
                    icon: Icon(d.icon),
                    selectedIcon: Icon(d.selectedIcon),
                    label: d.label,
                  ),
              ],
            ),
    );
  }
}

// ---------------------------------------------------------------------------
// Vendor + admin shells — collapsible navigation rail.
// ---------------------------------------------------------------------------

class _SideDest {
  final String path;
  final IconData icon;
  final IconData selectedIcon;
  final String label;
  const _SideDest(this.path, this.icon, this.selectedIcon, this.label);
}

const _vendorDests = [
  _SideDest('/vendor', Icons.dashboard_outlined, Icons.dashboard, 'Dashboard'),
  _SideDest('/vendor/orders', Icons.receipt_long_outlined, Icons.receipt_long, 'Orders'),
  _SideDest('/vendor/menu', Icons.restaurant_menu_outlined, Icons.restaurant_menu, 'Menu'),
  _SideDest('/vendor/promotions', Icons.local_offer_outlined, Icons.local_offer, 'Promos'),
  _SideDest('/vendor/settings', Icons.settings_outlined, Icons.settings, 'Settings'),
];

const _adminDests = [
  _SideDest('/admin', Icons.dashboard_outlined, Icons.dashboard, 'Overview'),
  _SideDest('/admin/users', Icons.people_outlined, Icons.people, 'Users'),
  _SideDest('/admin/vendors', Icons.storefront_outlined, Icons.storefront, 'Stalls'),
  _SideDest('/admin/orders', Icons.receipt_long_outlined, Icons.receipt_long, 'Orders'),
  _SideDest('/admin/promotions', Icons.local_offer_outlined, Icons.local_offer, 'Promos'),
];

class StaffShell extends ConsumerWidget {
  final Widget child;
  final List<_SideDest> dests;
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
              tooltip: 'Sign out',
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
                  leading: const Icon(Icons.logout),
                  title: const Text('Sign out'),
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
                  child: IconButton(
                    tooltip: 'Sign out',
                    icon: const Icon(Icons.logout, color: FrColors.muted),
                    onPressed: () =>
                        ref.read(authControllerProvider.notifier).signOut(),
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

class VendorShell extends StatelessWidget {
  final Widget child;
  const VendorShell({super.key, required this.child});

  @override
  Widget build(BuildContext context) => StaffShell(
        title: 'V',
        dests: _vendorDests,
        child: child,
      );
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
