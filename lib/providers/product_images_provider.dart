import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/product.dart';

// Ganti nama provider dan ubah menjadi family untuk efisiensi dan ketahanan
final productProvider = FutureProvider.family<Product?, String>((ref, productId) async {
  if (productId.isEmpty) {
    return null;
  }
  try {
    final doc = await FirebaseFirestore.instance.collection('products').doc(productId).get();
    if (doc.exists) {
      // --- PERBAIKAN DI SINI ---
      // Constructor fromFirestore mengharapkan DocumentSnapshot, bukan data dan id terpisah.
      return Product.fromFirestore(doc);
    }
    return null;
  } catch (e) {
    // Biarkan error dilempar agar bisa ditangani di UI
    rethrow;
  }
});

// Provider lama bisa dihapus atau tidak digunakan lagi
final productImagesProvider = FutureProvider<Map<String, String>>((ref) async {
  final productCollection = FirebaseFirestore.instance.collection('products');
  final snapshot = await productCollection.get();
  final Map<String, String> imageMap = {};
  for (var doc in snapshot.docs) {
    final data = doc.data();
    final imageUrl = data['image'] as String?;
    if (imageUrl != null && imageUrl.isNotEmpty) {
      imageMap[doc.id] = imageUrl;
    }
  }
  return imageMap;
});
