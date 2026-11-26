import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/product.dart';
import '../../models/staff_model.dart';
import '../../models/stock_movement.dart'; // DIPERBARUI: Impor enum yang benar
import '../../services/staff_service.dart';

class StockAdjustmentDialog extends ConsumerStatefulWidget {
  final Product product;

  const StockAdjustmentDialog({super.key, required this.product});

  @override
  ConsumerState<StockAdjustmentDialog> createState() => _StockAdjustmentDialogState();
}

class _StockAdjustmentDialogState extends ConsumerState<StockAdjustmentDialog> {
  // DIPERBARUI: Menggunakan enum StockMovementType yang benar
  StockMovementType _adjustmentType = StockMovementType.adjustmentIn;
  final _quantityController = TextEditingController(text: '1');
  final _reasonController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  // Nama kasir/admin yang dipilih (seperti dropdown di halaman validasi).
  String? _selectedStaffName;
  String? _selectedStaffId;

  @override
  void dispose() {
    _quantityController.dispose();
    _reasonController.dispose();
    super.dispose();
  }

  void _submit() {
    if (_formKey.currentState!.validate()) {
      final quantity = int.tryParse(_quantityController.text) ?? 0;
      final reason = _reasonController.text;

      // Mengirim kembali enum yang sudah benar
      Navigator.of(context).pop({
        'type': _adjustmentType,
        'quantity': quantity,
        'reason': reason,
        'adjustedByName': _selectedStaffName,
        'adjustedById': _selectedStaffId,
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final staffAsync = ref.watch(staffStreamProvider);
    return AlertDialog(
      title: const Text('Penyesuaian Stok'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(widget.product.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 8),
              Text('Stok saat ini: ${widget.product.stock}', style: TextStyle(color: Colors.grey.shade600)),
              const SizedBox(height: 24),

              // DIPERBARUI: Menggunakan enum StockMovementType
              RadioListTile<StockMovementType>(
                title: const Text('Stok Masuk'),
                value: StockMovementType.adjustmentIn,
                groupValue: _adjustmentType,
                onChanged: (value) => setState(() => _adjustmentType = value!),
                activeColor: Colors.green,
              ),
              RadioListTile<StockMovementType>(
                title: const Text('Stok Keluar'),
                value: StockMovementType.adjustmentOut,
                groupValue: _adjustmentType,
                onChanged: (value) => setState(() => _adjustmentType = value!),
                activeColor: Colors.red,
              ),
              const SizedBox(height: 24),

              TextFormField(
                controller: _quantityController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Jumlah',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) return 'Jumlah tidak boleh kosong';
                  final val = int.tryParse(value);
                  if (val == null || val <= 0) return 'Jumlah harus lebih dari 0';
                  // DIPERBARUI: Menggunakan enum yang benar untuk validasi
                  if (_adjustmentType == StockMovementType.adjustmentOut && val > widget.product.stock) {
                    return 'Stok keluar melebihi stok saat ini';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _reasonController,
                decoration: const InputDecoration(
                  labelText: 'Alasan Penyesuaian',
                  hintText: 'Contoh: Stok opname, barang rusak...',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) return 'Alasan tidak boleh kosong';
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Pilih nama kasir/admin yang menyesuaikan (seperti halaman
              // validasi) — wajib sebelum menyimpan.
              staffAsync.when(
                data: (staffList) {
                  final sorted = [...staffList]
                    ..sort((a, b) => a.name.compareTo(b.name));
                  return DropdownButtonFormField<String>(
                    initialValue: _selectedStaffName,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Disesuaikan oleh',
                      border: OutlineInputBorder(),
                    ),
                    hint: const Text('Pilih nama kasir/admin...'),
                    items: sorted
                        .map<DropdownMenuItem<String>>((Staff s) =>
                            DropdownMenuItem<String>(
                              value: s.name,
                              child: Text(s.name),
                            ))
                        .toList(),
                    onChanged: (value) {
                      setState(() {
                        _selectedStaffName = value;
                        final match = sorted.where((s) => s.name == value);
                        _selectedStaffId =
                            match.isNotEmpty ? match.first.id : null;
                      });
                    },
                    validator: (value) => value == null || value.isEmpty
                        ? 'Harap pilih nama kasir/admin'
                        : null,
                  );
                },
                loading: () => const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (e, s) => Text('Gagal memuat daftar staf: $e',
                    style: const TextStyle(color: Colors.red)),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Batal')),
        ElevatedButton(
          onPressed: _submit,
          style: ElevatedButton.styleFrom(
            // DIPERBARUI: Menggunakan enum yang benar untuk warna tombol
            backgroundColor: _adjustmentType == StockMovementType.adjustmentIn ? Colors.green : Colors.red,
            foregroundColor: Colors.white,
          ),
          child: const Text('Simpan'),
        ),
      ],
    );
  }
}
