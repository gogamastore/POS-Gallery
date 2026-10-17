import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'category_provider.dart'; // firestoreProvider

/// Brand sederhana dari koleksi `brands` (dipakai bersama web + aplikasi pembeli).
class Brand {
  final String id;
  final String name;
  final String logoUrl;

  const Brand({required this.id, required this.name, required this.logoUrl});

  factory Brand.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return Brand(
      id: doc.id,
      name: (data['name'] as String?) ?? '',
      logoUrl: (data['logoUrl'] as String?) ?? '',
    );
  }
}

/// Daftar SEMUA brand (real-time), diurutkan berdasarkan nama.
final brandsStreamProvider = StreamProvider<List<Brand>>((ref) {
  final firestore = ref.watch(firestoreProvider);
  return firestore
      .collection('brands')
      .orderBy('name')
      .snapshots()
      .map((snap) => snap.docs.map(Brand.fromFirestore).toList());
});

/// Menambah brand baru; mengembalikan id dokumen yang dibuat agar bisa langsung
/// dipilih pada form produk.
final addBrandProvider = FutureProvider.family<String, String>((ref, brandName) async {
  if (brandName.trim().isEmpty) {
    throw Exception('Nama brand tidak boleh kosong.');
  }
  final firestore = ref.watch(firestoreProvider);
  final docRef = await firestore.collection('brands').add({
    'name': brandName.trim(),
    'logoUrl': '',
    'createdAt': FieldValue.serverTimestamp(),
  });
  return docRef.id;
});
