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

    final Order newOrder = _buildOrder(
      id: orderRef.id,
      items: items,
      totalAmount: totalAmount,
      totalDiscount: totalDiscount,
      paymentMethod: paymentMethod,
      kasir: kasir,
      customer: customer,
      status: 'processing',
      paymentStatus: 'pending',
      stockUpdated: false, // Stok tidak diperbarui untuk draf
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

    final Order newOrder = _buildOrder(
      id: orderRef.id,
      items: items,
      totalAmount: totalAmount,
      totalDiscount: totalDiscount,
      paymentMethod: paymentMethod,
      kasir: kasir,
      customer: customer,
      status: 'success',
      paymentStatus: 'paid',
      stockUpdated: true,
      validatedAt: Timestamp.now(),
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

  /// Membuat pesanan yang menunggu pembayaran Midtrans: status 'pending',
  /// stok BELUM dikurangi. Saat pembeli membayar, webhook Midtrans di server
  /// menyetel status 'success', paymentStatus 'paid', dan mengurangi stok.
  Future<String> createPendingMidtransOrder({
    required List<PosCartItem> items,
    required double totalAmount,
    required double totalDiscount,
    required String kasir,
    Customer? customer,
  }) async {
    final DocumentReference orderRef = _firestore.collection('orders').doc();

    final Order newOrder = _buildOrder(
      id: orderRef.id,
      items: items,
      totalAmount: totalAmount,
      totalDiscount: totalDiscount,
      paymentMethod: 'midtrans',
      kasir: kasir,
      customer: customer,
      status: 'pending',
      paymentStatus: 'pending_payment',
      stockUpdated: false,
    );

    await orderRef.set(newOrder.toFirestore());
    return orderRef.id;
  }

  /// Membatalkan pesanan Midtrans yang belum dibayar. Mengembalikan `false`
  /// bila ternyata sudah lunas (webhook lebih dulu) — pesanan tidak diubah.
  Future<bool> cancelPendingMidtransOrder(String orderId) {
    final orderRef = _firestore.collection('orders').doc(orderId);
    return _firestore.runTransaction<bool>((transaction) async {
      final data = (await transaction.get(orderRef)).data();
      if (data == null) return true;
      if (data['paymentStatus'] == 'paid') return false;
      if (data['status'] == 'pending') {
        transaction.update(orderRef, {
          'status': 'cancelled',
          'paymentStatus': 'cancelled',
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
      return true;
    });
  }

  Order _buildOrder({
    required String id,
    required List<PosCartItem> items,
    required double totalAmount,
    required double totalDiscount,
    required String paymentMethod,
    required String kasir,
    required Customer? customer,
    required String status,
    required String paymentStatus,
    required bool stockUpdated,
    Timestamp? validatedAt,
  }) {
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

    return Order(
      id: id, // Menyimpan ID yang digenerate
      date: Timestamp.now(),
      createdAt: Timestamp.now(),
      products: productsData,
      productIds: items.map((item) => item.product.id).toList(),
      subtotal: totalAmount + totalDiscount,
      total: totalAmount,
      totalDiscount: totalDiscount,
      paymentMethod: paymentMethod,
      status: status,
      kasir: kasir,
      customer: customerName,
      customerId: customerId,
      customerDetails: customerDetails,
      paymentStatus: paymentStatus,
      stockUpdated: stockUpdated,
      validatedAt: validatedAt,
      shippingMethod: 'Ambil di Toko',
      shippingFee: 0,
    );
  }
}
