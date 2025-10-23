import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart'; // Import ini akan digunakan
import 'package:ionicons/ionicons.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../models/order.dart';
import '../../providers/report_provider.dart';

class OrderDetailDialog extends ConsumerWidget {
  final String orderId;

  const OrderDetailDialog({super.key, required this.orderId});

  // --- PERBAIKAN: Menambahkan fungsi helper lokal ---
  String _formatCurrency(double? amount) {
    if (amount == null) return 'Rp 0';
    final format = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
    return format.format(amount);
  }

  String _formatDate(DateTime date) {
    return DateFormat('dd MMMM yyyy, HH:mm', 'id_ID').format(date);
  }
  // ---------------------------------------------------

  Future<void> _printPdf(Order order) async {
    final pdf = pw.Document();
    final total = order.total;

    pdf.addPage(pw.Page(
      pageFormat: PdfPageFormat.a4,
      build: (pw.Context context) {
        return pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text('Faktur Pesanan', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 20),
            pw.Text('ID Pesanan: ${order.id ?? 'N/A'}'),
            pw.Text('Tanggal: ${_formatDate(order.date.toDate())}'),
            pw.Text('Status Pesanan: ${order.status}'),
            pw.Text('Status Pembayaran: ${order.paymentStatus}'),
            pw.Divider(height: 30, thickness: 2),
            pw.Text('Informasi Pelanggan:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
            pw.Text('Nama: ${order.customerDetails?['name'] ?? 'N/A'}'),
            pw.Divider(height: 30, thickness: 2),
            pw.Text('Rincian Produk:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 10),
            pw.TableHelper.fromTextArray(
              headers: ['Produk', 'Jumlah', 'Harga', 'Subtotal'],
              data: order.products.map((p) {
                  final price = (p['price'] as num? ?? 0).toDouble();
                  final quantity = (p['quantity'] as num? ?? 0).toInt();
                  return [
                    p['name'] as String? ?? 'N/A',
                    quantity.toString(),
                    _formatCurrency(price),
                    _formatCurrency(price * quantity),
                  ];
              }).toList(),
            ),
             pw.Divider(height: 30, thickness: 2),
             pw.Row(
               mainAxisAlignment: pw.MainAxisAlignment.end,
               children: [
                 pw.Column(
                   crossAxisAlignment: pw.CrossAxisAlignment.end,
                   children: [
                      // PERBAIKAN: Hanya menampilkan total karena tidak ada subtotal/ongkir
                      pw.Text('Total: ${_formatCurrency(total)}', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
                   ]
                 )
               ]
             )
          ],
        );
      },
    ));

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final orderData = ref.watch(orderByIdProvider(orderId));

    return AlertDialog(
      title: const Text('Detail Faktur'),
      content: SizedBox(
        width: double.maxFinite,
        child: orderData.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, stack) => Center(child: Text('Gagal memuat detail pesanan: $err')),
          data: (order) {
            final total = order.total;

            return SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ListTile(title: const Text('ID Pesanan'), subtitle: Text(order.id ?? 'N/A')),
                  ListTile(title: const Text('Pelanggan'), subtitle: Text(order.customerDetails?['name'] ?? 'N/A')),
                  // PERBAIKAN: Menggunakan helper _formatDate
                  ListTile(title: const Text('Tanggal'), subtitle: Text(_formatDate(order.date.toDate()))),
                  const Divider(),
                  const Text('Produk Dipesan', style: TextStyle(fontWeight: FontWeight.bold)),
                  ...order.products.map((p) {
                      final imageUrl = p['image'] as String?;
                      final name = p['name'] as String? ?? 'Produk tidak dikenal';
                      final quantity = (p['quantity'] as num? ?? 0).toInt();
                      final price = (p['price'] as num? ?? 0).toDouble();
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundImage: imageUrl != null && imageUrl.isNotEmpty ? NetworkImage(imageUrl) : null,
                          child: imageUrl == null || imageUrl.isEmpty ? const Icon(Ionicons.cube_outline) : null,
                        ),
                        title: Text(name),
                        subtitle: Text('$quantity x ${_formatCurrency(price)}'),
                        trailing: Text(_formatCurrency(quantity * price)),
                      );
                  }),
                  const Divider(),
                  // PERBAIKAN: Menghapus ListTile untuk Subtotal dan Ongkir
                  ListTile(
                    title: const Text('Total', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                    trailing: Text(_formatCurrency(total), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                  ),
                ],
              ),
            );
          },
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Tutup')),
        orderData.when(
          data: (order) => 
              ElevatedButton.icon(
                  icon: const Icon(Ionicons.print_outline),
                  label: const Text('Cetak PDF'),
                  onPressed: () => _printPdf(order),
                ),
          loading: () => const SizedBox.shrink(),
          error: (_, __) => const SizedBox.shrink(),
        ),
      ],
    );
  }
}
