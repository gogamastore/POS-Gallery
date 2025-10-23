import 'package:cloud_firestore/cloud_firestore.dart';

// Merepresentasikan struktur data untuk sebuah dokumen di koleksi /orders
class Order {
  final String? id; // ID dokumen dari Firestore, opsional saat membuat

  // Informasi Inti Transaksi
  final Timestamp date;
  final List<Map<String, dynamic>> products;
  final List<String> productIds;
  final double subtotal;
  final double total;

  // Detail Pembayaran & Status
  final String paymentMethod;
  final String paymentStatus;
  final String status; // Hanya 'Success', atau 'Cancelled'

  // Informasi Pelacakan & Pelanggan
  final String kasir;
  final Map<String, dynamic>? customerDetails; // Opsional, untuk member
  final bool stockUpdated;

  // Timestamps for tracking
  final Timestamp? createdAt;
  final Timestamp? updatedAt;
  final Timestamp? validatedAt;

  Order({
    this.id,
    required this.date,
    required this.products,
    required this.productIds,
    required this.subtotal,
    required this.total,
    required this.paymentMethod,
    this.paymentStatus = 'Paid', // Default sesuai struktur
    required this.status,
    required this.kasir,
    this.customerDetails,
    this.stockUpdated = false,
    this.createdAt,
    this.updatedAt,
    this.validatedAt,
  });

  // Factory constructor to create an Order from a Firestore document
  factory Order.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    return Order(
      id: doc.id,
      date: data['date'] as Timestamp,
      products: List<Map<String, dynamic>>.from(data['products'] ?? []),
      productIds: List<String>.from(data['productIds'] ?? []),
      subtotal: (data['subtotal'] as num).toDouble(),
      total: (data['total'] as num).toDouble(),
      paymentMethod: data['paymentMethod'] as String,
      paymentStatus: data['paymentStatus'] as String,
      status: data['status'] as String,
      kasir: data['kasir'] as String,
      stockUpdated: data['stockUpdated'] as bool? ?? false,
      createdAt: data['created_at'] as Timestamp?,
      updatedAt: data['updated_at'] as Timestamp?,
      validatedAt: data['validatedAt'] as Timestamp?,
      customerDetails: data['customerId'] != null && (data['customerId'] as String).isNotEmpty
          ? {
              'customer': data['customer'],
              'customerId': data['customerId'],
            }
          : null,
    );
  }


  // Mengonversi objek Order menjadi Map untuk disimpan ke Firestore
  Map<String, dynamic> toFirestore() {
    final Map<String, dynamic> data = {
      'date': date,
      'products': products,
      'productIds': productIds,
      'subtotal': subtotal,
      'total': total,
      'paymentMethod': paymentMethod,
      'paymentStatus': paymentStatus,
      'status': status,
      'kasir': kasir,
      'stockUpdated': stockUpdated,
      'created_at': createdAt ?? FieldValue.serverTimestamp(),
      'updated_at': FieldValue.serverTimestamp(), // Selalu perbarui saat menyimpan
      'validatedAt': validatedAt,

      // Field placeholder sesuai struktur Anda
      'paymentProofFileName': "",
      'paymentProofId': "",
      'paymentProofUploaded': false,
      'paymentProofUrl': "",
    };

    // Jika ada detail customer (member), tambahkan ke map
    if (customerDetails != null && customerDetails!.containsKey('customerId')) {
      data['customer'] = customerDetails!['customer'];
      data['customerId'] = customerDetails!['customerId'];
    } else {
      // Jika tidak ada member, isi dengan nilai default
      data['customer'] = "customer";
      data['customerId'] = "";
    }

    return data;
  }
}
