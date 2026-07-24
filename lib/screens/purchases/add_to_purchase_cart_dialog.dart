import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/product.dart';
import '../../providers/purchase_provider.dart';

class AddToPurchaseCartDialog extends ConsumerStatefulWidget {
  final Product product;

  const AddToPurchaseCartDialog({super.key, required this.product});

  @override
  AddToPurchaseCartDialogState createState() => AddToPurchaseCartDialogState();
}

class AddToPurchaseCartDialogState extends ConsumerState<AddToPurchaseCartDialog> {
  final _formKey = GlobalKey<FormState>();
  int _quantity = 1;
  late double _purchasePrice;

  @override
  void initState() {
    super.initState();
    _purchasePrice = widget.product.lastPurchasePrice ?? 0.0;
  }

  void _submit() {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();

      ref.read(purchaseCartProvider.notifier).addItem(
            widget.product,
            _quantity,
            _purchasePrice,
          );

      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${widget.product.name} ditambahkan ke keranjang pembelian.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return AlertDialog(
      // --- PERUBAHAN: Menggunakan style yang lebih kecil untuk judul dialog ---
      title: Text('Tambah ke Keranjang', style: textTheme.titleLarge),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- PERUBAHAN: Menggunakan style yang lebih normal untuk nama produk ---
            Text(widget.product.name, style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 24),
            TextFormField(
              initialValue: _quantity.toString(),
              decoration: const InputDecoration(labelText: 'Jumlah', border: OutlineInputBorder()),
              keyboardType: TextInputType.number,
              validator: (value) {
                if (value == null || int.tryParse(value) == null || int.parse(value) <= 0) {
                  return 'Masukkan jumlah yang valid.';
                }
                return null;
              },
              onSaved: (value) => _quantity = int.parse(value!),
            ),
            const SizedBox(height: 16),
            TextFormField(
              key: Key(_purchasePrice.toString()),
              initialValue: _purchasePrice.toStringAsFixed(0), // Menghilangkan desimal untuk harga
              decoration: const InputDecoration(labelText: 'Harga Beli per Unit', prefixText: 'Rp ', border: OutlineInputBorder()),
              keyboardType: const TextInputType.numberWithOptions(decimal: false), // Keyboard angka saja
              validator: (value) {
                if (value == null || double.tryParse(value.replaceAll('.', '')) == null || double.parse(value.replaceAll('.', '')) < 0) {
                  return 'Masukkan harga yang valid.';
                }
                return null;
              },
              onSaved: (value) => _purchasePrice = double.parse(value!.replaceAll('.', '')),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Batal')),
        ElevatedButton(onPressed: _submit, child: const Text('Tambah')),
      ],
    );
  }
}
