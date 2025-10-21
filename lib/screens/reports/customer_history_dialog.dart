import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/reports/customer_report_model.dart';
import 'order_detail_dialog.dart'; // Akan kita buat setelah ini

class CustomerHistoryDialog extends StatelessWidget {
  final CustomerReport customerReport;

  const CustomerHistoryDialog({super.key, required this.customerReport});

  String _formatCurrency(double amount) {
    final format =
        NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
    return format.format(amount);
  }

  String _formatDate(DateTime date) {
    return DateFormat('dd MMM yyyy, HH:mm', 'id_ID').format(date);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Riwayat Transaksi: ${customerReport.name}'),
      content: SizedBox(
        width: double.maxFinite,
        child: customerReport.orders.isEmpty
            ? const Center(child: Text('Tidak ada riwayat transaksi.'))
            : ListView.builder(
                shrinkWrap: true,
                itemCount: customerReport.orders.length,
                itemBuilder: (context, index) {
                  final order = customerReport.orders[index];
                  return Card(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    child: ListTile(
                      title: Text('Order ID: ${order.id.substring(0, 8)}...'),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(_formatDate(order.date)),
                          Row(
                            children: [
                              Chip(
                                  label: Text(order.status),
                                  backgroundColor: Colors.blue.shade100),
                              const SizedBox(width: 8),
                              Chip(
                                label: Text(
                                    order.paymentStatus == 'paid'
                                        ? 'Lunas'
                                        : 'Belum Lunas',
                                    style:
                                        const TextStyle(color: Colors.white)),
                                backgroundColor: order.paymentStatus == 'paid'
                                    ? Colors.green
                                    : Colors.orange,
                              ),
                            ],
                          )
                        ],
                      ),
                      trailing: Text(_formatCurrency(order.total),
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                      onTap: () {
                        // Tutup dialog saat ini dan buka dialog detail
                        Navigator.of(context).pop();
                        showDialog(
                          context: context,
                          builder: (_) => OrderDetailDialog(orderId: order.id),
                        );
                      },
                    ),
                  );
                },
              ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Tutup'),
        ),
      ],
    );
  }
}
