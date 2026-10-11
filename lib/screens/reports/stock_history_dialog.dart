import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../models/stock_movement.dart';
import '../../providers/stock_provider.dart';
import '../orders/marketplace_order_detail_screen.dart';

class StockHistoryDialog extends ConsumerWidget {
  final String productId;

  /// Rentang tanggal filter (sama seperti laporan arus stok web). Bila null,
  /// tampilkan semua pergerakan.
  final DateTimeRange? dateRange;

  const StockHistoryDialog({
    super.key,
    required this.productId,
    this.dateRange,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyAsync = ref.watch(stockHistoryProvider(productId));

    final dateFormat = DateFormat('dd MMM yyyy, HH:mm');
    final numberFormat = NumberFormat('#,##0');
    final rangeFormat = DateFormat('d MMM yyyy');

    return AlertDialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Riwayat Pergerakan Stok'),
          if (dateRange != null)
            Text(
              '${rangeFormat.format(dateRange!.start)} – ${rangeFormat.format(dateRange!.end)}',
              style: const TextStyle(
                fontSize: 12,
                color: Colors.grey,
                fontWeight: FontWeight.normal,
              ),
            ),
        ],
      ),
      content: SizedBox(
        width: MediaQuery.of(context).size.width * 0.9,
        height: MediaQuery.of(context).size.height * 0.7,
        child: historyAsync.when(
          data: (allMovements) {
            // Filter rentang tanggal (inklusif) — meniru filter laporan web.
            final movements = dateRange == null
                ? allMovements
                : allMovements
                    .where((m) =>
                        !m.date.isBefore(dateRange!.start) &&
                        !m.date.isAfter(dateRange!.end))
                    .toList();
            if (movements.isEmpty) {
              return const Center(
                child: Text(
                  'Tidak ada pergerakan stok pada rentang tanggal ini.',
                  textAlign: TextAlign.center,
                ),
              );
            }
            return _buildHistoryList(movements, dateFormat, numberFormat);
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          // --- MODIFIKASI SEMENTARA UNTUK DEBUGGING ---
          error: (err, stack) {
            // Ini akan mencetak link ke Debug Console
            print('--- START FIREBASE INDEX ERROR ---');
            print(err);
            print(stack);
            print('--- END FIREBASE INDEX ERROR: COPY URL FROM THE TEXT ABOVE ---');
            
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  'Gagal memuat. Link untuk membuat indeks Firestore telah dicetak di "DEBUG CONSOLE".\n\nBuka tab "DEBUG CONSOLE" di IDE Anda, salin link-nya, dan buka di browser.\n\nDetail Eror: $err',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.red),
                ),
              ),
            );
          },
          // --- AKHIR MODIFIKASI SEMENTARA ---
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

  void _openOrder(BuildContext context, String orderId) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => MarketplaceOrderDetailScreen(orderId: orderId),
      ),
    );
  }

  Widget _buildHistoryList(List<StockMovement> movements, DateFormat dateFormat, NumberFormat numberFormat) {
    return ListView.builder(
      itemCount: movements.length,
      itemBuilder: (context, index) {
        final movement = movements[index];
        final isStockIn = movement.change > 0;
        final icon = isStockIn
            ? const Icon(Icons.arrow_downward, color: Colors.green, size: 20)
            : const Icon(Icons.arrow_upward, color: Colors.red, size: 20);
        // Pergerakan dari pesanan bisa diketuk untuk membuka detail pesanan.
        final canOpen = movement.isOrder && movement.referenceId.isNotEmpty;
        final sourceLabel = movement.sourceLabel;

        return Card(
          margin: const EdgeInsets.symmetric(vertical: 5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: BorderSide(color: Colors.grey.shade200),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: canOpen ? () => _openOrder(context, movement.referenceId) : null,
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  icon,
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          dateFormat.format(movement.date),
                          style: const TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          movement.description,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Jenis: ${movement.typeLabel}',
                          style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
                        ),
                        if (sourceLabel != null) ...[
                          const SizedBox(height: 3),
                          Row(
                            children: [
                              Icon(
                                movement.source == 'pos'
                                    ? Icons.storefront
                                    : Icons.public,
                                size: 13,
                                color: Colors.blueGrey,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                sourceLabel,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.blueGrey,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '${isStockIn ? '+' : ''}${numberFormat.format(movement.change)}',
                        style: TextStyle(
                          color: isStockIn ? Colors.green : Colors.red,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Sisa: ${numberFormat.format(movement.stockAfter)}',
                        style: const TextStyle(fontSize: 13, color: Colors.black87),
                      ),
                    ],
                  ),
                  if (canOpen) ...[
                    const SizedBox(width: 4),
                    const Icon(Icons.chevron_right, color: Colors.grey, size: 20),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
