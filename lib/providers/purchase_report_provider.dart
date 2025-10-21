import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/purchase_transaction.dart';

// Provider ini akan mengambil SEMUA transaksi pembelian.
final purchaseTransactionsProvider = StreamProvider<List<PurchaseTransaction>>((ref) {
  final firestore = FirebaseFirestore.instance;
  final stream = firestore
      .collection('purchase_transactions')
      .orderBy('date', descending: true) // Urutkan dari yang terbaru
      .snapshots();

  return stream.map((snapshot) => snapshot.docs
      .map((doc) => PurchaseTransaction.fromFirestore(doc))
      .toList());
});
