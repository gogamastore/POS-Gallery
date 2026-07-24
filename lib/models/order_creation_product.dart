// File: lib/models/order_creation_product.dart

// Tujuan DTO ini adalah untuk menjadi "jembatan" data.
// Ia menerima data dari UI dan mengubahnya menjadi Map yang 100% kompatibel
// dengan apa yang diharapkan oleh model Order.fromFirestore() yang sudah ada.

class OrderCreationProduct {
  final String productId;
  final String name;
  final int quantity;
  final double price;
  final String? sku;
  final String? imageUrl; // DIUBAH: Menggunakan imageUrl agar kompatibel

  OrderCreationProduct({
    required this.productId,
    required this.name,
    required this.quantity,
    required this.price,
    this.sku,
    this.imageUrl, // DIUBAH
  });

  // Metode ini menghasilkan Map dengan key 'imageUrl' agar bisa dibaca
  // oleh Order.fromFirestore() saat refresh.
  Map<String, dynamic> toJson() {
    return {
      'productId': productId,
      'name': name,
      'quantity': quantity,
      'price': price,
      'sku': sku,
      'imageUrl': imageUrl, // DIUBAH: Menggunakan key 'imageUrl' yang benar
    };
  }
}
