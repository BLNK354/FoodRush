import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../core/constants.dart';
import '../models/order.dart';
import '../providers/repository.dart';
import 'browser/browser.dart' as browser;

/// Watches the signed-in user's live orders while a role shell is mounted and
/// raises an alert on the transitions that matter:
///   customer — their order becomes "ready for pickup" (or is rejected);
///   vendor   — a new order arrives or a GCash receipt needs checking.
/// Alerts: in-app snackbar, chime, vibration, a system notification when the
/// user allowed them, and a "(n)" badge in the tab title. Works without any
/// server — but only while FoodRush is open in a tab.
class OrderAlerts extends StatefulWidget {
  final bool vendor;
  final Widget child;

  const OrderAlerts.customer({super.key, required this.child})
      : vendor = false;
  const OrderAlerts.vendor({super.key, required this.child}) : vendor = true;

  @override
  State<OrderAlerts> createState() => _OrderAlertsState();
}

class _OrderAlertsState extends State<OrderAlerts> {
  StreamSubscription<List<Order>>? _sub;

  /// Last seen status per order; null until the first snapshot seeds it so
  /// orders that already existed don't alert on page load.
  Map<String, String>? _seen;

  /// Vendor only: the stall, and the queue size last published for it.
  String? _stallId;
  int? _publishedActive;

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    Stream<List<Order>> stream;
    if (widget.vendor) {
      final stall = await Repository.instance.getMyVendor();
      if (stall == null || !mounted) return;
      _stallId = stall.id;
      stream = Repository.instance.streamVendorOrders(stall.id);
    } else {
      stream = Repository.instance.streamMyOrders();
    }
    _sub = stream.listen(_onOrders, onError: (Object _) {});
  }

  void _onOrders(List<Order> orders) {
    final previous = _seen;
    _seen = {for (final o in orders) o.id: o.status};

    browser.setTitleBadge(orders.where(_needsAttention).length);
    _publishQueue(orders);
    if (previous == null) return; // first snapshot: seed only

    for (final o in orders) {
      final before = previous[o.id];
      if (before == o.status) continue;
      final alert = widget.vendor ? _vendorAlert(o, before) : _customerAlert(o);
      if (alert != null) _raise(alert.$1, alert.$2, o);
    }
  }

  /// Students can't read other people's orders, so the stall's app keeps
  /// the queue size on its counter doc for their wait estimates.
  void _publishQueue(List<Order> orders) {
    final stall = _stallId;
    if (stall == null) return;
    final active = orders.where(Repository.isInQueue).length;
    if (active == _publishedActive) return;
    _publishedActive = active;
    Repository.instance
        .publishActiveCount(stall, active)
        .catchError((Object _) => _publishedActive = null); // retry next time
  }

  bool _needsAttention(Order o) => widget.vendor
      ? o.status == kOrderProofSubmitted ||
          (o.status == kOrderAccepted && o.paymentMethod == kPayCash)
      : o.status == kOrderReady;

  (String, String)? _customerAlert(Order o) {
    final stall = o.vendorName ?? 'the stall';
    return switch (o.status) {
      kOrderReady => (
          'Order #${o.queueNumber ?? ''} is ready!',
          'Pick it up at $stall.'
        ),
      kOrderRejected => (
          'Order ${o.orderNumber} was rejected',
          o.rejectReason ?? 'Open the order for details.'
        ),
      _ => null,
    };
  }

  (String, String)? _vendorAlert(Order o, String? before) {
    final who = o.customerName?.isNotEmpty == true ? o.customerName! : 'A student';
    if (before == null) {
      return ('New order #${o.queueNumber ?? ''}', '$who ordered ${o.items.length} item(s).');
    }
    if (o.status == kOrderProofSubmitted) {
      return ('Receipt to check · #${o.queueNumber ?? ''}', '$who uploaded a GCash receipt.');
    }
    return null;
  }

  void _raise(String title, String body, Order o) {
    browser.playChime();
    browser.vibrate();
    HapticFeedback.heavyImpact();
    browser.showSystemNotification(title, body);
    if (!mounted) return;
    final messenger = ScaffoldMessenger.maybeOf(context);
    messenger?.showSnackBar(SnackBar(
      duration: const Duration(seconds: 8),
      content: Text('$title — $body'),
      action: SnackBarAction(
        label: 'View',
        onPressed: () =>
            context.go(widget.vendor ? '/vendor/orders' : '/orders/${o.id}'),
      ),
    ));
  }

  @override
  void dispose() {
    _sub?.cancel();
    browser.setTitleBadge(0);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// "Turn on notifications" prompt; hidden when unsupported or already on.
class EnableAlertsButton extends StatefulWidget {
  final String label;
  const EnableAlertsButton({super.key, required this.label});

  @override
  State<EnableAlertsButton> createState() => _EnableAlertsButtonState();
}

class _EnableAlertsButtonState extends State<EnableAlertsButton> {
  @override
  Widget build(BuildContext context) {
    if (!browser.notificationsSupported || browser.notificationsGranted) {
      return const SizedBox.shrink();
    }
    return OutlinedButton.icon(
      icon: const Icon(Icons.notifications_active_outlined),
      label: Text(widget.label),
      onPressed: () async {
        final ok = await browser.requestNotificationPermission();
        if (!mounted) return;
        setState(() {});
        ScaffoldMessenger.of(this.context).showSnackBar(SnackBar(
          content: Text(ok
              ? 'Notifications on. Keep FoodRush open in a tab to get them.'
              : 'Notifications are blocked. Allow them in your browser settings.'),
        ));
      },
    );
  }
}
