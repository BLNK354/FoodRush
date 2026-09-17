import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/admin/admin_dashboard.dart';
import '../features/admin/admin_orders.dart';
import '../features/admin/admin_promotions.dart';
import '../features/admin/admin_users.dart';
import '../features/admin/admin_vendors.dart';
import '../features/auth/login_screen.dart';
import '../features/auth/register_screen.dart';
import '../features/customer/cart_screen.dart';
import '../features/customer/checkout_screen.dart';
import '../features/customer/order_tracking_screen.dart';
import '../features/customer/orders_history_screen.dart';
import '../features/customer/shop_screen.dart';
import '../features/customer/stall_menu_screen.dart';
import '../features/vendor/vendor_dashboard.dart';
import '../features/vendor/vendor_menu_screen.dart';
import '../features/vendor/vendor_orders_screen.dart';
import '../features/vendor/vendor_promotions_screen.dart';
import '../features/vendor/vendor_settings_screen.dart';
import '../providers/auth_controller.dart';
import '../core/constants.dart';
import '../shared/shells.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final auth = ref.watch(authControllerProvider);

  return GoRouter(
    initialLocation: '/',
    redirect: (context, state) {
      final loggedIn = auth.isAuthenticated;
      final role = auth.role;
      final loc = state.matchedLocation;

      final onAuthPage =
          loc == '/' || loc == '/login' || loc == '/register';
      if (!loggedIn && !onAuthPage) return '/login';
      if (loggedIn && onAuthPage) {
        return switch (role) {
          kRoleAdmin => '/admin',
          kRoleVendor => '/vendor',
          _ => '/shop',
        };
      }
      return null;
    },
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const AuthGate(),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/register',
        builder: (context, state) => const RegisterScreen(),
      ),

      // ---------------- customer ----------------
      ShellRoute(
        builder: (context, state, child) => CustomerShell(child: child),
        routes: [
          GoRoute(
            path: '/shop',
            builder: (context, state) => const ShopScreen(),
          ),
          GoRoute(
            path: '/stall/:id',
            builder: (context, state) =>
                StallMenuScreen(vendorId: state.pathParameters['id']!),
          ),
          GoRoute(
            path: '/cart',
            builder: (context, state) => const CartScreen(),
          ),
          GoRoute(
            path: '/checkout',
            builder: (context, state) => const CheckoutScreen(),
          ),
          GoRoute(
            path: '/orders',
            builder: (context, state) => const OrdersHistoryScreen(),
          ),
          GoRoute(
            path: '/orders/:id',
            builder: (context, state) =>
                OrderTrackingScreen(orderId: state.pathParameters['id']!),
          ),
        ],
      ),

      // ---------------- vendor ----------------
      ShellRoute(
        builder: (context, state, child) => VendorShell(child: child),
        routes: [
          GoRoute(
            path: '/vendor',
            builder: (context, state) => const VendorDashboard(),
          ),
          GoRoute(
            path: '/vendor/orders',
            builder: (context, state) => const VendorOrdersScreen(),
          ),
          GoRoute(
            path: '/vendor/menu',
            builder: (context, state) => const VendorMenuScreen(),
          ),
          GoRoute(
            path: '/vendor/promotions',
            builder: (context, state) => const VendorPromotionsScreen(),
          ),
          GoRoute(
            path: '/vendor/settings',
            builder: (context, state) => const VendorSettingsScreen(),
          ),
        ],
      ),

      // ---------------- admin ----------------
      ShellRoute(
        builder: (context, state, child) => AdminShell(child: child),
        routes: [
          GoRoute(
            path: '/admin',
            builder: (context, state) => const AdminDashboard(),
          ),
          GoRoute(
            path: '/admin/users',
            builder: (context, state) => const AdminUsersScreen(),
          ),
          GoRoute(
            path: '/admin/vendors',
            builder: (context, state) => const AdminVendorsScreen(),
          ),
          GoRoute(
            path: '/admin/orders',
            builder: (context, state) => const AdminOrdersScreen(),
          ),
          GoRoute(
            path: '/admin/promotions',
            builder: (context, state) => const AdminPromotionsScreen(),
          ),
        ],
      ),
    ],
  );
});

/// Decides the first screen while auth state resolves.
class AuthGate extends ConsumerWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authControllerProvider);
    if (auth.loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    return const LoginScreen();
  }
}
