import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../providers/product_provider.dart';

class PurchaseHistoryDialog extends ConsumerWidget {
  final String productId;

  const PurchaseHistoryDialog({super.key, required this.productId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currencyFormatter =
        NumberFormat.currency(locale: 'id_ID', symbol: 'Rp', decimalDigits: 0);
    final historyAsync = ref.watch(purchaseHistoryProvider(productId));

    return AlertDialog(
      title: const Text('Riwayat Pembelian Produk'),
      content: SizedBox(
        width: double.maxFinite,
        child: historyAsync.when(
          data: (entries) {
            if (entries.isEmpty) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(20.0),
                  child: Text('Belum ada riwayat pembelian untuk produk ini.',
                      textAlign: TextAlign.center),
                ),
              );
            }
            return ListView.builder(
              shrinkWrap: true,
              itemCount: entries.length,
              itemBuilder: (context, index) {
                final entry = entries[index];

                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 6),
                  elevation: 1,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                    side: BorderSide(color: Colors.grey.shade200),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                    title: Text(
                      DateFormat('dd MMMM yyyy, HH:mm')
                          .format(entry.purchaseDate.toDate()),
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 6),
                        Text('Supplier: ${entry.supplierName ?? '-'}'),
                        const SizedBox(height: 4),
                        Text(
                            'Harga Beli: ${currencyFormatter.format(entry.purchasePrice)}'),
                        const SizedBox(height: 4),
                        Text('Jumlah: ${entry.quantity} pcs'),
                        const Divider(height: 16),
                        Text(
                          'Total: ${currencyFormatter.format(entry.subtotal)} ',
                          style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.blue,
                              fontSize: 14),
                        ),
                      ],
                    ),
                    isThreeLine: true,
                  ),
                );
              },
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, stack) =>
              Center(child: Text('Gagal memuat riwayat: $err')),
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
