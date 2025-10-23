import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/customer.dart';

// Provider untuk mendapatkan stream daftar customer dari Firestore
final customerProvider = StreamProvider<List<Customer>>((ref) {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  return _firestore.collection('customers').orderBy('name').snapshots().map((snapshot) {
    return snapshot.docs.map((doc) => Customer.fromFirestore(doc)).toList();
  });
});
