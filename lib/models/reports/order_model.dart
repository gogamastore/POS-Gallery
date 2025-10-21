import 'package:cloud_firestore/cloud_firestore.dart';
import 'order_product_model.dart';

// Model ini digunakan untuk detail lengkap dalam dialog faktur
class FullOrder {
  final String id;
  final String customerName;
  final String? customerId;
  final String status;
  final String paymentStatus;
  final double total;
  final double subtotal;
  final double shippingFee;
  final Timestamp date;
  final List<OrderProduct> products;
  // Detail pelanggan bisa ditambahkan di sini jika perlu
  final Map<String, dynamic>? customerDetails;

  FullOrder({
    required this.id,
    required this.customerName,
    this.customerId,
    required this.status,
    required this.paymentStatus,
    required this.total,
    required this.subtotal,
    required this.shippingFee,
    required this.date,
    required this.products,
    this.customerDetails,
  });

  factory FullOrder.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;

    // Konversi produk dari List<Map> ke List<OrderProduct>
    List<OrderProduct> productsList = [];
    if (data['products'] != null) {
      productsList = (data['products'] as List)
          .map((prod) => OrderProduct.fromMap(prod as Map<String, dynamic>))
          .toList();
    }

    return FullOrder(
      id: doc.id,
      customerName: data['customer'] ?? 'N/A',
      customerId: data['customerId'],
      status: data['status'] ?? 'pending',
      paymentStatus: data['paymentStatus'] ?? 'unpaid',
      total: (data['total'] ?? 0.0).toDouble(),
      subtotal: (data['subtotal'] ?? 0.0).toDouble(),
      shippingFee: (data['shippingFee'] ?? 0.0).toDouble(),
      date: data['date'] ?? Timestamp.now(),
      products: productsList,
      customerDetails: data['customerDetails'] as Map<String, dynamic>?,
    );
  }
}

// Model ini lebih ringan, digunakan untuk daftar di riwayat transaksi
class SimpleOrder {
  final String id;
  final String customerName;
  final String? customerId;
  final String status;
  final String paymentStatus;
  final double total;
  final DateTime date;

  SimpleOrder({
    required this.id,
    required this.customerName,
    this.customerId,
    required this.status,
    required this.paymentStatus,
    required this.total,
    required this.date,
  });

   factory SimpleOrder.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return SimpleOrder(
      id: doc.id,
      customerName: data['customer'] ?? 'N/A',
      customerId: data['customerId'],
      status: data['status'] ?? 'pending',
      paymentStatus: data['paymentStatus'] ?? 'unpaid',
      total: (data['total'] ?? 0.0).toDouble(),
      date: (data['date'] as Timestamp).toDate(),
    );
  }
}
