// 'hide Order' ditambahkan untuk mengatasi ambiguitas.
import 'package:cloud_firestore/cloud_firestore.dart' hide Order;
import '../models/customer.dart';
import '../models/order.dart'; // Ini adalah model Order kita yang benar.
import '../models/pos_cart_item.dart';

class PosService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> processSaleTransaction({
    required List<PosCartItem> items,
    required double totalAmount,
    required String paymentMethod,
    required String kasir,
    Customer? customer,
  }) async {
    final WriteBatch batch = _firestore.batch();
    final DocumentReference orderRef = _firestore.collection('orders').doc();

    // 1. Siapkan data produk untuk disimpan di order.
    final List<Map<String, dynamic>> productsData = items
        .map((item) => {
              'productId': item.product.id,
              'name': item.product.name,
              'image': item.product.image ?? '',
              'quantity': item.quantity,
              // --- PERBAIKAN FINAL: Menggunakan 'item.product.price' ---
              'price': item.product.price,
            })
        .toList();

    // 2. Siapkan detail customer jika ada.
    Map<String, dynamic>? customerDetails;
    if (customer != null) {
      customerDetails = {
        'name': customer.name,
        'address': customer.address,
        'whatsapp': customer.whatsapp,
      };
    }

    // 3. Buat objek Order baru sesuai model yang sudah diperbarui.
    final Order newOrder = Order(
      date: Timestamp.now(),
      products: productsData,
      productIds: items.map((item) => item.product.id).toList(),
      subtotal: totalAmount,
      total: totalAmount, // Untuk POS, subtotal dan total sama.
      paymentMethod: paymentMethod,
      status: 'Success', // Status untuk penjualan POS langsung berhasil.
      kasir: kasir,
      customerDetails: customerDetails,
      paymentStatus: 'Paid', // Penjualan POS selalu dianggap lunas.
    );

    // 4. Tambahkan operasi 'set' untuk membuat order baru ke dalam batch.
    batch.set(orderRef, newOrder.toFirestore());

    // 5. KRUSIAL: Kurangi stok untuk setiap produk yang terjual.
    for (final item in items) {
      final productRef = _firestore.collection('products').doc(item.product.id);
      batch.update(productRef, {'stock': FieldValue.increment(-item.quantity)});
    }

    // 6. Jalankan semua operasi dalam satu transaksi atomik.
    await batch.commit();
  }
}
