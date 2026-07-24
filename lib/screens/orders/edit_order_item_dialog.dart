import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/order_item.dart';

class EditOrderItemDialog extends StatefulWidget {
  final OrderItem product;

  const EditOrderItemDialog({super.key, required this.product});

  @override
  State<EditOrderItemDialog> createState() => _EditOrderItemDialogState();
}

class _EditOrderItemDialogState extends State<EditOrderItemDialog> {
  late final TextEditingController _priceController;
  late int _quantity;

  @override
  void initState() {
    super.initState();
    _priceController = TextEditingController(
      text: widget.product.price.toStringAsFixed(0),
    );
    _quantity = widget.product.quantity;
  }

  @override
  void dispose() {
    _priceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currencyFormatter = NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    );

    return AlertDialog(
      title: Text('Edit ${widget.product.name}'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _priceController,
            decoration: const InputDecoration(
              labelText: 'Harga Jual Satuan',
              prefixText: 'Rp ',
            ),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Jumlah', style: TextStyle(fontSize: 16)),
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.remove_circle_outline),
                    onPressed: () {
                      if (_quantity > 1) {
                        setState(() => _quantity--);
                      }
                    },
                  ),
                  Text('$_quantity', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  IconButton(
                    icon: const Icon(Icons.add_circle_outline),
                    onPressed: () {
                      setState(() => _quantity++);
                    },
                  ),
                ],
              )
            ],
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Subtotal', style: TextStyle(fontWeight: FontWeight.bold)),
              Text(
                currencyFormatter.format((double.tryParse(_priceController.text) ?? 0) * _quantity),
                style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue),
              ),
            ],
          )
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Batal'),
        ),
        ElevatedButton(
          onPressed: () {
            final newPrice = double.tryParse(_priceController.text) ?? widget.product.price;
            Navigator.of(context).pop({
              'quantity': _quantity,
              'price': newPrice,
            });
          },
          child: const Text('Simpan'),
        ),
      ],
    );
  }
}
