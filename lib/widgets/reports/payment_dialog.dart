import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:myapp/models/purchase.dart';
import 'package:myapp/services/report_service.dart';

class PaymentDialog extends StatefulWidget {
  final Purchase transaction;
  final VoidCallback onPaymentSuccess;

  const PaymentDialog({
    super.key,
    required this.transaction,
    required this.onPaymentSuccess,
  });

  @override
  State<PaymentDialog> createState() => _PaymentDialogState();
}

class _PaymentDialogState extends State<PaymentDialog> {
  final _reportService = ReportService();
  bool _isSubmitting = false;
  String _paymentMethod = 'cash'; // Default value
  final _descriptionController = TextEditingController();

  Future<void> _handleProcessPayment() async {
    if (_isSubmitting) return;

    setState(() {
      _isSubmitting = true;
    });

    try {
      await _reportService.processPurchasePayment(
        purchaseId: widget.transaction.id,
        paymentMethod: _paymentMethod,
        notes: _descriptionController.text,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pembayaran Berhasil!'),
          backgroundColor: Colors.green,
        ),
      );

      widget.onPaymentSuccess(); // Panggil callback untuk refresh
      Navigator.of(context).pop(); // Tutup dialog pembayaran

    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal memproses pembayaran: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currencyFormatter = NumberFormat.currency(
        locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);

    return AlertDialog(
      title: const Text('Pembayaran Utang Pembelian'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('ID Transaksi: ${widget.transaction.id}'),
            const SizedBox(height: 16),
            Center(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    const Text('Total Tagihan', style: TextStyle(color: Colors.grey)),
                    Text(
                      currencyFormatter.format(widget.transaction.totalAmount),
                      style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            const Text('Metode Pembayaran', style: TextStyle(fontWeight: FontWeight.bold)),
            RadioListTile<String>(
              title: const Text('Cash'),
              value: 'cash',
              groupValue: _paymentMethod,
              onChanged: (value) {
                if (value != null) setState(() => _paymentMethod = value);
              },
            ),
            RadioListTile<String>(
              title: const Text('Transfer Bank'),
              value: 'bank_transfer',
              groupValue: _paymentMethod,
              onChanged: (value) {
                if (value != null) setState(() => _paymentMethod = value);
              },
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: 'Keterangan (Opsional)',
                border: OutlineInputBorder(),
              ),
              textCapitalization: TextCapitalization.sentences,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Batal'),
        ),
        ElevatedButton(
          onPressed: _isSubmitting ? null : _handleProcessPayment,
          child: _isSubmitting
              ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Proses Pembayaran'),
        ),
      ],
    );
  }
}
