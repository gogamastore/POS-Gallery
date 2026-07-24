import 'package:cloud_firestore/cloud_firestore.dart';

class PurchaseHistory {
  final String purchaseId;
  final DateTime purchaseDate;
  final String supplierName;
  final int quantity;
  final double purchasePrice;

  PurchaseHistory({
    required this.purchaseId,
    required this.purchaseDate,
    required this.supplierName,
    required this.quantity,
    required this.purchasePrice,
  });

  // Factory constructor untuk membuat instance dari Map (data Firestore)
  factory PurchaseHistory.fromMap(Map<String, dynamic> map) {
    return PurchaseHistory(
      purchaseId: map['purchaseId'] ?? '',
      purchaseDate: (map['purchaseDate'] as Timestamp).toDate(),
      supplierName: map['supplierName'] ?? '',
      quantity: map['quantity'] ?? 0,
      purchasePrice: (map['purchasePrice'] ?? 0).toDouble(),
    );
  }
}
