import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/purchase.dart';
import './purchase_detail_dialog.dart';

class PayableList extends StatelessWidget {
  final List<Purchase> reportData;
  // --- TAMBAHKAN CALLBACK UNTUK MEMULAI PEMBAYARAN ---
  final Function(Purchase) onInitiatePayment;

  const PayableList({
    super.key,
    required this.reportData,
    required this.onInitiatePayment,
  });

  void _showDetailDialog(BuildContext context, Purchase purchase) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return PurchaseDetailDialog(
          purchase: purchase,
          // --- TERUSKAN AKSI PEMBAYARAN ---
          onPayAction: () {
            // Tutup dialog detail dulu, lalu panggil aksi pembayaran
            Navigator.of(context).pop(); 
            onInitiatePayment(purchase);
          },
        );
      },
    );
  }

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
          headingTextStyle: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
          columnSpacing: 20,
          showCheckboxColumn: false,
          columns: const [
            DataColumn(label: Text('Tanggal')),
            DataColumn(label: Text('Supplier')),
            DataColumn(label: Text('Total'), numeric: true),
            DataColumn(label: Text('Metode Pembayaran')),
            DataColumn(label: Text('Status Pembayaran')),
            DataColumn(label: Text('Status Transaksi')),
          ],
          rows: reportData.map((purchase) {
            bool isUnpaid = purchase.paymentStatus?.toLowerCase() != 'paid';
            return DataRow(
              onSelectChanged: (isSelected) {
                if (isSelected != null) {
                  _showDetailDialog(context, purchase);
                }
              },
              cells: [
                DataCell(Text(DateFormat('dd MMM yy', 'id_ID').format(purchase.date))),
                DataCell(Text(purchase.supplierName)),
                DataCell(Text(currencyFormatter.format(purchase.totalAmount))),
                DataCell(Text(purchase.paymentMethod)),
                DataCell(
                  Chip(
                    label: Text(
                      isUnpaid ? 'Belum Lunas' : 'Lunas',
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                    ),
                    backgroundColor: isUnpaid ? Colors.orange.shade800 : Colors.green.shade700,
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 0),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
                DataCell(Text(purchase.status)),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }
}
