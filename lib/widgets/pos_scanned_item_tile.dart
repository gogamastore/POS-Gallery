import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

// Widget ini sekarang lebih sederhana, hanya untuk tampilan.
class PosScannedItemTile extends StatelessWidget {
  final String name;
  final String? sku;
  final double price;
  final int originalQuantity;
  final int validatedQuantity;
  final VoidCallback onTap;

  const PosScannedItemTile({
    super.key,
    required this.name,
    this.sku,
    required this.price,
    required this.originalQuantity,
    required this.validatedQuantity,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final currencyFormatter =
        NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);

    final isValidated = validatedQuantity > 0;

    return InkWell(
      onTap: onTap, // Fungsi onTap untuk memunculkan dialog
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        elevation: isValidated ? 4 : 1,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: isValidated ? Colors.green.shade400 : Colors.grey.shade300,
            width: 1.5,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
                    const SizedBox(height: 4),
                    Text('SKU: ${sku ?? 'N/A'}', style: TextStyle(fontSize: 12, color: Colors.grey.shade700, fontStyle: FontStyle.italic)),
                    const SizedBox(height: 4),
                    Text(currencyFormatter.format(price), style: const TextStyle(fontSize: 14)),
                  ],
                ),
              ),
              // Tampilan Kuantitas Baru
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('Pesanan: $originalQuantity', style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                       Text('Validasi: ', style: TextStyle(fontSize: 15, color: Colors.grey.shade800)),
                       Text('$validatedQuantity', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.black)),
                       const SizedBox(width: 8),
                       Icon(Icons.touch_app, color: Colors.blue.shade300),
                    ],
                  )
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
