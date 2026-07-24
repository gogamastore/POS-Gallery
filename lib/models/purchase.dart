import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:myapp/models/purchase_cart_item.dart';

class Purchase {
  final String id;
  final String purchaseNumber;
  final String supplierId;
  final String supplierName;
  final List<PurchaseCartItem> items;
  final double totalAmount;
  final String paymentMethod;
  final DateTime date;
  final String status;
  final String? paymentStatus; // <-- DITAMBAHKAN

  Purchase({
    required this.id,
    required this.purchaseNumber,
    required this.supplierId,
    required this.supplierName,
    required this.items,
    required this.totalAmount,
    required this.paymentMethod,
    required this.date,
    required this.status,
    this.paymentStatus, // <-- DITAMBAHKAN
  });

  Map<String, dynamic> toMap() {
    return {
      'purchaseNumber': purchaseNumber,
      'supplierId': supplierId,
      'supplierName': supplierName,
      'items': items.map((item) => item.toMap()).toList(),
      'totalAmount': totalAmount,
      'paymentMethod': paymentMethod,
      'date': Timestamp.fromDate(date),
      'status': status,
      'paymentStatus': paymentStatus, // <-- DITAMBAHKAN
    };
  }

  factory Purchase.fromMap(String id, Map<String, dynamic> map) {
    return Purchase(
      id: id,
      purchaseNumber: map['purchaseNumber'] ?? '',
      supplierId: map['supplierId'] ?? '',
      supplierName: map['supplierName'] ?? '',
      items: (map['items'] as List)
          .map((itemMap) => PurchaseCartItem.fromMap(itemMap))
          .toList(),
      totalAmount: (map['totalAmount'] ?? 0).toDouble(),
      paymentMethod: map['paymentMethod'] ?? '',
      date: (map['date'] as Timestamp).toDate(),
      status: map['status'] ?? '',
      paymentStatus: map['paymentStatus'], // <-- DITAMBAHKAN
    );
  }
}
