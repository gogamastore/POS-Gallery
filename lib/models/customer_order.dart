import 'package:cloud_firestore/cloud_firestore.dart';
import 'order_creation_product.dart';

// Kelas ini tidak perlu diubah.
class CustomerDetails {
  final String name;
  final String address;
  final String whatsapp;

  CustomerDetails({
    required this.name,
    required this.address,
    required this.whatsapp,
  });

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'address': address,
      'whatsapp': whatsapp,
    };
  }
}

// --- MODEL DIPERBARUI AGAR 100% KOMPATIBEL DENGAN 'Order.fromFirestore()' ---
class CustomerOrder {
  // Properti yang relevan untuk membuat pesanan baru
  final String customer;
  final CustomerDetails customerDetails;
  final List<OrderCreationProduct> products;
  final num total;
  final num shippingFee;
  final String shippingMethod;
  final String status;
  final String paymentMethod;
  final String paymentStatus;
  final String? paymentProofUrl;

  CustomerOrder({
    required this.customer,
    required this.customerDetails,
    required this.products,
    required this.total,
    required this.shippingFee,
    required this.shippingMethod,
    required this.status,
    required this.paymentMethod,
    required this.paymentStatus,
    this.paymentProofUrl,
  });

  // --- toFirestore() DIUBAH TOTAL UNTUK KOMPATIBILITAS PENUH ---
  Map<String, dynamic> toFirestore() {
    return {
      // Kunci-kunci ini sekarang sama persis dengan yang dibaca oleh Order.fromFirestore()
      'customer': customer,
      'customerDetails': customerDetails.toMap(),
      'date': FieldValue.serverTimestamp(), // Firestore akan mengubah ini menjadi Timestamp
      'status': status,
      'total': total.toString(), // DIUBAH: `Order` mengharapkan String, kita kirim String
      'paymentMethod': paymentMethod,
      'paymentStatus': paymentStatus,
      'paymentProofUrl': paymentProofUrl, // Bisa null
      'shippingMethod': shippingMethod,
      'shippingFee': shippingFee,
      'products': products.map((p) => p.toJson()).toList(), // toJson() sekarang menghasilkan imageUrl
      'productIds': products.map((p) => p.productId).toList(),
      'updatedAt': FieldValue.serverTimestamp(),
      'shippedAt': null, // Pastikan ada, meskipun null
      'kasir': null,     // Pastikan ada, meskipun null
    };
  }
}
