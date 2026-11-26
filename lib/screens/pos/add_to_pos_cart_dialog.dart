
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../models/product.dart';
import '../../models/promotion_model.dart';
import '../../providers/pos_provider.dart';

class AddToPosCartDialog extends ConsumerStatefulWidget {
  final Product product;
  final Promotion? activePromo;

  const AddToPosCartDialog({super.key, required this.product, this.activePromo});

  @override
  AddToPosCartDialogState createState() => AddToPosCartDialogState();
}

class AddToPosCartDialogState extends ConsumerState<AddToPosCartDialog> {
  final _formKey = GlobalKey<FormState>();
  int _quantity = 1;
  late double _sellingPrice;
  // Harga jual yang sedang diketik (untuk peringatan "di bawah modal" live).
  late double _livePrice;

  final _currencyFormatter =
      NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);

  // Harga modal acuan: utamakan harga beli terakhir, jatuh ke rata-rata.
  double get _cost {
    final last = widget.product.lastPurchasePrice ?? 0;
    if (last > 0) return last;
    return widget.product.purchasePrice ?? 0;
  }

  bool get _isBelowCost => _cost > 0 && _livePrice < _cost;

  @override
  void initState() {
    super.initState();
    _sellingPrice = widget.activePromo?.discountPrice ?? widget.product.price;
    _livePrice = _sellingPrice;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();

    // Harga jual di bawah modal → minta konfirmasi dulu (meniru POS validasi
    // di gogama_office).
    if (_cost > 0 && _sellingPrice < _cost) {
      final proceed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Peringatan Harga Jual'),
          content: Text(
              'Harga jual (${_currencyFormatter.format(_sellingPrice)}) di bawah harga modal (${_currencyFormatter.format(_cost)}). Apakah Anda yakin ingin melanjutkan?'),
          actions: [
            TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('Tidak')),
            ElevatedButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                child: const Text('Ya, Yakin')),
          ],
        ),
      );
      if (proceed != true) return;
    }

    ref.read(posCartProvider.notifier).addItem(
          widget.product,
          _quantity,
          _sellingPrice,
        );

    if (!mounted) return;
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${widget.product.name} ditambahkan ke keranjang penjualan.')),
    );
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
            if (_cost > 0) ...[
              const SizedBox(height: 4),
              Text('Harga Modal: ${_currencyFormatter.format(_cost)}',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
            ],
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
                // PENGAMAN STOK: perhitungkan jumlah yang SUDAH ada di keranjang
                // (addItem menambah, bukan mengganti) agar tak melebihi stok.
                final inCart = ref
                    .read(posCartProvider)
                    .where((it) => it.product.id == widget.product.id)
                    .fold<int>(0, (s, it) => s + it.quantity);
                final available = widget.product.stock - inCart;
                if (requestedQuantity > available) {
                  return available <= 0
                      ? 'Stok habis (semua ${widget.product.stock} sudah di keranjang).'
                      : 'Stok tidak cukup. Bisa ditambah $available lagi (stok ${widget.product.stock}, di keranjang $inCart).';
                }
                return null;
              },
              onSaved: (value) => _quantity = int.parse(value!),
            ),
            const SizedBox(height: 16),
            TextFormField(
              key: Key(_sellingPrice.toString()),
              initialValue: _sellingPrice.toStringAsFixed(0),
              decoration: const InputDecoration(
                  labelText: 'Harga Jual per Unit', prefixText: 'Rp ', border: OutlineInputBorder()),
              keyboardType: const TextInputType.numberWithOptions(decimal: false),
              onChanged: (value) {
                final v = double.tryParse(value.replaceAll('.', ''));
                setState(() => _livePrice = v ?? 0);
              },
              validator: (value) {
                if (value == null ||
                    double.tryParse(value.replaceAll('.', '')) == null ||
                    double.parse(value.replaceAll('.', '')) < 0) {
                  return 'Masukkan harga yang valid.';
                }
                return null;
              },
              onSaved: (value) => _sellingPrice = double.parse(value!.replaceAll('.', '')),
            ),
            if (_isBelowCost)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Row(
                  children: [
                    const Icon(Icons.warning_amber_rounded,
                        color: Colors.red, size: 18),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Harga jual di bawah harga modal (${_currencyFormatter.format(_cost)})!',
                        style: const TextStyle(
                            color: Colors.red,
                            fontWeight: FontWeight.bold,
                            fontSize: 12.5),
                      ),
                    ),
                  ],
                ),
              ),
            if (widget.activePromo != null)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Text(
                  'Harga promo diterapkan!',
                  style: TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.bold),
                ),
              )
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
