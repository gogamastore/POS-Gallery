import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/product.dart';
import '../models/purchase_history_entry.dart'; // Impor model purchase history
import '../services/product_service.dart';

// Provider untuk ProductService
final productServiceProvider = Provider<ProductService>((ref) {
  return ProductService();
});

// Provider untuk mendapatkan semua produk (stream)
final allProductsProvider = StreamProvider<List<Product>>((ref) {
  final productService = ref.watch(productServiceProvider);
  return productService.getProducts();
});

// Provider untuk mendapatkan satu produk berdasarkan ID
final productDetailProvider = StreamProvider.family<Product?, String>((ref, productId) {
  final productService = ref.watch(productServiceProvider);
  return productService.getProductById(productId);
});

// --- PERBAIKAN: Menambahkan provider untuk riwayat pembelian produk ---
final purchaseHistoryProvider = StreamProvider.family<List<PurchaseHistoryEntry>, String>((ref, productId) {
  final productService = ref.watch(productServiceProvider);
  return productService.getPurchaseHistory(productId);
});
