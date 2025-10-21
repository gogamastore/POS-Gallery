
import 'package:myapp/models/product.dart';

// Model ini diperbarui dengan 'orderIndex' untuk mendukung fungsionalitas drag-and-drop.
class TrendingProduct {
  final String trendingId;
  final Product product;
  int orderIndex; // Menggunakan 'int' dan bukan 'final' agar bisa diubah saat reordering

  TrendingProduct({
    required this.trendingId,
    required this.product,
    required this.orderIndex,
  });
}
