import 'package:cloud_firestore/cloud_firestore.dart';

// Merepresentasikan satu item produk di dalam transaksi pembelian
class PurchaseItem {
  final String productId;
  final String productName;
  final int quantity;
  final double purchasePrice;

  PurchaseItem({
    required this.productId,
    required this.productName,
    required this.quantity,
    required this.purchasePrice,
  });

  // Konversi dari Map (data Firestore) ke objek PurchaseItem
  factory PurchaseItem.fromMap(Map<String, dynamic> map) {
    return PurchaseItem(
      productId: map['productId'] as String? ?? '',
      productName: map['productName'] as String? ?? 'N/A',
      quantity: map['quantity'] as int? ?? 0,
      purchasePrice: (map['purchasePrice'] as num? ?? 0.0).toDouble(),
    );
  }
}

// Merepresentasikan satu dokumen transaksi pembelian lengkap
class PurchaseTransaction {
  final String id;
  final DateTime date;
  final double totalAmount;
  final String supplierName;
  final String paymentStatus; // e.g., 'Lunas', 'Kredit'
  final String paymentMethod; // e.g., 'cash', 'credit', 'bank_transfer'
  final List<PurchaseItem> items;

  PurchaseTransaction({
    required this.id,
    required this.date,
    required this.totalAmount,
    required this.supplierName,
    required this.paymentStatus,
    required this.paymentMethod,
    required this.items,
  });

  // Factory constructor untuk membuat instance dari dokumen Firestore
  factory PurchaseTransaction.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};

    // Logika untuk menentukan status pembayaran
    final paymentMethod = data['paymentMethod'] as String? ?? 'cash';
    String derivedStatus;
    if (paymentMethod.toLowerCase() == 'credit') {
      derivedStatus = 'Kredit';
    } else {
      derivedStatus = 'Lunas'; // Anggap cash, bank_transfer, dll. sebagai Lunas
    }

    return PurchaseTransaction(
      id: doc.id,
      date: (data['date'] as Timestamp? ?? Timestamp.now()).toDate(),
      totalAmount: (data['totalAmount'] as num? ?? 0.0).toDouble(),
      supplierName: data['supplierName'] as String? ?? 'N/A',
      paymentMethod: paymentMethod, // Simpan metode pembayaran asli
      paymentStatus: derivedStatus, // Gunakan status yang sudah diturunkan
      items: (data['items'] as List<dynamic>? ?? [])
          .map((item) => PurchaseItem.fromMap(item as Map<String, dynamic>))
          .toList(),
    );
  }
}
