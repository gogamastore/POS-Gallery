import 'product.dart';

class PurchaseCartItem {
  final Product product;
  final int quantity;
  final double purchasePrice;

  PurchaseCartItem({
    required this.product,
    this.quantity = 1,
    required this.purchasePrice,
  });

  double get subtotal => quantity * purchasePrice;

  // Konversi ke Map untuk disimpan di Firestore
  Map<String, dynamic> toMap() {
    return {
      'productId': product.id,
      'productName': product.name,
      'quantity': quantity,
      'purchasePrice': purchasePrice,
      'subtotal': subtotal,
    };
  }

  // Buat instance dari Map yang diambil dari Firestore
  factory PurchaseCartItem.fromMap(Map<String, dynamic> map) {
    return PurchaseCartItem(
      // Buat objek Product "parsial" karena data lengkap tidak disimpan di dalam transaksi
      product: Product(
        id: map['productId'] ?? '',
        name: map['productName'] ?? '',
        price: 0, // Harga jual tidak disimpan di item, default ke 0
        stock: 0, // Stok tidak relevan dalam konteks item keranjang, default ke 0
        // Harga beli tersedia di dalam map
        purchasePrice: (map['purchasePrice'])?.toDouble() ?? 0.0,
        lastPurchasePrice: (map['purchasePrice'])?.toDouble() ?? 0.0,
      ),
      quantity: (map['quantity'])?.toInt() ?? 0,
      purchasePrice: (map['purchasePrice'])?.toDouble() ?? 0.0,
    );
  }
  
  PurchaseCartItem copyWith({
    Product? product,
    int? quantity,
    double? purchasePrice,
  }) {
    return PurchaseCartItem(
      product: product ?? this.product,
      quantity: quantity ?? this.quantity,
      purchasePrice: purchasePrice ?? this.purchasePrice,
    );
  }
}
