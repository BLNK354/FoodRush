import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants.dart';
import '../../core/theme.dart';

/// Privacy notice (Philippine Data Privacy Act of 2012, RA 10173). Public:
/// linked from sign-up and the profile. A plain-language starting point —
/// have it reviewed before relying on it legally.
class PrivacyScreen extends StatelessWidget {
  const PrivacyScreen({super.key});

  static const _sections = <(String, String)>[
    (
      'What we collect',
      'Your name, email and student number, and (if you add them) your '
          'mobile number and a profile photo. For each order: the items, prices, pickup time, your note '
          'to the stall, and GCash receipt photos you upload. Also your '
          'reviews and favourite stalls.',
    ),
    (
      'Why',
      'Only to run FoodRush: placing and preparing orders, checking GCash '
          'payments, telling you when food is ready, showing reviews, and '
          'keeping each stall\'s sales records. We do not sell your data or '
          'use it for advertising.',
    ),
    (
      'Who can see it',
      'You. The stall you order from sees your name, your profile photo (if '
          'you added one, so they hand your food to the right person), your '
          'order, your note and your receipt. FoodRush administrators can see accounts and '
          'orders to keep the service running. Other students cannot see your '
          'orders or profile. Reviews show your first name and last initial.',
    ),
    (
      'Where it is stored',
      'In Google Firebase (Authentication and Cloud Firestore), which may '
          'store data on servers outside the Philippines. Access is protected '
          'by sign-in and by database security rules.',
    ),
    (
      'How long',
      'Until you delete your account (you can remove your photo any time in '
          'My profile). When you do, your profile, photo, favourites '
          'and login are deleted, and your name is removed from past orders '
          'and reviews (the stall keeps the anonymous sales record).',
    ),
    (
      'Your rights',
      'You can see and correct your details in My profile, and delete your '
          'account there at any time. You may also object to processing or '
          'complain to the National Privacy Commission (privacy.gov.ph).',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Privacy notice'),
        leading: IconButton(
          tooltip: 'Back',
          icon: const Icon(Icons.arrow_back),
          onPressed: () =>
              context.canPop() ? context.pop() : context.go('/'),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('$kAppName privacy notice',
                    style: const TextStyle(
                        fontSize: 22, fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                Text(
                  'How $kAppName handles your personal data, under the '
                  'Philippine Data Privacy Act of 2012 (RA 10173).',
                  style: TextStyle(color: FrColors.muted),
                ),
                for (final (title, body) in _sections) ...[
                  const SizedBox(height: 20),
                  Text(title,
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 6),
                  Text(body, style: const TextStyle(height: 1.5)),
                ],
                if (kSupportEmail.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  const Text('Contact',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 6),
                  const Text('Privacy questions or requests: $kSupportEmail'),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
