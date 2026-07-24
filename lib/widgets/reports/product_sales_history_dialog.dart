import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/product_sales_history.dart';
import '../../services/report_service.dart';

class ProductSalesHistoryDialog extends StatefulWidget {
  final String productId;
  final String productName;
  final DateTime startDate;
  final DateTime endDate;

  const ProductSalesHistoryDialog({
    super.key,
    required this.productId,
    required this.productName,
    required this.startDate,
    required this.endDate,
  });

  @override
  State<ProductSalesHistoryDialog> createState() => _ProductSalesHistoryDialogState();
}

class _ProductSalesHistoryDialogState extends State<ProductSalesHistoryDialog> {
  final ReportService _reportService = ReportService();
  late Future<List<ProductSalesHistory>> _historyFuture;

  @override
  void initState() {
    super.initState();
    _historyFuture = _reportService.getProductSalesHistory(
      productId: widget.productId,
      startDate: widget.startDate,
      endDate: widget.endDate,
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Transaksi: ${widget.productName}'),
      content: FutureBuilder<List<ProductSalesHistory>>(
        future: _historyFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Text('Error: ${snapshot.error}');
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(
              child: Text('Tidak ada riwayat penjualan untuk produk ini dalam periode ini.'),
            );
          }

          final history = snapshot.data!;
          // --- PERBAIKAN TATA LETAK TABEL ---
          return SizedBox(
            width: double.maxFinite, // Memastikan widget mengambil lebar maksimal dialog
            // Bungkus DataTable dengan SingleChildScrollView horizontal.
            // AlertDialog akan menangani scroll vertikal secara otomatis.
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal, // Mengaktifkan scroll ke samping
              child: DataTable(
                columnSpacing: 20,
                columns: const [
                  DataColumn(label: Text('Order ID')),
                  DataColumn(label: Text('Pelanggan')),
                  DataColumn(label: Text('Tanggal')),
                  DataColumn(label: Text('Jumlah'), numeric: true),
                ],
                rows: history.map((sale) {
                  return DataRow(
                    cells: [
                      DataCell(Text(_truncateOrderId(sale.orderId))),
                      DataCell(Text(sale.customerName)),
                      DataCell(Text(DateFormat('dd MMM yy').format(sale.orderDate))),
                      DataCell(Text(sale.quantity.toString())),
                    ],
                  );
                }).toList(),
              ),
            ),
          );
          // -------------------------------------
        },
      ),
      actions: [
        TextButton(
          child: const Text('Tutup'),
          onPressed: () {
            Navigator.of(context).pop();
          },
        ),
      ],
    );
  }

  String _truncateOrderId(String orderId) {
    return orderId.length > 8 ? '...${orderId.substring(orderId.length - 8)}' : orderId;
  }
}
