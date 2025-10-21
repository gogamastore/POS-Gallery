import 'package:cloud_firestore/cloud_firestore.dart';
import './order_product.dart';
// PERBAIKAN: Beri alias pada impor untuk menghindari konflik nama
import './order.dart' as app_order;

// --- FUNGSI HELPER TETAP SAMA ---
Timestamp _parseDate(dynamic date) {
  if (date is Timestamp) return date;
  if (date is DateTime) return Timestamp.fromDate(date);
  return Timestamp.now();
}

Timestamp? _parseDateOrNull(dynamic date) {
  if (date == null) return null;
  if (date is Timestamp) return date;
  if (date is DateTime) return Timestamp.fromDate(date);
  return null;
}

double? _parseDouble(dynamic value) {
  if (value is double) return value;
  if (value is int) return value.toDouble();
  if (value is String) {
    return double.tryParse(value.replaceAll(RegExp(r'[^0-9.]'), ''));
  }
  return null;
}

String _parseString(dynamic value, {String defaultValue = ''}) {
  if (value == null) return defaultValue;
  if (value is String) return value;
  return value.toString();
}

String? _parseStringOrNull(dynamic value) {
  if (value == null) return null;
  if (value is String) return value;
  return value.toString();
}

class MyOrder {
  final String id;
  final String customerId;
  final String customer;
  final String customerPhone;
  final String customerAddress;
  final Timestamp date;
  final String status;
  final String total;
  final String paymentMethod;
  final String paymentStatus;
  final String? paymentProofUrl;
  final String shippingMethod;
  final double? shippingFee;
  final List<OrderProduct> products;
  final Timestamp? updatedAt;
  final Timestamp? shippedAt;
  final String? kasir;

  MyOrder({
    required this.id,
    required this.customerId,
    required this.customer,
    required this.customerPhone,
    required this.customerAddress,
    required this.date,
    required this.status,
    required this.total,
    required this.paymentMethod,
    required this.paymentStatus,
    this.paymentProofUrl,
    required this.shippingMethod,
    this.shippingFee,
    required this.products,
    this.updatedAt,
    this.shippedAt,
    this.kasir,
  });

  factory MyOrder.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    Map<String, dynamic> customerDetails =
        data['customerDetails'] as Map<String, dynamic>? ?? {};

    dynamic totalValue = data['total'];
    String totalString;
    if (totalValue is num) {
      totalString = totalValue.toString();
    } else if (totalValue is String) {
      totalString = totalValue;
    } else {
      totalString = '0';
    }

    return MyOrder(
      id: doc.id,
      customerId: _parseString(data['customerId'], defaultValue: ''),
      customer: _parseString(data['customer'], defaultValue: 'N/A'),
      customerPhone:
          _parseString(customerDetails['whatsapp'], defaultValue: '-'),
      customerAddress:
          _parseString(customerDetails['address'], defaultValue: '-'),
      date: _parseDate(data['date']),
      status:
          _parseString(data['status'], defaultValue: 'pending').toLowerCase(),
      total: totalString,
      paymentMethod: _parseString(data['paymentMethod'], defaultValue: 'N/A'),
      paymentStatus: _parseString(data['paymentStatus'], defaultValue: 'unpaid')
          .toLowerCase(),
      paymentProofUrl: _parseStringOrNull(data['paymentProofUrl']),
      shippingMethod: _parseString(data['shippingMethod'], defaultValue: 'N/A'),
      shippingFee: _parseDouble(data['shippingFee']),
      products: (data['products'] as List<dynamic>?)
              ?.map(
                  (item) => OrderProduct.fromJson(item as Map<String, dynamic>))
              .toList() ??
          [],
      updatedAt:
          data['updatedAt'] != null ? _parseDate(data['updatedAt']) : null,
      shippedAt: _parseDateOrNull(data['shippedAt']),
      kasir: _parseStringOrNull(data['kasir']),
    );
  }

  // --- BARU: Factory untuk konversi dari app_order.Order ke MyOrder ---
  factory MyOrder.fromOrder(app_order.Order order) {
    return MyOrder(
      id: order.id,
      customerId: order.customerId,
      customer: order.customer,
      customerPhone: order.customerPhone,
      customerAddress: order.customerAddress,
      date: order.date,
      status: order.status,
      total: order.total,
      paymentMethod: order.paymentMethod,
      paymentStatus: order.paymentStatus,
      paymentProofUrl: order.paymentProofUrl,
      shippingMethod: order.shippingMethod,
      shippingFee: order.shippingFee,
      products: order.products,
      updatedAt: order.updatedAt,
      shippedAt: order.shippedAt,
      kasir: order.kasir,
    );
  }

  // Konversi dari MyOrder ke app_order.Order (model utama)
  app_order.Order toOrder() {
    return app_order.Order(
      id: id,
      customerId: customerId,
      customer: customer,
      customerPhone: customerPhone,
      customerAddress: customerAddress,
      date: date,
      status: status,
      total: total,
      paymentMethod: paymentMethod,
      paymentStatus: paymentStatus,
      paymentProofUrl: paymentProofUrl,
      shippingMethod: shippingMethod,
      shippingFee: shippingFee,
      products: products,
      updatedAt: updatedAt,
      shippedAt: shippedAt,
      kasir: kasir,
    );
  }
}
