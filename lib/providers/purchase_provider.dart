import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/product.dart';
import '../../models/purchase_cart_item.dart';

// Provider untuk mengelola state dari keranjang pembelian
class PurchaseCartNotifier extends StateNotifier<List<PurchaseCartItem>> {
  PurchaseCartNotifier() : super([]);

  // Menambah produk ke keranjang atau memperbarui jumlah jika sudah ada
  void addItem(Product product, int quantity, double purchasePrice) {
    final itemIndex = state.indexWhere((item) => item.product.id == product.id);

    if (itemIndex != -1) {
      // --- PERBAIKAN: Buat item baru, jangan mutasi state lama ---
      final existingItem = state[itemIndex];
      final updatedItem = PurchaseCartItem(
        product: existingItem.product, 
        // Tambah kuantitas yang ada dengan kuantitas baru
        quantity: existingItem.quantity + quantity,
        // Selalu gunakan harga terakhir yang dimasukkan sebagai harga pembelian
        purchasePrice: purchasePrice, 
      );
      // Ganti item lama dengan item yang sudah diperbarui
      state = [
        for (int i = 0; i < state.length; i++)
          if (i == itemIndex) updatedItem else state[i],
      ];
    } else {
      // Jika produk belum ada, tambahkan sebagai item baru
      state = [
        ...state,
        PurchaseCartItem(
          product: product,
          quantity: quantity,
          purchasePrice: purchasePrice,
        ),
      ];
    }
  }

  // --- PERBAIKAN: Gabungkan menjadi satu metode update yang lebih baik ---
  void updateItem(String productId, {int? newQuantity, double? newPrice}) {
    state = [
      for (final item in state)
        if (item.product.id == productId)
          PurchaseCartItem(
            product: item.product, 
            // Gunakan nilai baru jika ada, jika tidak, gunakan nilai lama
            quantity: newQuantity ?? item.quantity, 
            purchasePrice: newPrice ?? item.purchasePrice,
          )
        else
          item,
    ];
  }

  // Menghapus item dari keranjang
  void removeItem(String productId) {
    state = state.where((item) => item.product.id != productId).toList();
  }

  // Mengosongkan seluruh keranjang
  void clearCart() {
    state = [];
  }
}

final purchaseCartProvider =
    StateNotifierProvider<PurchaseCartNotifier, List<PurchaseCartItem>>((ref) {
      return PurchaseCartNotifier();
    });

// Provider untuk menghitung total harga di keranjang
final purchaseTotalProvider = Provider<double>((ref) {
  final cart = ref.watch(purchaseCartProvider);
  return cart.fold(0, (total, item) => total + item.subtotal);
});
