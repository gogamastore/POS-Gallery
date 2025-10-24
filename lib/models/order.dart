import 'package:cloud_firestore/cloud_firestore.dart';

class Order {
  final String? id;

  // Timestamps
  final Timestamp date;
  final Timestamp? createdAt;
  final Timestamp? updatedAt;
  final Timestamp? validatedAt;
  final Timestamp? shippedAt;

  // Customer Info
  final String? customer;
  final String? customerId;
  final Map<String, dynamic>? customerDetails;

  // Products Info
  final List<Map<String, dynamic>> products;
  final List<String> productIds;

  // Financials
  final num subtotal;
  final num total;
  final num? shippingFee;

  // Payment Info
  final String paymentMethod;
  final String paymentStatus;

  // Status & Tracking
  final String status;
  final String kasir;
  final bool stockUpdated;
  final String? shippingMethod;

  Order({
    this.id,
    required this.date,
    this.createdAt,
    this.updatedAt,
    this.validatedAt,
    this.shippedAt,
    this.customer,
    this.customerId,
    this.customerDetails,
    required this.products,
    required this.productIds,
    required this.subtotal,
    required this.total,
    this.shippingFee,
    required this.paymentMethod,
    required this.paymentStatus,
    required this.status,
    required this.kasir,
    required this.stockUpdated,
    this.shippingMethod,
  });

  factory Order.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;

    // Helper untuk menangani tipe data timestamp yang tidak konsisten
    Timestamp? _parseTimestamp(dynamic value) {
      if (value is Timestamp) return value;
      // Dokumen Anda menunjukkan created_at sebagai string, jadi kita tangani di sini
      if (value is String) return Timestamp.fromDate(DateTime.parse(value));
      return null;
    }

    return Order(
      id: doc.id,
      date: data['date'] as Timestamp,
      createdAt: _parseTimestamp(data['created_at']), // Menggunakan helper
      updatedAt: data['updatedAt'] as Timestamp?,
      validatedAt: data['validatedAt'] as Timestamp?,
      shippedAt: data['shippedAt'] as Timestamp?,

      customer: data['customer'] as String?,
      customerId: data['customerId'] as String?,
      customerDetails: data['customerDetails'] as Map<String, dynamic>?,

      products: List<Map<String, dynamic>>.from(data['products'] ?? []),
      productIds: List<String>.from(data['productIds'] ?? []),

      subtotal: data['subtotal'] as num? ?? 0,
      total: data['total'] as num? ?? 0,
      shippingFee: data['shippingFee'] as num?,

      paymentMethod: data['paymentMethod'] as String? ?? 'N/A',
      paymentStatus: data['paymentStatus'] as String? ?? 'N/A',

      status: data['status'] as String? ?? 'N/A',
      kasir: data['kasir'] as String? ?? 'N/A',
      stockUpdated: data['stockUpdated'] as bool? ?? false,
      shippingMethod: data['shippingMethod'] as String?,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'date': date,
      'createdAt': createdAt ?? FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'validatedAt': validatedAt,
      'shippedAt': shippedAt,

      'customer': customer,
      'customerId': customerId,
      'customerDetails': customerDetails,

      'products': products,
      'productIds': productIds,

      'subtotal': subtotal,
      'total': total,
      'shippingFee': shippingFee,

      'paymentMethod': paymentMethod,
      'paymentStatus': paymentStatus,
      'paymentProofFileName': "", // Menjaga placeholder
      'paymentProofId': "",
      'paymentProofUploaded': false,
      'paymentProofUrl': "",

      'status': status,
      'kasir': kasir,
      'stockUpdated': stockUpdated,
      'shippingMethod': shippingMethod,
    };
  }
}
