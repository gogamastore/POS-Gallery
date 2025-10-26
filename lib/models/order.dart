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
  final num totalDiscount;
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
    required this.totalDiscount,
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

    // PERBAIKAN: Menghilangkan underscore dari nama fungsi lokal
    Timestamp? parseTimestamp(dynamic value) {
      if (value is Timestamp) return value;
      if (value is String) return Timestamp.fromDate(DateTime.parse(value));
      return null;
    }

    return Order(
      id: doc.id,
      date: data['date'] as Timestamp,
      createdAt: parseTimestamp(data['created_at']), // Menggunakan fungsi yang sudah diganti nama
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
      totalDiscount: data['totalDiscount'] as num? ?? 0,
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
  
  // --- METHOD copyWith DIPERBARUI ---
  Order copyWith({
    double? cogs,
    double? grossProfit,
  }) {
    // PERBAIKAN: Menghilangkan 'this.' yang tidak perlu
    return Order(
      id: id,
      date: date,
      createdAt: createdAt,
      updatedAt: updatedAt,
      validatedAt: validatedAt,
      shippedAt: shippedAt,
      customer: customer,
      customerId: customerId,
      customerDetails: customerDetails,
      products: products,
      productIds: productIds,
      subtotal: subtotal,
      total: total,
      totalDiscount: totalDiscount,
      shippingFee: shippingFee,
      paymentMethod: paymentMethod,
      paymentStatus: paymentStatus,
      status: status,
      kasir: kasir,
      stockUpdated: stockUpdated,
      shippingMethod: shippingMethod,
      cogs: cogs ?? this.cogs, // 'this.' di sini diperlukan untuk membedakan dengan parameter
      grossProfit: grossProfit ?? this.grossProfit, // 'this.' di sini diperlukan
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
      'totalDiscount': totalDiscount,
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
