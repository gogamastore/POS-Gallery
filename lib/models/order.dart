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

  // Biaya tambahan pesanan marketplace (null/0 pada pesanan POS).
  final num? adminFee;
  final num? serviceFee;

  // Payment Info
  final String paymentMethod;
  final String paymentStatus;

  // Status & Tracking
  final String status;
  final String kasir;
  /// Kanal penjualan: 'pos' (kasir) atau 'marketplace'. Null untuk data lama.
  final String? source;
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
    this.adminFee,
    this.serviceFee,
    required this.paymentMethod,
    required this.paymentStatus,
    required this.status,
    required this.kasir,
    this.source,
    required this.stockUpdated,
    this.shippingMethod,
    // Default value untuk field baru
    this.cogs = 0.0,
    this.grossProfit = 0.0,
  });

  factory Order.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) =>
      Order.fromMap(doc.id, doc.data()!);

  /// Map mentah dokumen `orders/{id}` -> [Order]. Dipakai juga oleh layar
  /// marketplace yang membaca dokumennya lewat StreamBuilder. Pesanan
  /// marketplace ditulis checkout web/app pembeli, jadi sebagian field POS
  /// bisa absen — semua pembacaan dibuat toleran.
  factory Order.fromMap(String id, Map<String, dynamic> data) {
    // PERBAIKAN: Menghilangkan underscore dari nama fungsi lokal
    Timestamp? parseTimestamp(dynamic value) {
      if (value is Timestamp) return value;
      if (value is String) return Timestamp.fromDate(DateTime.parse(value));
      return null;
    }

    final details = data['customerDetails'] as Map<String, dynamic>?;

    return Order(
      id: id,
      // Marketplace kadang hanya punya `createdAt`; jangan sampai gagal parse.
      date: parseTimestamp(data['date']) ??
          parseTimestamp(data['createdAt']) ??
          Timestamp.now(),
      createdAt: parseTimestamp(data['created_at']), // Menggunakan fungsi yang sudah diganti nama
      updatedAt: data['updatedAt'] as Timestamp?,
      validatedAt: data['validatedAt'] as Timestamp?,
      shippedAt: data['shippedAt'] as Timestamp?,
      customer: data['customer'] as String? ?? details?['name'] as String?,
      customerId: data['customerId'] as String?,
      customerDetails: details,
      products: List<Map<String, dynamic>>.from(data['products'] ?? []),
      productIds: List<String>.from(data['productIds'] ?? []),
      subtotal: data['subtotal'] as num? ?? 0,
      total: data['total'] as num? ?? 0,
      // Marketplace menulis potongannya sebagai `voucherDiscount`.
      totalDiscount:
          data['totalDiscount'] as num? ?? data['voucherDiscount'] as num? ?? 0,
      shippingFee: data['shippingFee'] as num?,
      adminFee: data['adminFee'] as num?,
      serviceFee: data['serviceFee'] as num?,
      paymentMethod: data['paymentMethod'] as String? ?? 'N/A',
      paymentStatus: data['paymentStatus'] as String? ?? 'N/A',
      status: data['status'] as String? ?? 'N/A',
      kasir: data['kasir'] as String? ?? 'N/A',
      source: data['source'] as String?,
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
      adminFee: adminFee,
      serviceFee: serviceFee,
      paymentMethod: paymentMethod,
      paymentStatus: paymentStatus,
      status: status,
      kasir: kasir,
      source: source,
      stockUpdated: stockUpdated,
      shippingMethod: shippingMethod,
      cogs: cogs ?? this.cogs, // 'this.' di sini diperlukan untuk membedakan dengan parameter
      grossProfit: grossProfit ?? this.grossProfit, // 'this.' di sini diperlukan
    );
  }

  Map<String, dynamic> toFirestore() {
    // cogs & grossProfit tidak disimpan kembali ke Firestore
    return {
      // Penanda kanal penjualan. toFirestore() hanya dipakai saat MEMBUAT
      // pesanan dari kasir POS, jadi selalu 'pos' di sini. Pesanan marketplace
      // ditulis oleh checkout web/app pembeli dengan source 'marketplace'.
      'source': 'pos',
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
