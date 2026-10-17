import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/theme.dart';
import '../models/misc.dart';
import '../providers/repository.dart';
import 'widgets.dart';

/// Background for each [HomeBanner.styles] value.
LinearGradient bannerGradient(String style) => switch (style) {
      'sunset' => FrGradients.sunset,
      'night' => const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF2B2422), Color(0xFF14110F)],
        ),
      'mint' => const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF2FB277), Color(0xFF137A55)],
        ),
      _ => FrGradients.brand,
    };

String bannerStyleLabel(String style) => switch (style) {
      'sunset' => 'Sunset',
      'night' => 'Night',
      'mint' => 'Mint',
      _ => 'Ember',
    };

/// One promo card. Used on the Shop page and as the admin's live preview.
class HomeBannerCard extends StatelessWidget {
  final HomeBanner banner;

  /// Preview mode: the button does nothing.
  final bool preview;
  final double height;

  const HomeBannerCard({
    super.key,
    required this.banner,
    this.preview = false,
    this.height = 168,
  });

  @override
  Widget build(BuildContext context) {
    final b = banner;
    final hasImage = (b.imageUrl ?? '').isNotEmpty;
    final link = b.link ?? '';
    final cta = (b.ctaLabel ?? '').trim();
    return Container(
      height: height,
      decoration: BoxDecoration(
        gradient: bannerGradient(b.style),
        borderRadius: BorderRadius.circular(FrRadius.xl),
        boxShadow: FrShadows.soft,
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (hasImage) ...[
            FrImage(b.imageUrl),
            // Scrim keeps white text readable over any photo.
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [Color(0xCC000000), Color(0x33000000)],
                ),
              ),
            ),
          ],
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 18, 22, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  b.title.trim().isEmpty ? 'Banner title' : b.title.trim(),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    height: 1.1,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.6,
                  ),
                ),
                if ((b.body ?? '').trim().isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    b.body!.trim(),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.9),
                      fontSize: 13.5,
                      height: 1.35,
                    ),
                  ),
                ],
                if (cta.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: const Color(0xFF1A1614),
                      visualDensity: VisualDensity.compact,
                    ),
                    onPressed: preview || link.isEmpty
                        ? (preview ? () {} : null)
                        : () => context.go(link),
                    child: Text(cta),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Live banners from the CMS, swiping every few seconds. Renders nothing
/// when there are none (or they fail to load).
class HomeBannerCarousel extends StatefulWidget {
  const HomeBannerCarousel({super.key});

  @override
  State<HomeBannerCarousel> createState() => _HomeBannerCarouselState();
}

class _HomeBannerCarouselState extends State<HomeBannerCarousel> {
  final _page = PageController();
  StreamSubscription<List<HomeBanner>>? _sub;
  Timer? _timer;
  List<HomeBanner> _banners = const [];
  int _index = 0;

  @override
  void initState() {
    super.initState();
    _sub = Repository.instance.streamBanners().listen(
      (all) {
        if (!mounted) return;
        setState(() {
          _banners = all.where((b) => b.active).toList();
          if (_index >= _banners.length) _index = 0;
        });
      },
      onError: (Object _) {}, // no banners is better than a broken page
    );
    _timer = Timer.periodic(const Duration(seconds: 6), (_) {
      if (_banners.length < 2 || !_page.hasClients) return;
      _page.animateToPage(
        (_index + 1) % _banners.length,
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeOutCubic,
      );
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _sub?.cancel();
    _page.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_banners.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        children: [
          SizedBox(
            height: 168,
            child: PageView.builder(
              controller: _page,
              itemCount: _banners.length,
              onPageChanged: (i) => setState(() => _index = i),
              itemBuilder: (context, i) => Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: HomeBannerCard(banner: _banners[i]),
              ),
            ),
          ),
          if (_banners.length > 1) ...[
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < _banners.length; i++)
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: i == _index ? 18 : 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: i == _index ? FrColors.primary : FrColors.line,
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
