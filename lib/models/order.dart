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

  // --- FIELD BARU UNTUK KALKULASI LABA ---
  final double cogs; // Cost of Goods Sold (Harga Pokok Penjualan)
  final double grossProfit; // Laba Kotor

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
    // Default value untuk field baru
    this.cogs = 0.0,
    this.grossProfit = 0.0,
  });

  factory Order.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;

    Timestamp? _parseTimestamp(dynamic value) {
      if (value is Timestamp) return value;
      if (value is String) return Timestamp.fromDate(DateTime.parse(value));
      return null;
    }

    return Order(
      id: doc.id,
      date: data['date'] as Timestamp,
      createdAt: _parseTimestamp(data['created_at']),
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
      // cogs & grossProfit tidak diambil dari Firestore, defaultnya 0
    );
  }
  
  // --- METHOD BARU UNTUK MEMPERBARUI ---
  Order copyWith({
    double? cogs,
    double? grossProfit,
  }) {
    return Order(
      id: this.id,
      date: this.date,
      createdAt: this.createdAt,
      updatedAt: this.updatedAt,
      validatedAt: this.validatedAt,
      shippedAt: this.shippedAt,
      customer: this.customer,
      customerId: this.customerId,
      customerDetails: this.customerDetails,
      products: this.products,
      productIds: this.productIds,
      subtotal: this.subtotal,
      total: this.total,
      shippingFee: this.shippingFee,
      paymentMethod: this.paymentMethod,
      paymentStatus: this.paymentStatus,
      status: this.status,
      kasir: this.kasir,
      stockUpdated: this.stockUpdated,
      shippingMethod: this.shippingMethod,
      cogs: cogs ?? this.cogs,
      grossProfit: grossProfit ?? this.grossProfit,
    );
  }

  Map<String, dynamic> toFirestore() {
    // cogs & grossProfit tidak disimpan kembali ke Firestore
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
      'paymentProofFileName': "", 
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
