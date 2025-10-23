import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/product.dart';
import '../../providers/pos_provider.dart';

class AddToPosCartDialog extends ConsumerStatefulWidget {
  final Product product;

  const AddToPosCartDialog({super.key, required this.product});

  @override
  AddToPosCartDialogState createState() => AddToPosCartDialogState();
}

class AddToPosCartDialogState extends ConsumerState<AddToPosCartDialog> {
  final _formKey = GlobalKey<FormState>();
  int _quantity = 1;
  late double _sellingPrice;

  @override
  void initState() {
    super.initState();
    _sellingPrice = widget.product.price;
  }

  void _submit() {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();

      ref.read(posCartProvider.notifier).addItem(
            widget.product,
            _quantity,
            _sellingPrice,
          );

      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${widget.product.name} ditambahkan ke keranjang penjualan.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return AlertDialog(
      title: Text('Tambah ke Keranjang', style: textTheme.titleLarge),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
                final int requestedQuantity = int.parse(value);
                if (requestedQuantity > widget.product.stock) {
                  return 'Stok tidak mencukupi. Sisa: ${widget.product.stock}';
                }
                return null;
              },
              onSaved: (value) => _quantity = int.parse(value!),
            ),
            const SizedBox(height: 16),
            TextFormField(
              key: Key(_sellingPrice.toString()),
              initialValue: _sellingPrice.toStringAsFixed(0),
              decoration: const InputDecoration(labelText: 'Harga Jual per Unit', prefixText: 'Rp ', border: OutlineInputBorder()),
              keyboardType: const TextInputType.numberWithOptions(decimal: false),
              validator: (value) {
                if (value == null || double.tryParse(value.replaceAll('.', '')) == null || double.parse(value.replaceAll('.', '')) < 0) {
                  return 'Masukkan harga yang valid.';
                }
                return null;
              },
              onSaved: (value) => _sellingPrice = double.parse(value!.replaceAll('.', '')),
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
