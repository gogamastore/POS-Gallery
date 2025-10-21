import 'package:cloud_firestore/cloud_firestore.dart' hide Order;

import '../models/order.dart';
import '../models/product.dart';
import '../models/order_product.dart';
import '../models/order_item.dart';

class OrderService {
  final _db = FirebaseFirestore.instance;

  // Metode untuk membuat pesanan dari Map
  Future<void> createOrderFromMap(Map<String, dynamic> orderData) async {
    final orderRef = _db.collection('orders').doc();

    await _db.runTransaction((transaction) async {
      final productsToUpdate = orderData['products'] as List<dynamic>? ?? [];

      for (final itemData in productsToUpdate) {
        final item = OrderProduct.fromJson(itemData as Map<String, dynamic>);
        final productRef = _db.collection('products').doc(item.productId);
        final productSnapshot = await transaction.get(productRef);

        if (!productSnapshot.exists) {
          throw Exception(
              'Produk dengan ID ${item.productId} tidak ditemukan.');
        }

        final data = productSnapshot.data()!;

        final dynamic stockValue = data['stock'];
        num currentStock;
        if (stockValue is num) {
          currentStock = stockValue;
        } else if (stockValue is String) {
          currentStock = num.tryParse(stockValue) ?? 0;
        } else {
          currentStock = 0;
        }

        if (currentStock < item.quantity) {
          final productName = data['name'] ?? 'N/A';
          throw Exception(
              'Stok untuk "$productName" tidak mencukupi. Sisa: $currentStock, Dibutuhkan: ${item.quantity}.');
        }

        transaction.update(
            productRef, {'stock': FieldValue.increment(-item.quantity)});
      }

      transaction.set(orderRef, orderData);
    });
  }

  Future<void> createOrder(Order order) async {
    final orderRef = _db.collection('orders').doc();

    await _db.runTransaction((transaction) async {
      for (final item in order.products) {
        final productRef = _db.collection('products').doc(item.productId);
        final productSnapshot = await transaction.get(productRef);

        if (!productSnapshot.exists) {
          throw Exception(
              'Produk dengan ID ${item.productId} tidak ditemukan.');
        }

        final data = productSnapshot.data()!;
        final dynamic stockValue = data['stock'];
        num currentStock;
        if (stockValue is num) {
          currentStock = stockValue;
        } else if (stockValue is String) {
          currentStock = num.tryParse(stockValue) ?? 0;
        } else {
          currentStock = 0;
        }

        if (currentStock < item.quantity) {
          final productName = data['name'] ?? 'N/A';
          throw Exception(
              'Stok untuk "$productName" tidak mencukupi. Sisa: $currentStock, Dibutuhkan: ${item.quantity}.');
        }

        transaction.update(
            productRef, {'stock': FieldValue.increment(-item.quantity)});
      }

      transaction.set(orderRef, order.toFirestore());
    });
  }

  Future<void> markOrderAsPaid(String orderId) async {
    final orderRef = _db.collection('orders').doc(orderId);
    await orderRef.update({
      'paymentStatus': 'Paid',
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<List<OrderProduct>> _enrichProducts(
      List<OrderProduct> orderProducts) async {
    if (orderProducts.isEmpty) return [];

    final productIds = orderProducts.map((p) => p.productId).toSet().toList();
    if (productIds.isEmpty) return [];

    final Map<String, Product> productMap = {};
    const chunkSize = 30;

    for (var i = 0; i < productIds.length; i += chunkSize) {
      final chunk = productIds.sublist(
          i,
          i + chunkSize > productIds.length
              ? productIds.length
              : i + chunkSize);

      if (chunk.isNotEmpty) {
        final productSnapshots = await _db
            .collection('products')
            .where(FieldPath.documentId, whereIn: chunk)
            .get();

        for (var doc in productSnapshots.docs) {
          productMap[doc.id] = Product.fromFirestore(doc);
        }
      }
    }

    return orderProducts.map((orderProduct) {
      final productDetails = productMap[orderProduct.productId];
      return orderProduct.copyWith(
        name: productDetails?.name ?? orderProduct.name,
        sku: productDetails?.sku,
        imageUrl: productDetails?.image,
      );
    }).toList();
  }

  Future<void> setValidationTimestamp(String orderId) async {
    final orderRef = _db.collection('orders').doc(orderId);
    await orderRef.update({
      'validatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> setOrderValidator(String orderId, String validatorName) async {
    final orderRef = _db.collection('orders').doc(orderId);
    await orderRef.update({
      'kasir': validatorName,
    });
  }

  Future<List<Order>> getOrdersByStatus(List<String> statuses) async {
    if (statuses.isEmpty) {
      return [];
    }
    final snapshot = await _db
        .collection('orders')
        .where('status', whereIn: statuses)
        .orderBy('date', descending: true)
        .get();
    final orders =
        snapshot.docs.map((doc) => Order.fromFirestore(doc)).toList();
    final enrichedOrders = await Future.wait(orders.map((order) async {
      final enrichedProducts = await _enrichProducts(order.products);
      return order.copyWith(products: enrichedProducts);
    }));
    return enrichedOrders;
  }

  Future<List<Order>> getAllOrders() async {
    final snapshot =
        await _db.collection('orders').orderBy('date', descending: true).get();
    final orders =
        snapshot.docs.map((doc) => Order.fromFirestore(doc)).toList();
    final enrichedOrders = await Future.wait(orders.map((order) async {
      final enrichedProducts = await _enrichProducts(order.products);
      return order.copyWith(products: enrichedProducts);
    }));
    return enrichedOrders;
  }

  Future<Order?> getOrderById(String orderId) async {
    final doc = await _db.collection('orders').doc(orderId).get();
    if (doc.exists) {
      final order = Order.fromFirestore(doc);
      final enrichedProducts = await _enrichProducts(order.products);
      return order.copyWith(products: enrichedProducts);
    }
    return null;
  }

  Future<void> updateOrderStatus(String orderId, String newStatus) async {
    final orderRef = _db.collection('orders').doc(orderId);
    final normalizedNewStatus = newStatus.toLowerCase();

    if (normalizedNewStatus == 'cancelled') {
      await _db.runTransaction((transaction) async {
        final orderSnapshot = await transaction.get(orderRef);
        if (!orderSnapshot.exists) {
          throw Exception('Pesanan tidak ditemukan saat mencoba membatalkan.');
        }

        final orderData = Order.fromFirestore(orderSnapshot);

        if (orderData.status.toLowerCase() == 'cancelled') {
          return;
        }

        for (final productInOrder in orderData.products) {
          final productRef =
              _db.collection('products').doc(productInOrder.productId);
          transaction.update(productRef,
              {'stock': FieldValue.increment(productInOrder.quantity)});
        }

        transaction.update(orderRef, {
          'status': 'Cancelled',
          'updatedAt': FieldValue.serverTimestamp(),
        });
      });
    } else {
      final updateData = <String, dynamic>{
        'status': newStatus,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (newStatus == 'Delivered') {
        updateData['deliveredAt'] = FieldValue.serverTimestamp();
      }

      await orderRef.update(updateData);
    }
  }

  Future<void> updateOrderDetails(String orderId, List<OrderItem> newProducts,
      double shippingFee, double newSubtotal, double newTotal,
      {String? validatorName}) async {
    final orderRef = _db.collection('orders').doc(orderId);

    await _db.runTransaction((transaction) async {
      final oldOrderSnapshot = await transaction.get(orderRef);
      if (!oldOrderSnapshot.exists) {
        throw Exception('Pesanan tidak ditemukan!');
      }

      final oldOrderData = oldOrderSnapshot.data()!;
      final oldProducts = (oldOrderData['products'] as List)
          .map((p) => OrderItem.fromJson(p as Map<String, dynamic>))
          .toList();

      final Map<String, int> oldQuantities = {
        for (var p in oldProducts) p.productId: p.quantity
      };
      final Map<String, int> newQuantities = {
        for (var p in newProducts) p.productId: p.quantity
      };
      final allProductIds = {...oldQuantities.keys, ...newQuantities.keys};
      final Map<String, int> stockDelta = {};

      for (var productId in allProductIds) {
        final oldQty = oldQuantities[productId] ?? 0;
        final newQty = newQuantities[productId] ?? 0;
        final delta = newQty - oldQty;
        if (delta != 0) {
          stockDelta[productId] = -delta;
        }
      }

      final Map<String, DocumentSnapshot> productSnapshots = {};
      for (final productId in stockDelta.keys) {
        productSnapshots[productId] =
            await transaction.get(_db.collection('products').doc(productId));
      }

      for (final entry in stockDelta.entries) {
        final productId = entry.key;
        final change = entry.value;
        final productSnapshot = productSnapshots[productId]!;

        if (!productSnapshot.exists) {
          throw Exception('Produk dengan ID $productId tidak ditemukan.');
        }
        final data = productSnapshot.data()! as Map<String, dynamic>;

        final dynamic stockValue = data['stock'];
        num currentStock;
        if (stockValue is num) {
          currentStock = stockValue;
        } else if (stockValue is String) {
          currentStock = num.tryParse(stockValue) ?? 0;
        } else {
          currentStock = 0;
        }

        if (currentStock + change < 0) {
          final productName = data['name'] ?? 'N/A';
          throw Exception(
              'Stok untuk "$productName" tidak mencukupi. Sisa: $currentStock, Dibutuhkan: ${-change}.');
        }
      }

      for (final entry in stockDelta.entries) {
        final productId = entry.key;
        final change = entry.value;
        transaction.update(_db.collection('products').doc(productId),
            {'stock': FieldValue.increment(change)});
      }

      final newProductsAsJson = newProducts.map((p) => p.toJson()).toList();

      final Map<String, dynamic> updateData = {
        'products': newProductsAsJson,
        'productIds': newProducts.map((p) => p.productId).toList(),
        'shippingFee': shippingFee,
        'subtotal': newSubtotal.toInt(),
        'total': newTotal.toInt(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (validatorName != null) {
        updateData['kasir'] = validatorName;
      }

      transaction.update(orderRef, updateData);
    });
  }
}
