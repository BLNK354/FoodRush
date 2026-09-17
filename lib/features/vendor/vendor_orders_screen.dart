import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants.dart';
import '../../core/theme.dart';
import '../../models/order.dart';
import '../../providers/repository.dart';
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
      setState(() => _error = null);
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
        return _orders
            .where((o) =>
                o.status == kOrderCompleted ||
                o.status == kOrderRejected ||
                o.status == kOrderCancelled)
            .toList();
      default:
        return _orders.where((o) => o.isActive).toList();
    }
  }

  @override
  Widget build(BuildContext context) {
    return FrPage(
      title: 'Orders',
      subtitle: 'Live queue — updates automatically.',
      actions: [
        IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
      ],
      children: [
        Wrap(
          spacing: 8,
          children: [
            for (final t in const [
              ('needs_action', 'Needs action'),
              ('preparing', 'Preparing / ready'),
              ('active', 'All active'),
              ('done', 'Completed'),
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
                onAction: _handleAction,
              )),
        const SizedBox(height: 40),
      ],
    );
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
          decoration: InputDecoration(labelText: label),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text),
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
  final Future<void> Function(Order, String) onAction;

  const _OrderCard({required this.order, required this.onAction});

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
                        style: const TextStyle(
                            color: FrColors.muted, fontSize: 12.5),
                      ),
                    ],
                  ),
                ),
                StatusChip.order(order.status),
              ],
            ),
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
                  style: const TextStyle(
                      fontStyle: FontStyle.italic,
                      color: FrColors.muted,
                      fontSize: 12.5)),
            ],
            if (order.rejectReason != null) ...[
              const SizedBox(height: 8),
              Text('Rejected: ${order.rejectReason}',
                  style: const TextStyle(
                      color: FrColors.danger, fontSize: 12.5)),
            ],
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

    if (children.isEmpty) return const SizedBox.shrink();
    return Wrap(spacing: 10, runSpacing: 8, children: children);
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
          style: const TextStyle(color: FrColors.muted, fontSize: 13)),
    );
  }

  static String _fmt(DateTime? d) {
    if (d == null) return '';
    return '${d.month}/${d.day} ${d.hour}:${d.minute.toString().padLeft(2, '0')}';
  }
}
