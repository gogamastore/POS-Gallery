import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:ionicons/ionicons.dart';
import '../../models/order.dart' as app_order;

class OrderInvoiceDialog extends StatelessWidget {
  final app_order.Order order;
  final VoidCallback onMarkAsPaid;

  const OrderInvoiceDialog({
    super.key,
    required this.order,
    required this.onMarkAsPaid,
  });

  @override
  Widget build(BuildContext context) {
    final currencyFormatter =
        NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
    final dateFormatter = DateFormat('dd MMMM yyyy, HH:mm', 'id_ID');

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 650, maxWidth: 600),
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildHeader(context),
                  const SizedBox(height: 16),
                  _buildInfoRow(
                      'Tanggal:', dateFormatter.format(order.date.toDate())),
                  _buildInfoRow('Pelanggan:', order.customer),
                  const Divider(height: 24),
                  _buildItemsTable(context, currencyFormatter),
                  const Divider(height: 24),
                  _buildFooter(context, currencyFormatter),
                  const SizedBox(height: 16),
                  _buildActionButtons(context),
                ],
              ),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: IconButton(
                icon: const Icon(Ionicons.close),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Faktur Pesanan',
          style: Theme.of(context)
              .textTheme
              .headlineSmall
              ?.copyWith(fontWeight: FontWeight.bold),
        ),
        Text(
          '#${order.id}',
          style: Theme.of(context)
              .textTheme
              .bodySmall
              ?.copyWith(color: Colors.grey),
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Row(
        children: [
          SizedBox(
              width: 80,
              child: Text(label,
                  style: const TextStyle(fontWeight: FontWeight.w600))),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  Widget _buildItemsTable(BuildContext context, NumberFormat formatter) {
    return Expanded(
      child: SingleChildScrollView(
        child: DataTable(
          columnSpacing: 24,
          columns: const [
            DataColumn(label: Text('Produk')),
            DataColumn(label: Text('Jml'), numeric: true),
            DataColumn(label: Text('Harga'), numeric: true),
            DataColumn(label: Text('Subtotal'), numeric: true),
          ],
          rows: order.products.map((item) {
            final subtotal = item.price * item.quantity;
            return DataRow(
              cells: [
                DataCell(SizedBox(
                    width: 150,
                    child: Text(item.name, overflow: TextOverflow.ellipsis))),
                DataCell(Text(item.quantity.toString())),
                DataCell(Text(formatter.format(item.price))),
                DataCell(Text(formatter.format(subtotal))),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildFooter(BuildContext context, NumberFormat formatter) {
    final total =
        double.tryParse(order.total.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0.0;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          'Status: ${order.paymentStatus}',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        Text(
          'Total: ${formatter.format(total)}',
          style: Theme.of(context)
              .textTheme
              .titleMedium
              ?.copyWith(fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  Widget _buildActionButtons(BuildContext context) {
    bool isUnpaid = order.paymentStatus.toLowerCase() == 'unpaid';

    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        TextButton.icon(
          onPressed: () {
            // Logika untuk print/download
          },
          icon: const Icon(Ionicons.print_outline, size: 16),
          label: const Text('Download'),
        ),
        const SizedBox(width: 8),
        if (isUnpaid)
          ElevatedButton.icon(
            onPressed: () {
              showDialog(
                context: context,
                builder: (BuildContext ctx) {
                  return AlertDialog(
                    title: const Text('Konfirmasi Pelunasan'),
                    content: const Text(
                        'Apakah Anda yakin ingin menandai pesanan ini sebagai LUNAS?'),
                    actions: <Widget>[
                      TextButton(
                        child: const Text('Batal'),
                        onPressed: () {
                          Navigator.of(ctx).pop();
                        },
                      ),
                      ElevatedButton(
                        child: const Text('Ya, Tandai Lunas'),
                        onPressed: () {
                          Navigator.of(ctx).pop(); // Tutup dialog konfirmasi
                          onMarkAsPaid(); // Panggil callback
                          Navigator.of(context).pop(); // Tutup dialog faktur
                        },
                      ),
                    ],
                  );
                },
              );
            },
            icon: const Icon(Ionicons.checkmark_circle_outline, size: 16),
            label: const Text('Tandai Lunas'),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
          ),
      ],
    );
  }
}
