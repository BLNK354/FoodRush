import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants.dart';
import '../../core/theme.dart';
import '../../models/order.dart';
import '../../providers/repository.dart';
import '../../shared/validation.dart';
import '../../shared/widgets.dart';

class VendorOrdersScreen extends ConsumerStatefulWidget {
  const VendorOrdersScreen({super.key});

  @override
  ConsumerState<VendorOrdersScreen> createState() =>
      _VendorOrdersScreenState();
}

class _VendorOrdersScreenState extends ConsumerState<VendorOrdersScreen> {
  List<Order> _orders = [];
  bool _loading = true;
  String? _error;
  StreamSubscription<List<Order>>? _ordersSub;
  String _tab = 'active';
  String? _vendorId;

  /// productId -> current menu price, for the per-order price check.
  Map<String, double>? _menuPrices;

  /// Older completed orders fetched with "Load older" (beyond the live 300).
  List<Order> _older = [];
  bool _loadingOlder = false;
  bool _noMoreOlder = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _ordersSub?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final vendor = await Repository.instance.getMyVendor();
      if (vendor == null) {
        if (!mounted) return;
        setState(() {
          _loading = false;
          _error = 'No stall found for your account.';
        });
        return;
      }
      if (!mounted) return;
      setState(() {
        _error = null;
        _vendorId = vendor.id;
      });
      Repository.instance.listProducts(vendor.id).then((products) {
        if (!mounted) return;
        setState(() => _menuPrices = {for (final p in products) p.id: p.price});
      }, onError: (Object _) {});
      // Live stream — orders update in real time, no polling.
      _ordersSub ??= Repository.instance
          .streamVendorOrders(vendor.id)
          .listen((orders) {
        if (!mounted) return;
        setState(() {
          _orders = orders;
          _loading = false;
        });
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = '$e';
      });
    }
  }

  List<Order> get _filtered {
    switch (_tab) {
      case 'needs_action':
        return _orders
            .where((o) =>
                o.status == kOrderAwaitingPayment ||
                o.status == kOrderProofSubmitted ||
                o.status == kOrderAccepted)
            .toList();
      case 'preparing':
        return _orders
            .where((o) =>
                o.status == kOrderPreparing || o.status == kOrderReady)
            .toList();
      case 'done':
        return [..._orders, ..._older]
            .where((o) =>
                o.status == kOrderCompleted ||
                o.status == kOrderRejected ||
                o.status == kOrderCancelled)
            .toList();
      case 'refunds':
        return [..._orders, ..._older]
            .where((o) => o.refundStatus != null)
            .toList()
          ..sort((a, b) =>
              (a.refundOwed ? 0 : 1).compareTo(b.refundOwed ? 0 : 1));
      default:
        return _orders.where((o) => o.isActive).toList();
    }
  }

  @override
  Widget build(BuildContext context) {
    final refundsOwed = _orders.where((o) => o.refundOwed).length;
    return FrPage(
      title: 'Orders',
      subtitle: 'Live queue — updates automatically.',
      actions: [
        IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
      ],
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final t in [
              ('needs_action', 'Needs action'),
              ('preparing', 'Preparing / ready'),
              ('active', 'All active'),
              ('done', 'Completed'),
              ('refunds', refundsOwed > 0 ? 'Refunds ($refundsOwed)' : 'Refunds'),
            ])
              ChoiceChip(
                label: Text(t.$2),
                selected: _tab == t.$1,
                onSelected: (_) => setState(() => _tab = t.$1),
              ),
          ],
        ),
        const SizedBox(height: 16),
        if (_loading && _orders.isEmpty)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(48),
              child: CircularProgressIndicator(),
            ),
          )
        else if (_error != null && _orders.isEmpty)
          EmptyState(
            icon: Icons.error_outline,
            title: 'Could not load orders',
            message: _error,
            action: FilledButton(onPressed: _load, child: const Text('Retry')),
          )
        else if (_filtered.isEmpty)
          const EmptyState(
            icon: Icons.receipt_long_outlined,
            title: 'Nothing here',
            message: 'Orders will appear as customers check out.',
          )
        else
          ..._filtered.map((o) => _OrderCard(
                order: o,
                menuPrices: _menuPrices,
                onAction: _handleAction,
              )),
        if ((_tab == 'done' || _tab == 'refunds') &&
            _orders.isNotEmpty &&
            !_noMoreOlder)
          Center(
            child: TextButton.icon(
              onPressed: _loadingOlder ? null : _loadOlder,
              icon: const Icon(Icons.history),
              label: Text(_loadingOlder ? 'Loading…' : 'Load older orders'),
            ),
          ),
        const SizedBox(height: 40),
      ],
    );
  }

  Future<void> _loadOlder() async {
    final all = [..._orders, ..._older];
    final oldest = all
        .map((o) => o.createdAt)
        .whereType<DateTime>()
        .fold<DateTime?>(null, (m, d) => m == null || d.isBefore(m) ? d : m);
    if (oldest == null || _vendorId == null) return;
    setState(() => _loadingOlder = true);
    try {
      final more = await Repository.instance.olderOrders(
          field: 'vendorId', value: _vendorId, before: oldest);
      if (!mounted) return;
      setState(() {
        _older = [..._older, ...more];
        _noMoreOlder = more.length < 50;
      });
    } catch (e) {
      if (mounted) showSnack(context, 'Could not load older orders: $e', error: true);
    } finally {
      if (mounted) setState(() => _loadingOlder = false);
    }
  }

  Future<void> _handleAction(Order order, String action) async {
    if (action == 'view') {
      _showReceipt(order);
      return;
    }
    try {
      switch (action) {
        case 'accept':
          await Repository.instance.reviewPayment(
            orderId: order.id,
            approve: true,
          );
          break;
        case 'reject':
          final reason = await _promptText(
            'Reject order',
            'Reason shown to the customer:',
            initial: 'Payment could not be verified.',
          );
          if (reason == null) return;
          await Repository.instance.reviewPayment(
            orderId: order.id,
            approve: false,
            note: reason,
          );
          break;
        case 'preparing':
          await Repository.instance.updateOrderStatus(
              order.id, kOrderPreparing);
          break;
        case 'ready':
          await Repository.instance
              .updateOrderStatus(order.id, kOrderReady);
          break;
        case 'complete':
          await Repository.instance
              .updateOrderStatus(order.id, kOrderCompleted);
          break;
        case 'cancel':
          final reason = await _promptText(
            'Cancel this order?',
            'Reason shown to the customer:',
            initial: 'Sorry, this item is sold out.',
          );
          if (reason == null) return;
          await Repository.instance.cancelOrder(order.id, reason: reason);
          if (mounted && order.isPaidFlow &&
              (order.status != kOrderAwaitingPayment)) {
            showSnack(context,
                'Cancelled. Refund of ${peso(order.total)} is now owed (see Refunds).');
            return;
          }
          break;
        case 'refunded':
          final ok = await confirmDialog(
            context,
            title: 'Mark ${peso(order.total)} as refunded?',
            message: 'Only do this after sending the money back to '
                '${order.customerName?.isNotEmpty == true ? order.customerName : 'the student'}'
                ' via GCash (use the number on their receipt).',
            confirmLabel: 'Mark refunded',
          );
          if (!ok) return;
          await Repository.instance.markRefunded(order.id);
          break;
      }
      if (mounted) showSnack(context, 'Order updated.');
    } catch (e) {
      if (mounted) showSnack(context, 'Update failed: $e', error: true);
    }
  }

  void _showReceipt(Order order) {
    if (order.receiptUrl == null) {
      showSnack(context, 'No receipt uploaded yet.', error: true);
      return;
    }
    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480, maxHeight: 640),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text('GCash receipt',
                          style: TextStyle(
                              fontWeight: FontWeight.w800, fontSize: 16)),
                    ),
                    if (order.receiptStatus != null)
                      StatusChip.proof(order.receiptStatus!),
                  ],
                ),
              ),
              Flexible(
                child: InteractiveViewer(
                  child: FrImage(order.receiptUrl, fit: BoxFit.contain),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Close'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<String?> _promptText(
    String title,
    String label, {
    String? initial,
  }) async {
    final controller = TextEditingController(text: initial);
    final res = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLines: 3,
          maxLength: Limits.note,
          decoration: InputDecoration(labelText: label),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              // Shown to the student, so no abuse and a real reason.
              final err = validateText(controller.text,
                  max: Limits.note, required: true, min: 3, label: 'Reason');
              if (err != null) {
                showSnack(context, err, error: true);
                return;
              }
              Navigator.pop(context, controller.text);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
    return res?.trim().isEmpty == true ? null : res?.trim();
  }
}

// ---------------------------------------------------------------------------
// Order card
// ---------------------------------------------------------------------------

class _OrderCard extends ConsumerWidget {
  final Order order;
  final Map<String, double>? menuPrices;
  final Future<void> Function(Order, String) onAction;

  const _OrderCard({
    required this.order,
    required this.menuPrices,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final needsPaymentReview = order.status == kOrderProofSubmitted ||
        (order.status == kOrderAwaitingPayment);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: FrColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(FrRadius.md),
                  ),
                  child: Text(
                    '#${order.queueNumber ?? '?'}',
                    style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                        color: FrColors.primary),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        order.customerName ?? 'Customer',
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      Text(
                        '${order.orderNumber} · ${_fmt(order.createdAt)}',
                        style: TextStyle(
                            color: FrColors.muted, fontSize: 12.5),
                      ),
                      if (order.isActive)
                        Text(
                          order.pickupAt == null
                              ? 'Pickup: ASAP'
                              : 'Pickup at ${fmtClock(order.pickupAt!)}',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w800,
                            color: order.pickupAt == null
                                ? FrColors.muted
                                : FrColors.info,
                          ),
                        ),
                    ],
                  ),
                ),
                StatusChip.order(order.status),
              ],
            ),
            if (order.isActive) ...[
              const SizedBox(height: 12),
              OrderProgressBar(
                  status: order.status, paymentMethod: order.paymentMethod),
            ],
            const Divider(height: 24),
            ...order.items.map(
              (it) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  children: [
                    Expanded(child: Text('${it.qty} × ${it.name}')),
                    Text(peso(it.lineTotal)),
                  ],
                ),
              ),
            ),
            const Divider(height: 24),
            Row(
              children: [
                Icon(
                  order.paymentMethod == kPayGcash
                      ? Icons.account_balance_wallet
                      : Icons.payments,
                  size: 16,
                  color: order.paymentMethod == kPayGcash
                      ? FrColors.chipGcash
                      : FrColors.chipCash,
                ),
                const SizedBox(width: 6),
                Text(
                  order.paymentMethod == kPayGcash
                      ? 'GCash'
                      : 'Cash at pickup',
                  style: const TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 13),
                ),
                const Spacer(),
                Text(peso(order.total),
                    style: const TextStyle(
                        fontWeight: FontWeight.w900, fontSize: 16)),
              ],
            ),
            if (order.note != null && order.note!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text('Note: ${order.note}',
                  style: TextStyle(
                      fontStyle: FontStyle.italic,
                      color: FrColors.muted,
                      fontSize: 12.5)),
            ],
            if (order.rejectReason != null) ...[
              const SizedBox(height: 8),
              Text(
                  '${order.status == kOrderCancelled ? 'Cancelled' : 'Rejected'}: '
                  '${order.rejectReason}',
                  style: TextStyle(
                      color: FrColors.danger, fontSize: 12.5)),
            ],
            if (order.refundStatus != null) ...[
              const SizedBox(height: 8),
              order.refundOwed
                  ? StatusChip('Refund owed: ${peso(order.total)}',
                      color: FrColors.danger)
                  : StatusChip('Refunded', color: FrColors.success),
            ],
            if (order.isActive) _integrityWarning(),
            const SizedBox(height: 14),
            _buildActions(context, needsPaymentReview),
          ],
        ),
      ),
    );
  }

  Widget _buildActions(BuildContext context, bool needsPaymentReview) {
    final children = <Widget>[];

    switch (order.status) {
      case kOrderAwaitingPayment:
        children.add(_chip('Awaiting customer receipt'));
        if (order.paymentMethod == kPayCash) {
          children.add(_actionBtn('Accept', 'accept', FrColors.success));
        }
        break;
      case kOrderProofSubmitted:
        children.add(_actionBtn('View receipt', 'view', FrColors.info));
        children.add(_actionBtn('Verify & accept', 'accept', FrColors.success));
        children.add(_actionBtn('Reject', 'reject', FrColors.danger));
        break;
      case kOrderAccepted:
        children.add(
            _actionBtn('Start preparing', 'preparing', FrColors.secondary));
        break;
      case kOrderPreparing:
        children.add(_actionBtn('Mark ready', 'ready', FrColors.success));
        break;
      case kOrderReady:
        children.add(_actionBtn('Complete pickup', 'complete', FrColors.primary));
        break;
      default:
        break;
    }
    // The stall can cancel anything not yet picked up (e.g. sold out);
    // receipts under review use Reject instead.
    if (order.isActive && order.status != kOrderProofSubmitted) {
      children.add(_actionBtn('Cancel', 'cancel', FrColors.muted));
    }
    if (order.refundOwed) {
      children.add(_actionBtn('Mark refunded', 'refunded', FrColors.success));
    }

    if (children.isEmpty) return const SizedBox.shrink();
    return Wrap(spacing: 10, runSpacing: 8, children: children);
  }

  /// Prices that don't match the menu mean the order didn't come from the
  /// app as-is (or the menu changed since): check before accepting.
  Widget _integrityWarning() {
    final issues = order.integrityIssues(menuPrices);
    if (issues.isEmpty) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: FrColors.danger.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(FrRadius.md),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.warning_amber_rounded,
              color: FrColors.danger, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Check this order before accepting:\n• ${issues.join('\n• ')}',
              style: TextStyle(color: FrColors.danger, fontSize: 12.5),
            ),
          ),
        ],
      ),
    );
  }

  Widget _actionBtn(String label, String action, Color color) {
    return FilledButton.tonal(
      onPressed: () => onAction(order, action == 'view' ? 'view' : action),
      style: FilledButton.styleFrom(
        backgroundColor: color.withValues(alpha: 0.12),
        foregroundColor: color,
        minimumSize: const Size(0, 40),
        padding: const EdgeInsets.symmetric(horizontal: 14),
      ),
      child: Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
    );
  }

  Widget _chip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: FrColors.muted.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(FrRadius.md),
      ),
      child: Text(label,
          style: TextStyle(color: FrColors.muted, fontSize: 13)),
    );
  }

  static String _fmt(DateTime? d) {
    if (d == null) return '';
    return '${d.month}/${d.day} ${d.hour}:${d.minute.toString().padLeft(2, '0')}';
  }
}
