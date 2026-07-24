import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/stock_movement.dart';
import '../services/stock_service.dart';

// Provider untuk instance StockService
final stockServiceProvider = Provider<StockService>((ref) {
  return StockService();
});

// --- MODIFIKASI: Mengubah provider untuk hanya menerima productId ---
// Menghapus kelas StockHistoryParams yang tidak lagi dibutuhkan.
// Provider sekarang menerima String (productId) secara langsung.
final stockHistoryProvider =
    FutureProvider.autoDispose.family<List<StockMovement>, String>(
  (ref, productId) async {
    // Pantau service provider
    final stockService = ref.watch(stockServiceProvider);
    // Panggil metode untuk mendapatkan seluruh riwayat stok untuk produk ini
    return stockService.getStockHistory(productId);
  },
);
