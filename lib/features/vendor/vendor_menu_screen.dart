import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';

import '../../core/constants.dart';
import '../../core/theme.dart';
import '../../models/product.dart';
import '../../models/user.dart';
import '../../providers/repository.dart';
import '../../shared/widgets.dart';

class VendorMenuScreen extends ConsumerStatefulWidget {
  const VendorMenuScreen({super.key});

  @override
  ConsumerState<VendorMenuScreen> createState() => _VendorMenuScreenState();
}

class _VendorMenuScreenState extends ConsumerState<VendorMenuScreen> {
  Vendor? _vendor;
  List<Product> _products = [];
  List<ProductCategory> _categories = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final vendor = await Repository.instance.getMyVendor();
      if (vendor == null) {
        if (!mounted) return;
        setState(() {
          _loading = false;
        });
        showSnack(context, 'No stall found for your account.', error: true);
        return;
      }
      final products = await Repository.instance.listProducts(vendor.id);
      final cats = await Repository.instance.listCategories(vendor.id);
      if (!mounted) return;
      setState(() {
        _vendor = vendor;
        _products = products;
        _categories = cats;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      showSnack(context, 'Could not load menu: $e', error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FrPage(
      title: 'Menu',
      subtitle: 'What students can order from your stall.',
      actions: [
        IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
        FilledButton.icon(
          onPressed: _vendor == null ? null : () => _editProduct(null),
          icon: const Icon(Icons.add),
          label: const Text('Add product'),
        ),
      ],
      children: [
        if (_loading && _products.isEmpty)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(48),
              child: CircularProgressIndicator(),
            ),
          )
        else if (_vendor == null)
          const EmptyState(icon: Icons.storefront_outlined, title: 'No stall found')
        else ...[
          // Categories row
          SectionHeader(
            'Categories',
            trailing: TextButton.icon(
              onPressed: _manageCategories,
              icon: const Icon(Icons.category, size: 18),
              label: const Text('Manage'),
            ),
          ),
          Wrap(
            spacing: 8,
            children: [
              for (final c in _categories)
                Chip(label: Text(c.name)),
              if (_categories.isEmpty)
                const Text('No categories — products are fine without them.',
                    style: TextStyle(color: FrColors.muted, fontSize: 13)),
            ],
          ),
          const SizedBox(height: 20),
          SectionHeader('Products (${_products.length})'),
          if (_products.isEmpty)
            const EmptyState(
              icon: Icons.restaurant_menu,
              title: 'No products yet',
              message: 'Add your first product to start taking orders.',
            )
          else
            ..._products.map(_productTile),
        ],
        const SizedBox(height: 40),
      ],
    );
  }

  Widget _productTile(Product p) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: FrColors.cream,
            borderRadius: BorderRadius.circular(FrRadius.md),
          ),
          clipBehavior: Clip.antiAlias,
          child: p.imageUrl != null
              ? FrImage(p.imageUrl)
              : const Icon(Icons.fastfood, color: FrColors.secondary),
        ),
        title: Text(p.name,
            style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text(
          '${peso(p.price)}'
          '${p.stockQty != null ? ' · ${p.stockQty} in stock' : ''}'
          '${p.categoryId != null ? ' · ${_catName(p.categoryId)}' : ''}',
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              p.isAvailable ? 'Available' : 'Hidden',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: p.isAvailable ? FrColors.success : FrColors.muted,
              ),
            ),
            Switch(
              value: p.isAvailable,
              onChanged: (_) => _toggleAvailability(p),
            ),
            IconButton(
              icon: const Icon(Icons.edit_outlined, size: 20),
              onPressed: () => _editProduct(p),
              tooltip: 'Edit',
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline,
                  size: 20, color: FrColors.danger),
              onPressed: () => _deleteProduct(p),
              tooltip: 'Delete',
            ),
          ],
        ),
      ),
    );
  }

  String _catName(String? id) {
    if (id == null) return '';
    for (final c in _categories) {
      if (c.id == id) return c.name;
    }
    return '';
  }

  Future<void> _toggleAvailability(Product p) async {
    try {
      await Repository.instance.upsertProduct(
        id: p.id,
        vendorId: p.vendorId,
        name: p.name,
        description: p.description,
        price: p.price,
        imageUrl: p.imageUrl,
        isAvailable: !p.isAvailable,
        stockQty: p.stockQty,
        categoryId: p.categoryId,
      );
      await _load();
    } catch (e) {
      if (mounted) showSnack(context, 'Update failed: $e', error: true);
    }
  }

  Future<void> _deleteProduct(Product p) async {
    final ok = await confirmDialog(
      context,
      title: 'Delete ${p.name}?',
      message: 'Past orders keep their records, but the product disappears from your menu.',
      confirmLabel: 'Delete',
      destructive: true,
    );
    if (!ok) return;
    try {
      await Repository.instance.deleteProduct(p.vendorId, p.id);
      await _load();
    } catch (e) {
      if (mounted) showSnack(context, 'Delete failed: $e', error: true);
    }
  }

  Future<void> _editProduct(Product? existing) async {
    final name = TextEditingController(text: existing?.name ?? '');
    final desc = TextEditingController(text: existing?.description ?? '');
    final price = TextEditingController(
        text: existing == null ? '' : existing.price.toStringAsFixed(2));
    final stock = TextEditingController(
        text: existing?.stockQty?.toString() ?? '');
    String? categoryId = existing?.categoryId;
    String? imageUrl = existing?.imageUrl;
    bool available = existing?.isAvailable ?? true;
    Uint8List? newImageBytes;
    String? newImageName;

    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
        final currentImage = newImageBytes;
        return AlertDialog(
          title: Text(existing == null ? 'Add product' : 'Edit product'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: name,
                  decoration: const InputDecoration(labelText: 'Product name'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: desc,
                  decoration:
                      const InputDecoration(labelText: 'Description (optional)'),
                  maxLines: 2,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: price,
                        keyboardType: TextInputType.number,
                        decoration:
                            const InputDecoration(labelText: 'Price (₱)'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: stock,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                            labelText: 'Stock (optional)'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String?>(
                  initialValue: categoryId,
                  decoration:
                      const InputDecoration(labelText: 'Category (optional)'),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('None')),
                    for (final c in _categories)
                      DropdownMenuItem(value: c.id, child: Text(c.name)),
                  ],
                  onChanged: (v) => setDialogState(() => categoryId = v),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: FrColors.cream,
                        borderRadius: BorderRadius.circular(FrRadius.md),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: currentImage != null
                          ? Image.memory(currentImage, fit: BoxFit.cover)
                          : (imageUrl != null
                              ? FrImage(imageUrl)
                              : const Icon(Icons.image,
                                  color: FrColors.muted)),
                    ),
                    const SizedBox(width: 10),
                    OutlinedButton(
                      onPressed: () async {
                        final picked = await FilePicker.platform.pickFiles(
                          type: FileType.image,
                          withData: true,
                        );
                        final f = picked?.files.single;
                        final bytes = f?.bytes;
                        if (f != null && bytes != null) {
                          setDialogState(() {
                            newImageBytes = bytes;
                            newImageName = f.name;
                          });
                        }
                      },
                      child: const Text('Upload photo'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Available for ordering'),
                  value: available,
                  onChanged: (v) => setDialogState(() => available = v),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Save'),
            ),
          ],
        );
        },
      ),
    );
    if (saved != true) return;

    final priceValue = double.tryParse(price.text.trim());
    if (name.text.trim().isEmpty || priceValue == null) {
      if (mounted) {
        showSnack(context, 'Name and a valid price are required.', error: true);
      }
      return;
    }

    try {
      String? finalImage = imageUrl;
      if (newImageBytes != null) {
        finalImage = await Repository.instance.uploadImage(
          pathPrefix: kPathProductImages,
          bytes: newImageBytes!,
          fileName: newImageName ?? 'product.png',
        );
      }
      await Repository.instance.upsertProduct(
        id: existing?.id,
        vendorId: _vendor!.id,
        name: name.text.trim(),
        description: desc.text.trim().isEmpty ? null : desc.text.trim(),
        price: priceValue,
        imageUrl: finalImage,
        isAvailable: available,
        stockQty: int.tryParse(stock.text.trim()),
        categoryId: categoryId,
      );
      if (mounted) showSnack(context, 'Product saved.');
      await _load();
    } catch (e) {
      if (mounted) showSnack(context, 'Save failed: $e', error: true);
    }
  }

  Future<void> _manageCategories() async {
    final nameCtrl = TextEditingController();
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Categories'),
        content: SizedBox(
          width: 360,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_categories.isEmpty)
                const Text('No categories yet.',
                    style: TextStyle(color: FrColors.muted)),
              for (final c in _categories)
                ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: Text(c.name),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline,
                        size: 20, color: FrColors.danger),
                    onPressed: () async {
                      try {
                        await Repository.instance
                            .deleteCategory(_vendor!.id, c.id);
                        if (context.mounted) Navigator.pop(context);
                        await _load();
                      } catch (e) {
                        if (context.mounted) {
                          showSnack(context, 'Delete failed: $e', error: true);
                        }
                      }
                    },
                  ),
                ),
              const SizedBox(height: 8),
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(
                    labelText: 'New category name'),
                onSubmitted: (_) {},
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          FilledButton(
            onPressed: () async {
              if (nameCtrl.text.trim().isEmpty || _vendor == null) return;
              try {
                await Repository.instance.addCategory(
                  vendorId: _vendor!.id,
                  name: nameCtrl.text.trim(),
                  sort: _categories.length,
                );
                nameCtrl.clear();
                if (context.mounted) Navigator.pop(context);
                await _load();
              } catch (e) {
                if (context.mounted) {
                  showSnack(context, 'Save failed: $e', error: true);
                }
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }
}
