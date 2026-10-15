import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants.dart';
import '../../models/order.dart';
import '../../models/user.dart';
import '../../providers/repository.dart';
import '../../shared/browser/browser.dart' as browser;

/// Full-screen "Now serving" board for a TV/tablet at the counter: queue
/// numbers ready for pickup (big) and being prepared (smaller), live. Uses a
/// fixed dark, high-contrast look regardless of the app theme, since it's
/// read from across a room. Runs on a stall owner or staff login.
class NowServingScreen extends ConsumerStatefulWidget {
  const NowServingScreen({super.key});

  @override
  ConsumerState<NowServingScreen> createState() => _NowServingScreenState();
}

class _NowServingScreenState extends ConsumerState<NowServingScreen> {
  static const _bg = Color(0xFF111111);
  static const _ready = Color(0xFF4CC274);
  static const _text = Colors.white;
  static const _dim = Color(0xFFB0B0B0);

  Vendor? _stall;
  List<Order> _readyOrders = [];
  List<Order> _preparing = [];
  String? _newestReadyId;
  StreamSubscription<List<Order>>? _sub;
  Timer? _clock;
  String? _error;

  @override
  void initState() {
    super.initState();
    _start();
    _clock = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  Future<void> _start() async {
    try {
      final stall = await Repository.instance.getMyVendor();
      if (!mounted) return;
      if (stall == null) {
        setState(() => _error = 'No stall linked to this account.');
        return;
      }
      setState(() => _stall = stall);
      _sub = Repository.instance.streamVendorOrders(stall.id).listen((orders) {
        if (!mounted) return;
        final ready = orders.where((o) => o.status == kOrderReady).toList()
          ..sort((a, b) => (b.readyAt ?? DateTime(2000)).compareTo(a.readyAt ?? DateTime(2000)));
        final newest = ready.isEmpty ? null : ready.first.id;
        if (newest != null && newest != _newestReadyId && _newestReadyId != null) {
          browser.playChime(); // a new number to call out
        }
        setState(() {
          _readyOrders = ready;
          _newestReadyId = newest ?? _newestReadyId;
          _preparing = orders
              .where((o) => o.status == kOrderAccepted || o.status == kOrderPreparing)
              .toList()
            ..sort((a, b) => (a.queueNumber ?? 0).compareTo(b.queueNumber ?? 0));
        });
      }, onError: (Object e) {
        if (mounted) setState(() => _error = '$e');
      });
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    _clock?.cancel();
    super.dispose();
  }

  String _clockText() {
    final t = TimeOfDay.now();
    final h = t.hourOfPeriod == 0 ? 12 : t.hourOfPeriod;
    return '$h:${t.minute.toString().padLeft(2, '0')} ${t.period == DayPeriod.am ? 'AM' : 'PM'}';
  }

  Widget _number(Order o, {required double size, required Color color, bool glow = false}) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: size * 0.35, vertical: size * 0.12),
      decoration: BoxDecoration(
        color: glow ? color.withValues(alpha: 0.18) : Colors.transparent,
        border: Border.all(color: color, width: glow ? 4 : 2),
        borderRadius: BorderRadius.circular(size * 0.25),
      ),
      child: Text('#${o.queueNumber ?? '?'}',
          style: TextStyle(color: color, fontSize: size, fontWeight: FontWeight.w900)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    final big = (w / 9).clamp(48.0, 140.0);
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: _error != null
              ? Center(child: Text(_error!, style: const TextStyle(color: _text, fontSize: 22)))
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(_stall?.name ?? kAppName,
                              style: const TextStyle(
                                  color: _text, fontSize: 32, fontWeight: FontWeight.w900)),
                        ),
                        Text(_clockText(), style: const TextStyle(color: _dim, fontSize: 28)),
                        IconButton(
                          tooltip: 'Close',
                          color: _dim,
                          icon: const Icon(Icons.close),
                          onPressed: () => context.go('/vendor'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    const Text('READY FOR PICKUP',
                        style: TextStyle(
                            color: _ready, fontSize: 26, fontWeight: FontWeight.w800, letterSpacing: 2)),
                    const SizedBox(height: 16),
                    Expanded(
                      flex: 3,
                      child: _readyOrders.isEmpty
                          ? const Text('—', style: TextStyle(color: _dim, fontSize: 48))
                          : SingleChildScrollView(
                              child: Wrap(
                                spacing: 20,
                                runSpacing: 20,
                                children: [
                                  for (final o in _readyOrders)
                                    _number(o,
                                        size: big,
                                        color: _ready,
                                        glow: o.id == _newestReadyId),
                                ],
                              ),
                            ),
                    ),
                    const Divider(color: Color(0xFF333333), height: 40),
                    const Text('PREPARING',
                        style: TextStyle(
                            color: _dim, fontSize: 22, fontWeight: FontWeight.w800, letterSpacing: 2)),
                    const SizedBox(height: 12),
                    Expanded(
                      flex: 2,
                      child: SingleChildScrollView(
                        child: Wrap(
                          spacing: 14,
                          runSpacing: 14,
                          children: [
                            for (final o in _preparing)
                              _number(o, size: big * 0.45, color: _dim),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
