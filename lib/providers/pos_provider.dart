import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/pos_cart_item.dart';
import '../models/product.dart';

// Provider untuk mengelola state dari keranjang penjualan (POS)
final posCartProvider = StateNotifierProvider<PosCartNotifier, List<PosCartItem>>((ref) {
  return PosCartNotifier();
});

class PosCartNotifier extends StateNotifier<List<PosCartItem>> {
  PosCartNotifier() : super([]);

  void addItem(Product product, int quantity, double price) {
    final existingIndex = state.indexWhere((item) => item.product.id == product.id);

    if (existingIndex != -1) {
      // Jika item sudah ada, perbarui jumlahnya
      final updatedItem = state[existingIndex].copyWith(quantity: state[existingIndex].quantity + quantity);
      state = [
        for (int i = 0; i < state.length; i++) 
          if (i == existingIndex) updatedItem else state[i],
      ];
    } else {
      // Jika item belum ada, tambahkan item baru
      state = [...state, PosCartItem(product: product, quantity: quantity, PosPrice: price)];
    }
  }

  void removeItem(String productId) {
    state = state.where((item) => item.product.id != productId).toList();
  }

  void updateItem(String productId, {int? newQuantity, double? newPrice}) {
    state = [
      for (final item in state)
        if (item.product.id == productId)
          item.copyWith(
            quantity: newQuantity ?? item.quantity,
            PosPrice: newPrice ?? item.PosPrice,
          )
        else
          item,
    ];
  }
  
  void clearCart() {
    state = [];
  }
}

// Provider untuk menghitung total harga di keranjang penjualan
final posTotalProvider = Provider<double>((ref) {
  final cart = ref.watch(posCartProvider);
  return cart.fold(0.0, (total, item) => total + item.subtotal);
});
