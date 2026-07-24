
// --- FUNGSI UTILITAS GLOBAL ---

double parsePrice(dynamic price) {
  if (price is double) return price;
  if (price is int) return price.toDouble();
  if (price is String) {
    final sanitized = price.replaceAll(RegExp(r'[^0-9]'), '');
    return double.tryParse(sanitized) ?? 0.0;
  }
  return 0.0;
}

String? parseStringOrNull(dynamic value) {
  if (value == null) return null;
  if (value is String) return value;
  return value.toString();
}

class OrderProduct {
  final String productId;
  final String name;
  final int quantity;
  final double price;
  final String? sku;
  final String? imageUrl;

  OrderProduct({
    required this.productId,
    required this.name,
    required this.quantity,
    required this.price,
    this.sku,
    this.imageUrl,
  });

  // --- FACTORY METHOD YANG DIPERBAIKI ---
  factory OrderProduct.fromJson(Map<String, dynamic> json) {
    return OrderProduct(
      productId: json['productId'] as String,
      name: json['name'] as String,
      quantity: (json['quantity'] as num?)?.toInt() ?? 1,
      price: parsePrice(json['price']), 
      sku: parseStringOrNull(json['sku']), 
      // **LOGIKA BARU**: Coba 'imageUrl', lalu fallback ke 'image'
      imageUrl: json['imageUrl'] as String? ?? json['image'] as String?, 
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'productId': productId,
      'name': name,
      'quantity': quantity,
      'price': price,
      'sku': sku,
      'imageUrl': imageUrl,
    };
  }

  OrderProduct copyWith({
    String? productId,
    String? name,
    int? quantity,
    double? price,
    String? sku,
    String? imageUrl,
  }) {
    return OrderProduct(
      productId: productId ?? this.productId,
      name: name ?? this.name,
      quantity: quantity ?? this.quantity,
      price: price ?? this.price,
      sku: sku ?? this.sku,
      imageUrl: imageUrl ?? this.imageUrl,
    );
  }
}
