import 'package:cloud_firestore/cloud_firestore.dart' hide Order;
import '../models/customer.dart';
import '../models/order.dart'; 
import '../models/pos_cart_item.dart';

class PosService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> processSaleTransaction({
    required List<PosCartItem> items,
    required double totalAmount,
    required String paymentMethod,
    required String kasir,
    Customer? customer,
    String? userId, // userId dari pengguna yang login (jika ada)
  }) async {
    final WriteBatch batch = _firestore.batch();
    final DocumentReference orderRef = _firestore.collection('orders').doc();

    // PERBAIKAN: Menyesuaikan struktur data produk
    final List<Map<String, dynamic>> productsData = items
        .map((item) => {
              'productId': item.product.id, // Menggunakan productId
              'name': item.product.name,
              'imageUrl': item.product.image ?? '', // Menggunakan imageUrl
              'quantity': item.quantity,
              'price': item.product.price,
              'sku': item.product.sku, // Menambahkan SKU
            })
        .toList();

    // PERBAIKAN: Menyesuaikan struktur data pelanggan
    Map<String, dynamic>? customerDetails;
    String? customerId;
    String? customerName;

    if (customer != null) {
      customerDetails = {
        'name': customer.name,
        'address': customer.address,
        'whatsapp': customer.whatsapp,
      };
      customerId = customer.id; // Mengambil customerId dari objek Customer
      customerName = customer.name;
    }

    // Buat objek Order baru yang sesuai dengan model yang sudah disempurnakan
    final Order newOrder = Order(
      date: Timestamp.now(),
      createdAt: Timestamp.now(),
      products: productsData,
      productIds: items.map((item) => item.product.id).toList(),
      subtotal: totalAmount,
      total: totalAmount,
      paymentMethod: paymentMethod,
      status: 'success', // Status untuk penjualan POS langsung berhasil
      kasir: kasir,
      
      // PERBAIKAN: Menyimpan semua informasi customer
      customer: customerName,
      customerId: customerId, // Menyimpan ID customer
      customerDetails: customerDetails,
      
      paymentStatus: 'paid',
      stockUpdated: true, // Penjualan POS langsung mengurangi stok
      validatedAt: Timestamp.now(),
      shippingMethod: 'Ambil di Toko', // Default untuk POS
      shippingFee: 0,
    );

    // Tambahkan operasi 'set' untuk membuat order baru
    batch.set(orderRef, newOrder.toFirestore());

    // Kurangi stok untuk setiap produk
    for (final item in items) {
      final productRef = _firestore.collection('products').doc(item.product.id);
      batch.update(productRef, {'stock': FieldValue.increment(-item.quantity)});
    }

    // Jalankan semua operasi
    await batch.commit();
  }
}
