import 'package:cloud_firestore/cloud_firestore.dart' hide Order;
import '../models/customer.dart';
import '../models/order.dart'; 
import '../models/pos_cart_item.dart';

class PosService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Fungsi untuk menyimpan sebagai 'processing' tanpa mengurangi stok
  Future<void> saveOrderAsProcessing({
    required List<PosCartItem> items,
    required double totalAmount,
    required double totalDiscount,
    required String paymentMethod,
    required String kasir,
    Customer? customer,
  }) async {
    final DocumentReference orderRef = _firestore.collection('orders').doc();

    // Data produk sudah benar, tidak perlu diubah
    final List<Map<String, dynamic>> productsData = items
        .map((item) => {
              'productId': item.product.id,
              'name': item.product.name,
              'imageUrl': item.product.image ?? '',
              'quantity': item.quantity,
              'price': item.PosPrice, // Menggunakan harga dari keranjang
              'originalPrice': item.product.price,
              'sku': item.product.sku,
            })
        .toList();

    Map<String, dynamic>? customerDetails;
    String? customerId;
    String? customerName;

    if (customer != null) {
      customerDetails = {
        'name': customer.name,
        'address': customer.address,
        'whatsapp': customer.whatsapp,
      };
      customerId = customer.id;
      customerName = customer.name;
    }

    final Order newOrder = Order(
      id: orderRef.id, // Menyimpan ID yang digenerate
      date: Timestamp.now(),
      createdAt: Timestamp.now(),
      products: productsData,
      productIds: items.map((item) => item.product.id).toList(),
      subtotal: totalAmount + totalDiscount, 
      total: totalAmount,
      totalDiscount: totalDiscount,
      paymentMethod: paymentMethod,
      status: 'processing', 
      kasir: kasir,
      customer: customerName,
      customerId: customerId,
      customerDetails: customerDetails,
      paymentStatus: 'pending',
      stockUpdated: false, // Stok tidak diperbarui untuk draf
      shippingMethod: 'Ambil di Toko',
      shippingFee: 0,
    );

    // Hanya membuat pesanan, tidak ada operasi stok
    await orderRef.set(newOrder.toFirestore());
  }

  Future<String> processSaleTransaction({
    required List<PosCartItem> items,
    required double totalAmount,
    required double totalDiscount,
    required String paymentMethod,
    required String kasir,
    Customer? customer,
    String? userId,
  }) async {
    final WriteBatch batch = _firestore.batch();
    final DocumentReference orderRef = _firestore.collection('orders').doc();

    final List<Map<String, dynamic>> productsData = items
        .map((item) => {
              'productId': item.product.id,
              'name': item.product.name,
              'imageUrl': item.product.image ?? '',
              'quantity': item.quantity,
              'price': item.PosPrice, // Menggunakan harga dari keranjang
              'originalPrice': item.product.price,
              'sku': item.product.sku,
            })
        .toList();

    Map<String, dynamic>? customerDetails;
    String? customerId;
    String? customerName;

    if (customer != null) {
      customerDetails = {
        'name': customer.name,
        'address': customer.address,
        'whatsapp': customer.whatsapp,
      };
      customerId = customer.id;
      customerName = customer.name;
    }

    final Order newOrder = Order(
      id: orderRef.id, // Menyimpan ID yang digenerate
      date: Timestamp.now(),
      createdAt: Timestamp.now(),
      products: productsData,
      productIds: items.map((item) => item.product.id).toList(),
      subtotal: totalAmount + totalDiscount,
      total: totalAmount,
      totalDiscount: totalDiscount,
      paymentMethod: paymentMethod,
      status: 'success',
      kasir: kasir,
      customer: customerName,
      customerId: customerId,
      customerDetails: customerDetails,
      paymentStatus: 'paid',
      stockUpdated: true,
      validatedAt: Timestamp.now(),
      shippingMethod: 'Ambil di Toko',
      shippingFee: 0,
    );

    batch.set(orderRef, newOrder.toFirestore());

    // PERBAIKAN FINAL: Hanya kurangi stok untuk produk katalog
    for (final item in items) {
      if (!item.product.id.startsWith('temp_')) {
        final productRef = _firestore.collection('products').doc(item.product.id);
        batch.update(productRef, {'stock': FieldValue.increment(-item.quantity)});
      }
    }

    await batch.commit();
    return orderRef.id; // Mengembalikan ID pesanan
  }
}
