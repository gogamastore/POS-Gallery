
import 'package:cloud_firestore/cloud_firestore.dart';

class ProductCategory {
  final String id;
  final String name;

  ProductCategory({required this.id, required this.name});

  factory ProductCategory.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ProductCategory(
      id: doc.id,
      name: data['name'] ?? 'Tanpa Nama',
    );
  }
}
