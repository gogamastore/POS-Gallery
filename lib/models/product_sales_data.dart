import './product.dart';

// Model untuk menampung data agregat penjualan produk untuk laporan.
class ProductSalesData {
  final Product product;
  final int totalSold;

  ProductSalesData({
    required this.product,
    required this.totalSold,
  });
}
