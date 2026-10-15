
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants.dart';
import '../../core/theme.dart';
import '../../models/user.dart';
import '../../providers/repository.dart';
import '../../shared/validation.dart';
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

  /// Weekly schedule being edited; only saved when [_useSchedule].
  Map<int, DayHours> _hours = {};
  bool _useSchedule = false;
  final _prep = TextEditingController();

  /// Mon-Fri 7:00 AM-5:00 PM, the starting point when hours are switched on.
  static final _defaultHours = {
    for (var d = 1; d <= 5; d++) d: const DayHours(7 * 60, 17 * 60),
  };

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
    _prep.dispose();
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
        _hours = Map.of(vendor.hours);
        _useSchedule = vendor.hasSchedule;
        _prep.text = '${vendor.prepMinutes}';
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
    final err = firstError([
      validateText(_name.text,
          max: Limits.name, required: true, min: 2, label: 'Stall name'),
      validateText(_description.text, max: Limits.description, label: 'Description'),
      validateText(_pickupPoint.text, max: Limits.pickupPoint, label: 'Pickup point'),
      validatePhone(_gcashNumber.text, label: 'GCash number'),
      _gcashName.text.trim().isEmpty ? null : validatePersonName(_gcashName.text),
      validateWholeNumber(_prep.text,
          min: 1, max: 120, required: true, label: 'Prep time'),
    ]);
    if (err != null) {
      showSnack(context, err, error: true);
      return;
    }
    final prep = int.tryParse(_prep.text.trim());
    if (prep == null || prep < 1 || prep > 120) {
      showSnack(context, 'Prep time must be 1 to 120 minutes.', error: true);
      return;
    }
    if (_useSchedule && _hours.isEmpty) {
      showSnack(context, 'Open at least one day, or turn opening hours off.',
          error: true);
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
        hours: _useSchedule ? _hours : const {},
        prepMinutes: prep,
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

  Future<void> _pickTime(int day, bool open) async {
    final h = _hours[day]!;
    final current = open ? h.openMinute : h.closeMinute;
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: current ~/ 60, minute: current % 60),
    );
    if (picked == null) return;
    final m = picked.hour * 60 + picked.minute;
    final next = open ? DayHours(m, h.closeMinute) : DayHours(h.openMinute, m);
    if (next.closeMinute <= next.openMinute) {
      if (mounted) {
        showSnack(context, 'Closing time must be after opening time.',
            error: true);
      }
      return;
    }
    setState(() => _hours[day] = next);
  }

  Widget _hoursCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SectionHeader('Opening hours & prep time'),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Use opening hours'),
              subtitle: const Text(
                  'Students can only order while you are open AND inside these '
                  'hours. Off: the open switch alone decides.'),
              value: _useSchedule,
              onChanged: (v) => setState(() {
                _useSchedule = v;
                if (v && _hours.isEmpty) _hours = Map.of(_defaultHours);
              }),
            ),
            if (_useSchedule)
              for (var day = 1; day <= 7; day++)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 56,
                        child: Text(kWeekdayShort[day - 1],
                            style:
                                const TextStyle(fontWeight: FontWeight.w700)),
                      ),
                      Checkbox(
                        value: _hours.containsKey(day),
                        onChanged: (on) => setState(() {
                          if (on == true) {
                            _hours[day] = _hours.values.isNotEmpty
                                ? _hours.values.first
                                : const DayHours(7 * 60, 17 * 60);
                          } else {
                            _hours.remove(day);
                          }
                        }),
                      ),
                      if (_hours[day] == null)
                        Text('Closed',
                            style: TextStyle(color: FrColors.muted))
                      else
                        Expanded(
                          child: Wrap(
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              TextButton(
                                onPressed: () => _pickTime(day, true),
                                child: Text(
                                    fmtMinuteOfDay(_hours[day]!.openMinute)),
                              ),
                              const Text('to'),
                              TextButton(
                                onPressed: () => _pickTime(day, false),
                                child: Text(
                                    fmtMinuteOfDay(_hours[day]!.closeMinute)),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
            const SizedBox(height: 14),
            FrTextField(
              controller: _prep,
              label: 'Average minutes to prepare one order',
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(3),
              ],
              validator: (v) => validateWholeNumber(v,
                  min: 1, max: 120, required: true, label: 'Prep time'),
              hint: 'Used for the "Ready in ~N min" estimate students see',
            ),
          ],
        ),
      ),
    );
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
                  : Icon(Icons.storefront,
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
                Text('Save settings to apply.',
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
                FrTextField(
                  controller: _name,
                  label: 'Stall name',
                  maxLength: Limits.name,
                  validator: (v) => validateText(v,
                      max: Limits.name, required: true, min: 2, label: 'Stall name'),
                ),
                const SizedBox(height: 14),
                FrTextField(
                  controller: _description,
                  label: 'Description',
                  maxLines: 3,
                  maxLength: Limits.description,
                  validator: (v) => validateText(v, max: Limits.description),
                ),
                const SizedBox(height: 14),
                FrTextField(
                  controller: _pickupPoint,
                  label: 'Pickup point',
                  hint: 'e.g. Canteen Gate 2, beside the flagpole',
                  maxLength: Limits.pickupPoint,
                  validator: (v) => validateText(v, max: Limits.pickupPoint),
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
                  style: TextStyle(color: FrColors.muted, fontSize: 13),
                ),
                const SizedBox(height: 14),
                FrTextField(
                  controller: _gcashNumber,
                  label: 'GCash mobile number',
                  keyboardType: TextInputType.phone,
                  hint: '09XXXXXXXXX',
                  maxLength: Limits.phone,
                  validator: (v) => validatePhone(v, label: 'GCash number'),
                ),
                const SizedBox(height: 14),
                FrTextField(
                  controller: _gcashName,
                  label: 'GCash account name',
                  hint: 'Name registered in GCash',
                  maxLength: Limits.name,
                  validator: (v) =>
                      (v ?? '').trim().isEmpty ? null : validatePersonName(v),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        _hoursCard(),
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
