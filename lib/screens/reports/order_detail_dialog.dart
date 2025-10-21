import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:ionicons/ionicons.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../models/order.dart';
import '../../providers/report_provider.dart';

class OrderDetailDialog extends ConsumerWidget {
  final String orderId;

  const OrderDetailDialog({super.key, required this.orderId});

  String _formatCurrency(double? amount) {
    if (amount == null) return 'Rp 0';
    final format = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
    return format.format(amount);
  }
   double _parseTotal(String total) {
    return double.tryParse(total.replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0.0;
  }


  String _formatDate(DateTime date) {
    return DateFormat('dd MMMM yyyy, HH:mm', 'id_ID').format(date);
  }

  Future<void> _printPdf(Order order) async {
    final pdf = pw.Document();
    final total = _parseTotal(order.total);
    final subtotal = total - (order.shippingFee ?? 0);

    pdf.addPage(pw.Page(
      pageFormat: PdfPageFormat.a4,
      build: (pw.Context context) {
        return pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text('Faktur Pesanan', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 20),
            pw.Text('ID Pesanan: ${order.id}'),
            pw.Text('Tanggal: ${_formatDate(order.date.toDate())}'),
            pw.Text('Status Pesanan: ${order.status}'),
            pw.Text('Status Pembayaran: ${order.paymentStatus}'),
            pw.Divider(height: 30, thickness: 2),
            pw.Text('Informasi Pelanggan:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
            pw.Text('Nama: ${order.customer}'),
            pw.Divider(height: 30, thickness: 2),
            pw.Text('Rincian Produk:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 10),
            pw.TableHelper.fromTextArray(
              headers: ['Produk', 'Jumlah', 'Harga', 'Subtotal'],
              data: order.products.map((p) => [
                p.name,
                p.quantity.toString(),
                _formatCurrency(p.price),
                _formatCurrency(p.price * p.quantity),
              ]).toList(),
            ),
             pw.Divider(height: 30, thickness: 2),
             pw.Row(
               mainAxisAlignment: pw.MainAxisAlignment.end,
               children: [
                 pw.Column(
                   crossAxisAlignment: pw.CrossAxisAlignment.end,
                   children: [
                      pw.Text('Subtotal Produk: ${_formatCurrency(subtotal)}'),
                      pw.Text('Biaya Pengiriman: ${_formatCurrency(order.shippingFee)}'),
                      pw.SizedBox(height: 10),
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
             final total = _parseTotal(order.total);
             final subtotal = total - (order.shippingFee ?? 0);
            return SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ListTile(title: const Text('ID Pesanan'), subtitle: Text(order.id)),
                  ListTile(title: const Text('Pelanggan'), subtitle: Text(order.customer)),
                  ListTile(title: const Text('Tanggal'), subtitle: Text(_formatDate(order.date.toDate()))),
                  const Divider(),
                  const Text('Produk Dipesan', style: TextStyle(fontWeight: FontWeight.bold)),
                  ...order.products.map((p) => ListTile(
                        leading: CircleAvatar(
                          backgroundImage: p.imageUrl != null && p.imageUrl!.isNotEmpty ? NetworkImage(p.imageUrl!) : null,
                          child: p.imageUrl == null || p.imageUrl!.isEmpty ? const Icon(Ionicons.cube_outline) : null,
                        ),
                        title: Text(p.name),
                        subtitle: Text('${p.quantity} x ${_formatCurrency(p.price)}'),
                        trailing: Text(_formatCurrency(p.quantity * p.price)),
                      )),
                  const Divider(),
                  ListTile(title: const Text('Subtotal'), trailing: Text(_formatCurrency(subtotal))),
                  ListTile(title: const Text('Ongkir'), trailing: Text(_formatCurrency(order.shippingFee))),
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
