import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ionicons/ionicons.dart';

import '../../models/purchase_cart_item.dart';
import '../../providers/purchase_provider.dart';

class EditPurchaseCartItemDialog extends ConsumerStatefulWidget {
  final PurchaseCartItem cartItem;

  const EditPurchaseCartItemDialog({super.key, required this.cartItem});

  @override
  ConsumerState<EditPurchaseCartItemDialog> createState() => _EditPurchaseCartItemDialogState();
}

class _EditPurchaseCartItemDialogState extends ConsumerState<EditPurchaseCartItemDialog> {
  final _formKey = GlobalKey<FormState>();
  late int _quantity;
  late double _purchasePrice;
  final _priceController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _quantity = widget.cartItem.quantity;
    _purchasePrice = widget.cartItem.purchasePrice;
    _priceController.text = _purchasePrice.toStringAsFixed(0); // Menghilangkan desimal
  }

  @override
  void dispose() {
    _priceController.dispose();
    super.dispose();
  }

  void _submit() {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();
      // --- PERBAIKAN: Gunakan metode `updateItem` yang baru dan efisien ---
      ref.read(purchaseCartProvider.notifier).updateItem(
        widget.cartItem.product.id, 
        newQuantity: _quantity, 
        newPrice: _purchasePrice,
      );
      if (mounted) Navigator.of(context).pop();
    }
  }

  void _delete() {
    ref.read(purchaseCartProvider.notifier).removeItem(widget.cartItem.product.id);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text('Edit Item', style: TextStyle(fontWeight: FontWeight.bold)),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.cartItem.product.name, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 18)),
            const SizedBox(height: 24),
            TextFormField(
              initialValue: _quantity.toString(),
              decoration: const InputDecoration(
                labelText: 'Jumlah', 
                border: OutlineInputBorder(),
                prefixIcon: Icon(Ionicons.cube_outline),
              ),
              keyboardType: TextInputType.number,
              validator: (value) {
                if (value == null || value.isEmpty) return 'Jumlah tidak boleh kosong';
                if (int.tryParse(value) == null || int.parse(value) <= 0) {
                  return 'Masukkan jumlah yang valid';
                }
                return null;
              },
              onSaved: (value) => _quantity = int.parse(value!),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _priceController,
              decoration: const InputDecoration(
                labelText: 'Harga Beli per Item',
                prefixText: 'Rp ', 
                border: OutlineInputBorder(),
                prefixIcon: Icon(Ionicons.cash_outline),
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: false),
              validator: (value) {
                if (value == null || value.isEmpty) return 'Harga tidak boleh kosong';
                // Hapus pemisah ribuan sebelum parsing
                final cleanValue = value.replaceAll('.', '');
                if (double.tryParse(cleanValue) == null) return 'Format harga tidak valid';
                return null;
              },
              onSaved: (value) {
                final cleanValue = value!.replaceAll('.', '');
                _purchasePrice = double.parse(cleanValue);
              },
            ),
          ],
        ),
      ),
      actionsAlignment: MainAxisAlignment.spaceBetween,
      actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      actions: [
        TextButton.icon(
          icon: const Icon(Ionicons.trash_outline),
          label: const Text('Hapus'),
          onPressed: _delete,
          style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
          
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
             TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Batal')),
             const SizedBox(width: 8),
             ElevatedButton(onPressed: _submit, child: const Text('Simpan')),
          ],
        ),
      ],
    );
  }
}
