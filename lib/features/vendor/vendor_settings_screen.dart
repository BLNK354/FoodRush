import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import '../../models/user.dart';
import '../../providers/repository.dart';
import '../../shared/widgets.dart';

class VendorSettingsScreen extends ConsumerStatefulWidget {
  const VendorSettingsScreen({super.key});

  @override
  ConsumerState<VendorSettingsScreen> createState() =>
      _VendorSettingsScreenState();
}

class _VendorSettingsScreenState extends ConsumerState<VendorSettingsScreen> {
  Vendor? _vendor;
  bool _loading = true;
  bool _saving = false;

  final _name = TextEditingController();
  final _description = TextEditingController();
  final _gcashNumber = TextEditingController();
  final _gcashName = TextEditingController();
  final _pickupPoint = TextEditingController();
  bool _isOpen = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    _gcashNumber.dispose();
    _gcashName.dispose();
    _pickupPoint.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final vendor = await Repository.instance.getMyVendor();
      if (!mounted) return;
      if (vendor == null) {
        setState(() => _loading = false);
        return;
      }
      setState(() {
        _vendor = vendor;
        _name.text = vendor.name;
        _description.text = vendor.description ?? '';
        _gcashNumber.text = vendor.gcashNumber ?? '';
        _gcashName.text = vendor.gcashName ?? '';
        _pickupPoint.text = vendor.pickupPoint ?? '';
        _isOpen = vendor.isOpen;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      showSnack(context, 'Could not load settings: $e', error: true);
    }
  }

  Future<void> _save() async {
    if (_name.text.trim().isEmpty) {
      showSnack(context, 'Stall name is required.', error: true);
      return;
    }
    setState(() => _saving = true);
    try {
      await Repository.instance.updateMyVendor(
        vendorId: _vendor!.id,
        name: _name.text.trim(),
        description: _description.text.trim(),
        gcashNumber: _gcashNumber.text.trim(),
        gcashName: _gcashName.text.trim(),
        pickupPoint: _pickupPoint.text.trim(),
        isOpen: _isOpen,
      );
      if (!mounted) return;
      showSnack(context, 'Settings saved.');
      await _load();
    } catch (e) {
      if (mounted) showSnack(context, 'Save failed: $e', error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_vendor == null) {
      return const FrPage(
        title: 'Settings',
        children: [
          EmptyState(icon: Icons.storefront_outlined, title: 'No stall found'),
        ],
      );
    }

    return FrPage(
      title: 'Settings',
      subtitle: 'Your stall\'s public profile and payment details.',
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SectionHeader('Stall profile'),
                FrTextField(controller: _name, label: 'Stall name'),
                const SizedBox(height: 14),
                FrTextField(
                  controller: _description,
                  label: 'Description',
                  maxLines: 3,
                ),
                const SizedBox(height: 14),
                FrTextField(
                  controller: _pickupPoint,
                  label: 'Pickup point',
                  hint: 'e.g. Canteen Gate 2, beside the flagpole',
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SectionHeader('GCash details'),
                Text(
                  'Customers see this when they choose GCash at checkout. '
                  'Leave blank to use the FoodRush platform GCash.',
                  style: const TextStyle(color: FrColors.muted, fontSize: 13),
                ),
                const SizedBox(height: 14),
                FrTextField(
                  controller: _gcashNumber,
                  label: 'GCash mobile number',
                  keyboardType: TextInputType.phone,
                  hint: '09XXXXXXXXX',
                ),
                const SizedBox(height: 14),
                FrTextField(
                  controller: _gcashName,
                  label: 'GCash account name',
                  hint: 'Name registered in GCash',
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        Card(
          child: SwitchListTile(
            title: const Text('Stall is open',
                style: TextStyle(fontWeight: FontWeight.w800)),
            subtitle: const Text(
                'Open stalls appear in the customer shop. Closed stalls accept no new orders.'),
            value: _isOpen,
            onChanged: (v) => setState(() => _isOpen = v),
          ),
        ),
        const SizedBox(height: 24),
        FilledButton(
          onPressed: _saving ? null : _save,
          style: FilledButton.styleFrom(minimumSize: const Size(0, 50)),
          child: _saving
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white))
              : const Text('Save settings'),
        ),
        const SizedBox(height: 40),
      ],
    );
  }
}
