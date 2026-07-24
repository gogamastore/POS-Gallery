class OrderProduct {
  final String productId;
  final String name;
  final int quantity;
  final double price;
  final String image;

  OrderProduct({
    required this.productId,
    required this.name,
    required this.quantity,
    required this.price,
    required this.image,
  });

  factory OrderProduct.fromMap(Map<String, dynamic> data) {
    return OrderProduct(
      productId: data['productId'] ?? '',
      name: data['name'] ?? 'Produk tidak diketahui',
      quantity: data['quantity'] ?? 0,
      price: (data['price'] ?? 0.0).toDouble(),
      image: data['image'] ?? '',
    );
  }
}
