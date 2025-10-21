// lib/services/supplier_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/supplier.dart';

class SupplierService {
  final _db = FirebaseFirestore.instance;

  Future<List<Supplier>> getSuppliers() async {
    final snapshot = await _db.collection('suppliers').orderBy('createdAt', descending: true).get();
    return snapshot.docs.map((doc) => Supplier.fromFirestore(doc)).toList();
  }

  Future<void> addSupplier(Map<String, dynamic> data) async {
    await _db.collection('suppliers').add(data);
  }

// Implementasi updateSupplier dan deleteSupplier di sini
}