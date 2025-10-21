import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/receivable_data.dart';

class ReceivableList extends StatelessWidget {
  final List<ReceivableData> reportData;

  const ReceivableList({super.key, required this.reportData});

  @override
  Widget build(BuildContext context) {
    final currencyFormatter = NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    );

    return SingleChildScrollView(
      scrollDirection: Axis.vertical,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columnSpacing: 24.0, // Beri jarak antar kolom
          columns: const [
            DataColumn(label: Text('No. Order')),
            DataColumn(label: Text('Nama Customer')),
            DataColumn(label: Text('Tanggal')),
            DataColumn(label: Text('Status Pesanan')),
            DataColumn(label: Text('Total Piutang'), numeric: true),
          ],
          rows: reportData.map((data) {
            return DataRow(
              cells: [
                DataCell(Text(data.orderId)),
                DataCell(Text(data.customerName)),
                DataCell(Text(DateFormat('dd MMM yyyy', 'id_ID').format(data.orderDate))),
                DataCell(Text(data.orderStatus)),
                DataCell(Text(currencyFormatter.format(data.totalReceivable))),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }
}
