import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants.dart';
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

  /// Picked but not yet saved logo; [_removeLogo] clears the saved one.
  Uint8List? _newLogo;
  String? _newLogoName;
  bool _removeLogo = false;

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
        _newLogo = null;
        _newLogoName = null;
        _removeLogo = false;
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
      String? logoUrl;
      final logo = _newLogo;
      if (logo != null) {
        // Small: every stall's logo is loaded with the shop list.
        logoUrl = await Repository.instance.uploadImage(
          pathPrefix: kPathVendorLogos,
          bytes: logo,
          fileName: _newLogoName ?? 'logo.png',
          maxDim: 256,
          quality: 80,
        );
      }
      await Repository.instance.updateMyVendor(
        vendorId: _vendor!.id,
        name: _name.text.trim(),
        description: _description.text.trim(),
        gcashNumber: _gcashNumber.text.trim(),
        gcashName: _gcashName.text.trim(),
        pickupPoint: _pickupPoint.text.trim(),
        isOpen: _isOpen,
        logoUrl: logoUrl,
        removeLogo: _removeLogo,
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

  Future<void> _pickLogo() async {
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.image,
      withData: true,
    );
    final f = picked?.files.single;
    final bytes = f?.bytes;
    if (f == null || bytes == null) return;
    setState(() {
      _newLogo = bytes;
      _newLogoName = f.name;
      _removeLogo = false;
    });
  }

  Widget _logoPicker() {
    final saved = _removeLogo ? null : _vendor?.logoUrl;
    final hasLogo = _newLogo != null || saved != null;
    return Row(
      children: [
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            color: FrColors.cream,
            borderRadius: BorderRadius.circular(FrRadius.lg),
          ),
          clipBehavior: Clip.antiAlias,
          child: _newLogo != null
              ? Image.memory(_newLogo!, fit: BoxFit.cover)
              : saved != null
                  ? FrImage(saved)
                  : const Icon(Icons.storefront,
                      color: FrColors.muted, size: 32),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              OutlinedButton.icon(
                onPressed: _saving ? null : _pickLogo,
                icon: const Icon(Icons.upload),
                label: Text(hasLogo ? 'Change logo' : 'Upload logo'),
              ),
              if (hasLogo)
                TextButton(
                  onPressed: _saving
                      ? null
                      : () => setState(() {
                            _newLogo = null;
                            _newLogoName = null;
                            _removeLogo = true;
                          }),
                  child: const Text('Remove'),
                ),
              if (_newLogo != null || _removeLogo)
                const Text('Save settings to apply.',
                    style: TextStyle(color: FrColors.muted, fontSize: 12)),
            ],
          ),
        ),
      ],
    );
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
                _logoPicker(),
                const SizedBox(height: 18),
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
