// Model untuk menyimpan detail riwayat penjualan per produk dari setiap pesanan
class ProductSalesHistory {
  final String orderId;
  final String customerName;
  final DateTime orderDate;
  final int quantity;

  ProductSalesHistory({
    required this.orderId,
    required this.customerName,
    required this.orderDate,
    required this.quantity,
  });
}
