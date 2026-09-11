import 'dart:developer' as developer;

import 'package:cloud_firestore/cloud_firestore.dart' hide Order;
import '../models/order.dart';
import '../models/order_item.dart';

class OrderService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Deletes a single order by its ID.
  /// This is a simple deletion and does NOT handle stock restoration.
  /// Use with caution, primarily for 'processing' orders that are being finalized.
  Future<void> deleteOrder(String orderId) async {
    try {
      await _firestore.collection('orders').doc(orderId).delete();
    } catch (e, s) {
      developer.log('Gagal menghapus pesanan: $orderId', name: 'OrderService.deleteOrder', error: e, stackTrace: s);
      rethrow;
    }
  }

  /// Creates a new order and handles stock reduction in a single transaction.
  /// PERBAIKAN: Melewatkan pengurangan stok untuk produk non-katalog (ID diawali 'temp_').
  Future<void> createOrder(Order order) async {
    final CollectionReference orderCollection = _firestore.collection('orders');

    await _firestore.runTransaction((transaction) async {
      // Pisahkan produk katalog dan non-katalog
      final catalogProducts = order.products
          .where((item) => !(item['productId'] as String).startsWith('temp_'))
          .toList();

      if (catalogProducts.isNotEmpty) {
        // 1. Get all product references and their data in one batch for catalog products
        final productRefs = catalogProducts
            .map((item) =>
                _firestore.collection('products').doc(item['productId']))
            .toList();
        final productSnapshots =
            await Future.wait(productRefs.map(transaction.get));

        // 2. Validate stock for all catalog products
        for (int i = 0; i < productSnapshots.length; i++) {
          final productSnapshot = productSnapshots[i];
          final item = catalogProducts[i];

          if (!productSnapshot.exists) {
            throw Exception(
                'Produk dengan ID ${item['productId']} tidak ditemukan.');
          }

          final productData = productSnapshot.data() as Map<String, dynamic>;
          final currentStock = (productData['stock'] as num).toInt();
          final quantityNeeded = (item['quantity'] as num).toInt();

          if (currentStock < quantityNeeded) {
            final productName = productData['name'] ?? 'N/A';
            throw Exception(
                'Stok untuk "$productName" tidak mencukupi. Sisa: $currentStock, Dibutuhkan: $quantityNeeded.');
          }
        }

        // 3. Decrement stock for all catalog products
        for (int i = 0; i < productRefs.length; i++) {
          final productRef = productRefs[i];
          final quantityToDecrement =
              (catalogProducts[i]['quantity'] as num).toInt();
          transaction.update(productRef,
              {'stock': FieldValue.increment(-quantityToDecrement)});
        }
      }

      // 4. Create the new order (contains all products, catalog and temporary)
      final newOrderRef = orderCollection.doc();
      transaction.set(newOrderRef, order.toFirestore());
    });
  }

  Future<List<Order>> getOrdersByDateRange(DateTime start, DateTime end) async {
    try {
      final querySnapshot = await _firestore
          .collection('orders')
          .where('createdAt', isGreaterThanOrEqualTo: start)
          .where('createdAt', isLessThan: end)
          .orderBy('createdAt', descending: true)
          .get();
      if (querySnapshot.docs.isEmpty) {
        return [];
      }
      return querySnapshot.docs.map((doc) => Order.fromFirestore(doc)).toList();
    } on FirebaseException catch (e, s) {
      if (e.code == 'failed-precondition') {
        final urlMatch = RegExp(
                r'(https://console.firebase.google.com/project/[^/]+/database/[^/]+/indexes\?create_composite=.*?)')
            .firstMatch(e.message ?? '');
        if (urlMatch != null) {
          final url = urlMatch.group(0);
          developer.log(
            'FIRESTORE INDEX REQUIRED!\nBuka URL ini di browser untuk membuatnya:\n$url',
            name: 'FirestoreIndex',
            level: 1000, // SEVERE
            error: e,
            stackTrace: s,
          );
        } else {
          developer.log('Missing Firestore index.', error: e, stackTrace: s);
        }
      }
      rethrow;
    } catch (e, s) {
      developer.log('An unexpected error occurred while fetching orders.',
          error: e, stackTrace: s);
      rethrow;
    }
  }

  /// Fetches all orders, sorted by date, and handles potential Firestore index errors.
  Future<List<Order>> getAllOrders() async {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final todayEnd = todayStart.add(const Duration(days: 1));
    return getOrdersByDateRange(todayStart, todayEnd);
  }

  /// Fetches a single order by its ID.
  Future<Order?> getOrderById(String orderId) async {
    final doc = await _firestore.collection('orders').doc(orderId).get();
    if (doc.exists) {
      return Order.fromFirestore(doc);
    }
    return null;
  }

  /// Updates an order's status and restores stock if cancelled.
  Future<void> updateOrderStatus(String orderId, String newStatus) async {
    final orderRef = _firestore.collection('orders').doc(orderId);

    await _firestore.runTransaction((transaction) async {
      final orderSnapshot = await transaction.get(orderRef);
      if (!orderSnapshot.exists) {
        throw Exception(
            'Pesanan tidak ditemukan saat mencoba memperbarui status.');
      }

      final order = Order.fromFirestore(orderSnapshot);

      // Restore stock if the order is cancelled and stock was previously updated
      if (newStatus == 'Cancelled' && order.status != 'Cancelled' && order.stockUpdated) {
        for (final item in order.products) {
          // PERBAIKAN: Hanya kembalikan stok untuk produk katalog
          if (!(item['productId'] as String).startsWith('temp_')) {
            final productRef =
                _firestore.collection('products').doc(item['productId']);
            final quantityToRestore = (item['quantity'] as num).toInt();
            transaction.update(productRef, {'stock': FieldValue.increment(quantityToRestore)});
          }
        }
         transaction.update(orderRef, {'stockUpdated': false}); // Tandai bahwa stok telah dikembalikan
      }

      transaction.update(orderRef, {
        'status': newStatus,
        'updated_at': FieldValue.serverTimestamp(),
      });
    });
  }

  /// Updates order details, including products and totals, and adjusts stock accordingly.
  Future<void> updateOrderDetails(String orderId, List<OrderItem> newProducts,
      double newSubtotal, double newTotal,
      {String? validatorName}) async {
    final orderRef = _firestore.collection('orders').doc(orderId);

    await _firestore.runTransaction((transaction) async {
      // Get old order data
      final oldOrderSnapshot = await transaction.get(orderRef);
      if (!oldOrderSnapshot.exists) {
        throw Exception('Pesanan tidak ditemukan untuk diperbarui!');
      }
      final oldOrder = Order.fromFirestore(oldOrderSnapshot);

      // Calculate stock changes
      final stockChanges =
          _calculateStockChanges(oldOrder.products, newProducts);

      // Validate & apply stock changes
      for (var entry in stockChanges.entries) {
        // PERBAIKAN: Hanya proses stok untuk produk katalog
        if (!entry.key.startsWith('temp_')) {
          final productRef = _firestore.collection('products').doc(entry.key);
          final stockChange = entry.value;

          if (stockChange > 0) {
            // If quantity increases, check stock first
            final productSnapshot = await transaction.get(productRef);
            if (!productSnapshot.exists) {
              throw Exception('Produk ID ${entry.key} tidak ada.');
            }
            final currentStock =
                (productSnapshot.data() as Map<String, dynamic>)['stock'] as int;
            if (currentStock < stockChange) {
              throw Exception('Stok tidak cukup untuk produk ID ${entry.key}.');
            }
          }
          transaction
              .update(productRef, {'stock': FieldValue.increment(-stockChange)});
        }
      }

      // Prepare and apply order update
      final updateData = _prepareUpdateData(
          newProducts, oldOrder.products, newSubtotal, newTotal, validatorName);
      transaction.update(orderRef, updateData);
    });
  }

  /// Helper to calculate stock changes between old and new product lists.
  Map<String, int> _calculateStockChanges(
      List<Map<String, dynamic>> oldProducts, List<OrderItem> newProducts) {
    final Map<String, int> changes = {};
    final oldQuantities = {
      for (var p in oldProducts) p['productId']: (p['quantity'] as num).toInt()
    };
    final newQuantities = {for (var p in newProducts) p.productId: p.quantity};

    final allProductIds = {...oldQuantities.keys, ...newQuantities.keys};

    for (final id in allProductIds) {
      final oldQty = oldQuantities[id] ?? 0;
      final newQty = newQuantities[id] ?? 0;
      final delta = newQty - oldQty;
      if (delta != 0) {
        changes[id] = delta;
      }
    }
    return changes;
  }

  /// Helper to prepare the data map for an order update.
  Map<String, dynamic> _prepareUpdateData(
      List<OrderItem> newProducts,
      List<Map<String, dynamic>> oldProducts,
      double newSubtotal,
      double newTotal,
      String? validatorName) {
    // Lestarikan snapshot modal saat edit: bawa `purchasePrice` lama per
    // produk agar tidak hilang ketika array `products` ditulis ulang
    // (OrderItem tak punya field purchasePrice). Produk yang benar-benar baru
    // ditambah tak dapat snapshot di sini — nanti diisi current-cost oleh
    // snapshotPurchasePrices / fallback modal terkini di laporan.
    final Map<String, dynamic> oldPurchasePrices = {
      for (final p in oldProducts)
        if (p['productId'] != null && p['purchasePrice'] != null)
          p['productId'] as String: p['purchasePrice']
    };
    final newProductsAsJson = newProducts.map((p) {
      final json = p.toJson();
      if (oldPurchasePrices.containsKey(p.productId)) {
        json['purchasePrice'] = oldPurchasePrices[p.productId];
      }
      return json;
    }).toList();
    final Map<String, dynamic> data = {
      'products': newProductsAsJson,
      'productIds': newProducts.map((p) => p.productId).toList(),
      'subtotal': newSubtotal,
      'total': newTotal,
      'updated_at': FieldValue.serverTimestamp(),
    };
    if (validatorName != null) {
      data['kasir'] = validatorName;
    }
    return data;
  }

  /// Sets the validator for a specific order.
  Future<void> setOrderValidator(String orderId, String validatorName) async {
    await _firestore.collection('orders').doc(orderId).update({
      'kasir': validatorName,
      'validatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Snapshot modal (purchasePrice) ke pesanan: isi `products[].purchasePrice`
  /// yang BELUM ada dengan modal terkini produk, tanpa mengubah field lain
  /// (status/validatedAt tak disentuh). Idempoten — snapshot lama tetap.
  ///
  /// Dipakai saat validasi & proses kirim marketplace agar laporan penjualan
  /// punya modal saat penjualan (tak berubah oleh restok). Modal diambil via
  /// `whereIn` chunk 30 (aman untuk cap 160 item unik), dokumen jauh < 1 MiB.
  Future<void> snapshotPurchasePrices(String orderId) async {
    final ref = _firestore.collection('orders').doc(orderId);
    final snap = await ref.get();
    if (!snap.exists) return;

    final rawProducts = (snap.data()?['products'] as List<dynamic>?) ?? [];
    // Hanya produk yang belum punya purchasePrice.
    final missingIds = rawProducts
        .whereType<Map>()
        .where((p) => p['purchasePrice'] == null)
        .map((p) => p['productId'] as String?)
        .whereType<String>()
        .toSet()
        .toList();
    if (missingIds.isEmpty) return;

    final Map<String, double> costs = {};
    const chunkSize = 30;
    for (var i = 0; i < missingIds.length; i += chunkSize) {
      final chunk = missingIds.sublist(i,
          i + chunkSize > missingIds.length ? missingIds.length : i + chunkSize);
      if (chunk.isEmpty) continue;
      final qs = await _firestore
          .collection('products')
          .where(FieldPath.documentId, whereIn: chunk)
          .get();
      for (final d in qs.docs) {
        costs[d.id] = (d.data()['purchasePrice'] as num?)?.toDouble() ?? 0.0;
      }
    }

    final newProducts = rawProducts.map((p) {
      if (p is Map && p['purchasePrice'] == null) {
        final m = Map<String, dynamic>.from(p);
        final pid = m['productId'] as String?;
        if (pid != null && costs.containsKey(pid)) {
          m['purchasePrice'] = costs[pid];
        }
        return m;
      }
      return p;
    }).toList();

    await ref.update({'products': newProducts});
  }
}
