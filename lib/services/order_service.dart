import 'dart:developer' as developer;

import 'package:cloud_firestore/cloud_firestore.dart' hide Order;
import '../models/order.dart';
import '../models/order_item.dart';

class OrderService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Creates a new order and handles stock reduction in a single transaction.
  Future<void> createOrder(Order order) async {
    final CollectionReference orderCollection = _firestore.collection('orders');

    await _firestore.runTransaction((transaction) async {
      // 1. Get all product references and their data in one batch
      final productRefs = order.products
          .map((item) =>
              _firestore.collection('products').doc(item['productId']))
          .toList();
      final productSnapshots =
          await Future.wait(productRefs.map(transaction.get));

      // 2. Validate stock for all products
      for (int i = 0; i < productSnapshots.length; i++) {
        final productSnapshot = productSnapshots[i];
        final item = order.products[i];

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

      // 3. Decrement stock for all products
      for (int i = 0; i < productRefs.length; i++) {
        final productRef = productRefs[i];
        final quantityToDecrement =
            (order.products[i]['quantity'] as num).toInt();
        transaction.update(
            productRef, {'stock': FieldValue.increment(-quantityToDecrement)});
      }

      // 4. Create the new order
      final newOrderRef = orderCollection.doc();
      transaction.set(newOrderRef, order.toFirestore());
    });
  }

  /// Fetches all orders, sorted by date, and handles potential Firestore index errors.
  Future<List<Order>> getAllOrders() async {
    try {
      final querySnapshot = await _firestore
          .collection('orders')
          .orderBy('date', descending: true)
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
            'FIRESTORE INDEX REQUIRED!\\nBuka URL ini di browser untuk membuatnya:\\n$url',
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

      // Restore stock if the order is cancelled
      if (newStatus == 'Cancelled' && order.status != 'Cancelled') {
        for (final item in order.products) {
          final productRef =
              _firestore.collection('products').doc(item['productId']);
          final quantityToRestore = (item['quantity'] as num).toInt();
          transaction.update(
              productRef, {'stock': FieldValue.increment(quantityToRestore)});
        }
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

      // Prepare and apply order update
      final updateData =
          _prepareUpdateData(newProducts, newSubtotal, newTotal, validatorName);
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
  Map<String, dynamic> _prepareUpdateData(List<OrderItem> newProducts,
      double newSubtotal, double newTotal, String? validatorName) {
    final newProductsAsJson = newProducts.map((p) => p.toJson()).toList();
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
}
