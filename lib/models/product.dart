import 'package:cloud_firestore/cloud_firestore.dart';

// Fungsi utilitas yang diperbarui untuk mengubah berbagai format harga menjadi double
double parsePrice(dynamic price) {
  if (price is double) return price;
  if (price is int) return price.toDouble();
  if (price is String) {
    // Hapus semua karakter non-numerik (Rp, spasi, titik ribuan)
    final sanitized = price.replaceAll(RegExp(r'[^0-9]'), '');
    if (sanitized.isEmpty) return 0.0;
    return double.tryParse(sanitized) ?? 0.0;
  }
  return 0.0;
}

class Product {
  final String id;
  final String name;
  final double price; // Harga Jual
  final int stock;
  final String? sku;
  final String? image;
  final double? purchasePrice; // Harga Beli (bisa jadi harga rata-rata)
  final String? description;
  final String? categoryId;
  final double? lastPurchasePrice; // Harga beli terakhir yang spesifik
  final Timestamp? createdAt;
  final Timestamp? updatedAt;

  Product({
    required this.id,
    required this.name,
    required this.price,
    required this.stock,
    this.sku,
    this.image,
    this.purchasePrice,
    this.description,
    this.categoryId,
    this.lastPurchasePrice,
    this.createdAt,
    this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'price': price,
      'stock': stock,
      'sku': sku,
      'image': image,
      'purchasePrice': purchasePrice,
      'description': description,
      'categoryId': categoryId,
      'lastPurchasePrice': lastPurchasePrice,
      'createdAt': createdAt ?? FieldValue.serverTimestamp(),
      'updatedAt': updatedAt, // Biarkan null saat membuat, Firestore akan mengisinya
    };
  }

  factory Product.fromMap(Map<String, dynamic> map) {
    return Product(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      price: parsePrice(map['price']),
      stock: (map['stock'] as num?)?.toInt() ?? 0,
      sku: map['sku']?.toString(),
      image: map['image'] as String?,
      purchasePrice: parsePrice(map['purchasePrice']),
      description: map['description'] as String?,
      categoryId: map['categoryId'] as String?,
      // Fallback: Gunakan purchasePrice jika lastPurchasePrice tidak ada
      lastPurchasePrice: parsePrice(map['lastPurchasePrice'] ?? map['purchasePrice']),
      createdAt: map['createdAt'] as Timestamp?,
      updatedAt: map['updatedAt'] as Timestamp?,
    );
  }

  factory Product.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return Product(
      id: doc.id,
      name: data['name'] ?? '',
      price: parsePrice(data['price']),
      stock: (data['stock'] as num?)?.toInt() ?? 0,
      sku: data['sku']?.toString(),
      image: data['image'] as String?,
      purchasePrice: parsePrice(data['purchasePrice']),
      description: data['description'] as String?,
      categoryId: data['categoryId'] as String?,
      // Fallback: Gunakan purchasePrice jika lastPurchasePrice tidak ada
      lastPurchasePrice: parsePrice(data['lastPurchasePrice'] ?? data['purchasePrice']),
      createdAt: data['createdAt'] as Timestamp?,
      updatedAt: data['updatedAt'] as Timestamp?,
    );
  }

  Product copyWith({
    String? id,
    String? name,
    double? price,
    int? stock,
    String? sku,
    String? image,
    double? purchasePrice,
    String? description,
    String? categoryId,
    double? lastPurchasePrice,
    Timestamp? createdAt,
    Timestamp? updatedAt,
  }) {
    return Product(
      id: id ?? this.id,
      name: name ?? this.name,
      price: price ?? this.price,
      stock: stock ?? this.stock,
      sku: sku ?? this.sku,
      image: image ?? this.image,
      purchasePrice: purchasePrice ?? this.purchasePrice,
      description: description ?? this.description,
      categoryId: categoryId ?? this.categoryId,
      lastPurchasePrice: lastPurchasePrice ?? this.lastPurchasePrice,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
