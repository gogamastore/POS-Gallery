import 'package:cloud_firestore/cloud_firestore.dart';

class PurchaseHistoryEntry {
  final String id;
  final String productId;
  final Timestamp purchaseDate;
  final int quantity;
  final double purchasePrice;
  final String? supplierName;

  PurchaseHistoryEntry({
    required this.id,
    required this.productId,
    required this.purchaseDate,
    required this.quantity,
    required this.purchasePrice,
    this.supplierName,
  });

  // Factory constructor untuk membuat instance dari Firestore DocumentSnapshot
  factory PurchaseHistoryEntry.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return PurchaseHistoryEntry(
      id: doc.id,
      productId: data['productId'] as String,
      purchaseDate: data['purchaseDate'] as Timestamp,
      // Pastikan quantity dibaca sebagai int, default ke 0 jika null
      quantity: (data['quantity'] as num?)?.toInt() ?? 0,
      // Pastikan purchasePrice dibaca sebagai double, default ke 0.0 jika null
      purchasePrice: (data['purchasePrice'] as num?)?.toDouble() ?? 0.0,
      supplierName: data['supplierName'] as String?,
    );
  }

  // Kalkulasi subtotal untuk kemudahan
  double get subtotal => quantity * purchasePrice;
}
