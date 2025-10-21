import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'dart:io';
import 'dart:async';
import 'package:firebase_core/firebase_core.dart';

import '../../models/order.dart';
import '../../models/order_item.dart';
import '../../models/staff_model.dart';
import '../../providers/order_provider.dart';
import '../../services/staff_service.dart';

class ValidatedOrderSummaryScreen extends ConsumerStatefulWidget {
  final Order originalOrder;
  final List<OrderItem> validatedItems;

  const ValidatedOrderSummaryScreen({
    super.key,
    required this.originalOrder,
    required this.validatedItems,
  });

  @override
  ConsumerState<ValidatedOrderSummaryScreen> createState() =>
      _ValidatedOrderSummaryScreenState();
}

class _ValidatedOrderSummaryScreenState
    extends ConsumerState<ValidatedOrderSummaryScreen> {
  final _formKey = GlobalKey<FormState>();
  String? _selectedAdminName;
  bool _isProcessing = false;

  void _onConfirmAndProcess() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_isProcessing) return;
    setState(() => _isProcessing = true);

    final newSubtotal = widget.validatedItems
        .fold(0.0, (sum, item) => sum + (item.quantity * item.price));
    final shippingCost = widget.originalOrder.shippingFee ?? 0;
    final newGrandTotal = newSubtotal + shippingCost;

    final navigator = Navigator.of(context);
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    try {
      final orderId = widget.originalOrder.id;
      final orderNotifier = ref.read(orderProvider.notifier);

      final success = await orderNotifier.updateOrder(
        orderId,
        widget.validatedItems,
        shippingCost,
        newSubtotal, 
        newGrandTotal,
        validatorName: _selectedAdminName,
      );

      if (success) {
        await ref.read(orderServiceProvider).updateOrderStatus(orderId, 'processing');

        // --- FUNGSI BARU DITAMBAHKAN DI SINI ---
        await ref.read(orderServiceProvider).setValidationTimestamp(orderId);
        // --- AKHIR FUNGSI BARU ---

        ref.invalidate(orderProvider);
        ref.invalidate(orderDetailsProvider(orderId));
        ref.invalidate(orderStatusCountsProvider);

        if (mounted) {
          scaffoldMessenger.showSnackBar(
            const SnackBar(
                content: Text('Pesanan berhasil diproses dan siap dikirim.'),
                backgroundColor: Colors.green),
          );
          navigator.popUntil((route) => route.isFirst);
        }
      } else if (mounted) {
        scaffoldMessenger.showSnackBar(
          const SnackBar(
            content: Text('Gagal memproses pesanan. Silakan coba lagi.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } on SocketException {
        if (mounted) {
            scaffoldMessenger.showSnackBar(
                const SnackBar(
                    content: Text('Gagal menyimpan, koneksi internet error'),
                    backgroundColor: Colors.red,
                ),
            );
        }
    } on TimeoutException {
        if (mounted) {
            scaffoldMessenger.showSnackBar(
                const SnackBar(
                    content: Text('Gagal menyimpan, koneksi internet error'),
                    backgroundColor: Colors.red,
                ),
            );
        }
    } on FirebaseException {
        if (mounted) {
            scaffoldMessenger.showSnackBar(
                const SnackBar(
                    content: Text('Gagal menyimpan, unable to update database'),
                    backgroundColor: Colors.red,
                ),
            );
        }
    } catch (e) {
      if (mounted) {
        scaffoldMessenger.showSnackBar(
          SnackBar(content: Text('Terjadi error fungsional aplikasi: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currencyFormatter =
        NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);

    final newSubtotal = widget.validatedItems
        .fold(0.0, (sum, item) => sum + (item.quantity * item.price));
    final shippingCost = widget.originalOrder.shippingFee ?? 0;
    final newGrandTotal = newSubtotal + shippingCost;

    final adminUsersAsyncValue = ref.watch(adminUsersProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ringkasan Pesanan Divalidasi'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Ringkasan Pesanan Baru',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              Card(
                elevation: 2,
                margin: EdgeInsets.zero,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Nomor Pesanan:', style: TextStyle(color: Colors.grey[600])),
                            Text(widget.originalOrder.id,
                                style:
                                    const TextStyle(fontWeight: FontWeight.bold)),
                          ]),
                      const Divider(height: 24),
                      
                      SizedBox(
                        height: 300,
                        child: ListView.builder(
                          itemCount: widget.validatedItems.length,
                          itemBuilder: (BuildContext context, int index) {
                            final item = widget.validatedItems[index];
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 8.0),
                              child: ListTile(
                                visualDensity: VisualDensity.compact,
                                contentPadding: EdgeInsets.zero,
                                title: Text(item.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                                subtitle: Text(
                                    '${item.quantity} x ${currencyFormatter.format(item.price)}'),
                                trailing: Text(
                                    currencyFormatter.format(item.quantity * item.price), style: const TextStyle(fontWeight: FontWeight.w500)),
                              ),
                            );
                          },
                        ),
                      ),

                      const Divider(height: 24),
                      _buildSummaryRow(title: 'Subtotal', amount: newSubtotal, formatter: currencyFormatter),
                      const SizedBox(height: 8),
                      _buildSummaryRow(title: 'Ongkos Kirim', amount: shippingCost.toDouble(), formatter: currencyFormatter),
                      const Divider(),
                      _buildSummaryRow(
                        title: 'Grand Total',
                        amount: newGrandTotal,
                        formatter: currencyFormatter,
                        isTotal: true,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              adminUsersAsyncValue.when(
                data: (admins) => DropdownButtonFormField<String>(
                  initialValue: _selectedAdminName,
                  hint: const Text('Pilih nama...'),
                  decoration: const InputDecoration(
                    labelText: 'Di Validasi oleh',
                    border: OutlineInputBorder(),
                  ),
                  items: admins.map<DropdownMenuItem<String>>((Staff admin) {
                    return DropdownMenuItem<String>(
                      value: admin.name,
                      child: Text(admin.name),
                    );
                  }).toList(),
                  onChanged: (String? newValue) {
                    setState(() {
                      _selectedAdminName = newValue;
                    });
                  },
                  validator: (value) =>
                      value == null || value.isEmpty ? 'Harap pilih nama validator' : null,
                ),
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (err, stack) => Center(child: Text('Gagal memuat admin: $err')),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: Theme.of(context).primaryColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: _isProcessing ? null : _onConfirmAndProcess,
                  child: _isProcessing
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3))
                      : const Text('Proses Pesanan', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryRow({
    required String title,
    required double amount,
    required NumberFormat formatter,
    bool isTotal = false,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: TextStyle(
            fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
            fontSize: isTotal ? 16 : 14,
          ),
        ),
        Text(
          formatter.format(amount),
          style: TextStyle(
            fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
            fontSize: isTotal ? 18 : 14,
            color: isTotal ? Theme.of(context).colorScheme.primary : null,
          ),
        ),
      ],
    );
  }
}
