import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants.dart';
import '../../core/theme.dart';
import '../../models/order.dart';
import '../../providers/repository.dart';
import '../../shared/widgets.dart';

class OrderTrackingScreen extends ConsumerStatefulWidget {
  final String orderId;
  final bool isNew;

  const OrderTrackingScreen({super.key, required this.orderId, this.isNew = false});

  @override
  ConsumerState<OrderTrackingScreen> createState() =>
      _OrderTrackingScreenState();
}

class _OrderTrackingScreenState extends ConsumerState<OrderTrackingScreen> {
  Order? _order;
  bool _loading = true;
  String? _error;
  bool _uploading = false;
  StreamSubscription<Order?>? _sub;

  @override
  void initState() {
    super.initState();
    _subscribe();
  }

  /// Live stream — the page updates itself as the stall moves the order.
  void _subscribe() {
    _sub?.cancel();
    _sub = Repository.instance.streamOrder(widget.orderId).listen(
      (order) {
        if (!mounted) return;
        setState(() {
          _order = order;
          _loading = false;
          _error = order == null ? 'Order not found.' : null;
        });
      },
      onError: (e) {
        if (!mounted) return;
        setState(() {
          _loading = false;
          _error = '$e';
        });
      },
    );
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  Future<void> _uploadProof() async {
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.image,
      withData: true,
    );
    final file = picked?.files.single;
    final bytes = file?.bytes;
    if (file == null || bytes == null) return;

    setState(() => _uploading = true);
    try {
      final url = await Repository.instance.uploadImage(
        pathPrefix: kPathPaymentProofs,
        bytes: bytes,
        fileName: file.name,
      );
      await Repository.instance.submitProof(
          orderId: widget.orderId, imageUrl: url);
      if (!mounted) return;
      showSnack(context, 'Receipt submitted! The stall will verify it shortly.');
    } catch (e) {
      if (mounted) showSnack(context, 'Upload failed: $e', error: true);
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading && _order == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null && _order == null) {
      return FrPage(
        title: 'Order',
        children: [
          EmptyState(
            icon: Icons.error_outline,
            title: 'Could not load order',
            message: _error,
            action: FilledButton(
              onPressed: () {
                setState(() => _loading = true);
                _subscribe();
              },
              child: const Text('Retry'),
            ),
          ),
        ],
      );
    }
    final o = _order!;

    return FrPage(
      title: 'Order ${o.orderNumber}',
      subtitle: _isNewBanner,
      actions: [
        StatusChip.order(o.status),
      ],
      children: [
        if (widget.isNew && o.isPaidFlow && o.status == kOrderAwaitingPayment)
          _GcashPanel(
            order: o,
            uploading: _uploading,
            onUpload: _uploadProof,
          ),

        const SizedBox(height: 20),

        // Status timeline
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    if (o.queueNumber != null) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: FrColors.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(FrRadius.md),
                        ),
                        child: Column(
                          children: [
                            const Text('QUEUE #',
                                style: TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w800,
                                    color: FrColors.muted)),
                            Text('#${o.queueNumber}',
                                style: const TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w900,
                                    color: FrColors.primary)),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                    ],
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _headline(o),
                            style: const TextStyle(
                                fontWeight: FontWeight.w800, fontSize: 16),
                          ),
                          const SizedBox(height: 2),
                          Text(_subline(o),
                              style: const TextStyle(
                                  color: FrColors.muted, fontSize: 13)),
                        ],
                      ),
                    ),
                  ],
                ),
                const Divider(height: 32),
                _Timeline(order: o),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),

        // Items + payment summary
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ...o.items.map((it) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      child: Row(
                        children: [
                          Expanded(child: Text('${it.qty} × ${it.name}')),
                          Text(peso(it.lineTotal)),
                        ],
                      ),
                    )),
                const Divider(height: 24),
                _row('Subtotal', peso(o.subtotal)),
                if (o.discount > 0)
                  _row('Discount (${o.promoCode ?? ''})',
                      '-${peso(o.discount)}',
                      color: FrColors.success),
                _row('Total', peso(o.total), bold: true),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      o.paymentMethod == kPayGcash
                          ? Icons.account_balance_wallet
                          : Icons.payments,
                      size: 16,
                      color: FrColors.muted,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      o.paymentMethod == kPayGcash
                          ? 'Paid via GCash'
                          : 'Cash at pickup',
                      style: const TextStyle(color: FrColors.muted, fontSize: 13),
                    ),
                  ],
                ),
                if (o.rejectReason != null) ...[
                  const SizedBox(height: 8),
                  Text('Reason: ${o.rejectReason}',
                      style: const TextStyle(
                          color: FrColors.danger, fontSize: 13)),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        OutlinedButton.icon(
          onPressed: () => context.go('/orders'),
          icon: const Icon(Icons.arrow_back),
          label: const Text('All my orders'),
        ),
        const SizedBox(height: 40),
      ],
    );
  }

  Widget _row(String label, String value, {bool bold = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Text(label,
              style: TextStyle(
                  color: FrColors.muted,
                  fontWeight: bold ? FontWeight.w800 : null)),
          const Spacer(),
          Text(value,
              style: TextStyle(
                  fontWeight: bold ? FontWeight.w900 : FontWeight.w700,
                  color: color,
                  fontSize: bold ? 17 : 14.5)),
        ],
      ),
    );
  }

  String get _isNewBanner => widget.isNew
      ? 'Order placed! Below is what happens next.'
      : 'Placed ${_fmtDate(_order?.createdAt)} · ${_order?.vendorName ?? ''}';

  static String _fmtDate(DateTime? d) {
    if (d == null) return '';
    return '${d.month}/${d.day}/${d.year} ${d.hour}:${d.minute.toString().padLeft(2, '0')}';
  }

  String _headline(Order o) {
    if (o.status == kOrderRejected) {
      return 'Order rejected';
    }
    if (o.status == kOrderCompleted) return 'Enjoy your meal!';
    return switch (o.status) {
      kOrderAwaitingPayment => 'Waiting for your payment',
      kOrderProofSubmitted => 'Verifying your receipt',
      kOrderAccepted => 'Order accepted',
      kOrderPreparing => 'Being prepared',
      kOrderReady => 'Ready for pickup!',
      _ => o.status,
    };
  }

  String _subline(Order o) {
    if (o.status == kOrderRejected) {
      return o.rejectReason ?? 'Please contact the stall or place a new order.';
    }
    if (o.status == kOrderCompleted) return 'Picked up — thanks for ordering!';
    return switch (o.status) {
      kOrderAwaitingPayment =>
        'Send your GCash payment and upload the receipt below.',
      kOrderProofSubmitted => 'The stall is checking your receipt.',
      kOrderAccepted => 'The stall got your order — waiting to start.',
      kOrderPreparing => 'Almost there. Hang tight!',
      kOrderReady =>
        'Show your queue number at ${_order?.vendorName ?? 'the stall'}.',
      _ => '',
    };
  }
}

// ---------------------------------------------------------------------------
// GCash payment panel
// ---------------------------------------------------------------------------

class _GcashPanel extends ConsumerStatefulWidget {
  final Order order;
  final bool uploading;
  final VoidCallback onUpload;

  const _GcashPanel({
    required this.order,
    required this.uploading,
    required this.onUpload,
  });

  @override
  ConsumerState<_GcashPanel> createState() => _GcashPanelState();
}

class _GcashPanelState extends ConsumerState<_GcashPanel> {
  Map<String, dynamic>? _gcash;
  bool _loadingGcash = true;

  @override
  void initState() {
    super.initState();
    _loadGcash();
  }

  Future<void> _loadGcash() async {
    // Stall's own GCash first, platform fallback (admin-configured).
    final vendor = await Repository.instance.getVendor(widget.order.vendorId);
    if (vendor != null &&
        (vendor.gcashNumber?.isNotEmpty ?? false)) {
      if (!mounted) return;
      setState(() {
        _gcash = {
          'number': vendor.gcashNumber,
          'name': vendor.gcashName ?? vendor.name,
        };
        _loadingGcash = false;
      });
      return;
    }
    try {
      final data = await Repository.instance.getPlatformGcash();
      if (!mounted) return;
      setState(() {
        _gcash = data;
        _loadingGcash = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingGcash = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final number = _gcash?['number'] as String?;
    final name = _gcash?['name'] as String?;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: FrColors.chipGcash.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(FrRadius.md),
                  ),
                  child: const Icon(Icons.account_balance_wallet,
                      color: FrColors.chipGcash),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text('Pay with GCash',
                      style: TextStyle(
                          fontWeight: FontWeight.w800, fontSize: 16)),
                ),
                Text(peso(widget.order.total),
                    style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: FrColors.primary)),
              ],
            ),
            const SizedBox(height: 16),
            if (_loadingGcash)
              const Center(child: CircularProgressIndicator())
            else if (number == null || number.isEmpty)
              const Text(
                'GCash details are not configured yet. Please pay cash at pickup instead, or contact the stall.',
                style: TextStyle(color: FrColors.danger),
              )
            else
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: FrColors.chipGcash.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(FrRadius.md),
                  border: Border.all(
                      color: FrColors.chipGcash.withValues(alpha: 0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Send exactly this amount to:',
                        style: TextStyle(
                            fontSize: 12.5, color: FrColors.muted)),
                    const SizedBox(height: 6),
                    SelectableText(number,
                        style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                            color: FrColors.chipGcash)),
                    if (name != null && name.isNotEmpty)
                      Text(name,
                          style: const TextStyle(
                              color: FrColors.muted, fontSize: 13)),
                    const SizedBox(height: 4),
                    Text('Amount: ${peso(widget.order.total)}',
                        style: const TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 15)),
                  ],
                ),
              ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: widget.uploading ? null : widget.onUpload,
              icon: widget.uploading
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.upload_file),
              label: const Text('Upload GCash receipt'),
            ),
            const SizedBox(height: 6),
            const Text(
              'Take a screenshot of your GCash receipt and upload it here. The stall verifies it before preparing your order.',
              style: TextStyle(fontSize: 12, color: FrColors.muted),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Status timeline
// ---------------------------------------------------------------------------

class _Timeline extends StatelessWidget {
  final Order order;
  const _Timeline({required this.order});

  static const _steps = [
    (kOrderAwaitingPayment, 'Order placed'),
    (kOrderProofSubmitted, 'Receipt submitted'),
    (kOrderAccepted, 'Accepted'),
    (kOrderPreparing, 'Preparing'),
    (kOrderReady, 'Ready'),
    (kOrderCompleted, 'Picked up'),
  ];

  @override
  Widget build(BuildContext context) {
    if (order.status == kOrderRejected || order.status == kOrderCancelled) {
      return Row(
        children: [
          const Icon(Icons.cancel, color: FrColors.danger),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              order.status == kOrderRejected
                  ? 'This order was rejected by the stall.'
                  : 'This order was cancelled.',
              style: const TextStyle(
                  color: FrColors.danger, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      );
    }

    // For cash orders, proof_submitted step is skipped.
    final steps = order.paymentMethod == kPayCash
        ? _steps.where((s) => s.$1 != kOrderProofSubmitted).toList()
        : _steps;

    final currentIdx = steps.indexWhere((s) => s.$1 == order.status);

    return Column(
      children: [
        for (var i = 0; i < steps.length; i++)
          _TimelineRow(
            label: steps[i].$2,
            state: i < currentIdx
                ? _StepState.done
                : (i == currentIdx ? _StepState.current : _StepState.pending),
            isLast: i == steps.length - 1,
          ),
      ],
    );
  }
}

enum _StepState { done, current, pending }

class _TimelineRow extends StatelessWidget {
  final String label;
  final _StepState state;
  final bool isLast;

  const _TimelineRow({
    required this.label,
    required this.state,
    required this.isLast,
  });

  @override
  Widget build(BuildContext context) {
    final color = switch (state) {
      _StepState.done => FrColors.success,
      _StepState.current => FrColors.primary,
      _StepState.pending => FrColors.muted.withValues(alpha: 0.4),
    };
    return IntrinsicHeight(
      child: Row(
        children: [
          Column(
            children: [
              Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: state == _StepState.done
                      ? FrColors.success
                      : Colors.transparent,
                  border: Border.all(color: color, width: 2),
                ),
                child: state == _StepState.done
                    ? const Icon(Icons.check, size: 14, color: Colors.white)
                    : state == _StepState.current
                        ? const Icon(Icons.circle,
                            size: 10, color: FrColors.primary)
                        : null,
              ),
              if (!isLast)
                Expanded(
                  child: Container(width: 2, color: FrColors.line),
                ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 18),
              child: Text(
                label,
                style: TextStyle(
                  fontWeight: state == _StepState.current
                      ? FontWeight.w800
                      : FontWeight.w500,
                  color: state == _StepState.pending
                      ? FrColors.muted
                      : FrColors.ink,
                  fontSize: 14,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
