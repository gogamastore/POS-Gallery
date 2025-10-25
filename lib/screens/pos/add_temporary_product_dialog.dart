import 'package:cloud_firestore/cloud_firestore.dart'; // Impor untuk Timestamp
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/product.dart';
import '../../providers/pos_provider.dart';

class AddTemporaryProductDialog extends ConsumerStatefulWidget {
  const AddTemporaryProductDialog({super.key});

  @override
  AddTemporaryProductDialogState createState() =>
      AddTemporaryProductDialogState();
}

class AddTemporaryProductDialogState extends ConsumerState<AddTemporaryProductDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _priceController = TextEditingController();
  final _quantityController = TextEditingController(text: '1');

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    _quantityController.dispose();
    super.dispose();
  }

  void _submit() {
    if (_formKey.currentState!.validate()) {
      final name = _nameController.text;
      final price = double.tryParse(_priceController.text) ?? 0.0;
      final quantity = int.tryParse(_quantityController.text) ?? 1;

      // PERBAIKAN: Membuat produk sementara dengan parameter yang benar
      final tempProduct = Product(
        id: 'temp_${DateTime.now().millisecondsSinceEpoch}', // ID unik sementara
        name: name,
        price: price,
        stock: quantity, // Stok dianggap sama dengan jumlah yang dibeli
        sku: 'N/A',
        image: '', 
        description: 'Produk non-katalog',
        // PERBAIKAN: Menggunakan Timestamp.now() untuk createdAt dan updatedAt
        createdAt: Timestamp.now(), 
        updatedAt: Timestamp.now(),
      );

      // Menambahkan ke keranjang
      ref.read(posCartProvider.notifier).addItem(tempProduct, quantity, price);

      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Tambah Produk Non-Katalog'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Nama Produk'),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Nama produk tidak boleh kosong.';
                }
                return null;
              },
            ),
            TextFormField(
              controller: _priceController,
              decoration: const InputDecoration(labelText: 'Harga Jual'),
              keyboardType: TextInputType.number,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Harga tidak boleh kosong.';
                }
                if (double.tryParse(value) == null) {
                  return 'Masukkan harga yang valid.';
                }
                return null;
              },
            ),
            TextFormField(
              controller: _quantityController,
              decoration: const InputDecoration(labelText: 'Jumlah'),
              keyboardType: TextInputType.number,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Jumlah tidak boleh kosong.';
                }
                if (int.tryParse(value) == null || int.parse(value) < 1) {
                  return 'Masukkan jumlah yang valid (minimal 1).';
                }
                return null;
              },
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
