import 'dart:async';
import 'dart:developer';

import 'package:cloud_firestore/cloud_firestore.dart' hide Order;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/order.dart'; 
import '../models/order_item.dart';
import '../services/order_service.dart';

final orderServiceProvider = Provider<OrderService>((ref) => OrderService());

// Provider untuk rentang tanggal
final dateRangeProvider = StateProvider<DateTimeRange>((ref) {
  final now = DateTime.now();
  final todayStart = DateTime(now.year, now.month, now.day);
  final todayEnd = todayStart.add(const Duration(days: 1));
  return DateTimeRange(start: todayStart, end: todayEnd);
});

final allOrdersProvider = FutureProvider.autoDispose<List<Order>>((ref) async {
  final dateRange = ref.watch(dateRangeProvider);
  return ref.watch(orderServiceProvider).getOrdersByDateRange(dateRange.start, dateRange.end);
});

final orderFilterProvider = StateProvider<String>((ref) => 'processing');

final filteredOrdersProvider =
    Provider.autoDispose<AsyncValue<List<Order>>>((ref) {
  final filter = ref.watch(orderFilterProvider);
  final allOrdersAsync = ref.watch(allOrdersProvider);

  return allOrdersAsync.when(
    data: (orders) {
      if (filter == 'all') {
        return AsyncValue.data(orders);
      }
      final filtered = orders
          .where((o) => o.status.toLowerCase() == filter.toLowerCase())
          .toList();
      return AsyncValue.data(filtered);
    },
    loading: () => const AsyncValue.loading(),
    error: (e, s) => AsyncValue.error(e, s),
  );
});

class OrderActionsNotifier extends AutoDisposeNotifier<void> {
  @override
  void build() {}

  Future<void> refreshOrders() async {
    ref.invalidate(allOrdersProvider);
    // Juga invalidasi detail jika ada yang terbuka
    // Ini adalah pendekatan sederhana; bisa lebih spesifik jika diperlukan
  }

  Future<void> deleteOrder(String orderId) async {
    final orderService = ref.read(orderServiceProvider);
    try {
      await orderService.deleteOrder(orderId);
      refreshOrders();
    } catch (e, s) {
      log('Gagal menghapus pesanan: $e', name: 'OrderDeletionError', error: e, stackTrace: s);
      // Mungkin re-throw atau tangani error di UI
    }
  }

  Future<bool> createOrder(Map<String, dynamic> orderData) async {
    final orderService = ref.read(orderServiceProvider);
    try {
      final customerDetailsMap = {
        'name': orderData['customerName'],
        'address': orderData['customerAddress'],
        'whatsapp': orderData['customerWhatsapp'],
      };

      final Order newOrder = Order(
        date: orderData['date'] as Timestamp,
        products: (orderData['products'] as List)
            .map((p) => p as Map<String, dynamic>)
            .toList(),
        productIds: (orderData['productIds'] as List).cast<String>(),
        subtotal: orderData['subtotal'],
        total: orderData['total'],
        totalDiscount: orderData['totalDiscount'] ?? 0, // Perbaikan
        paymentMethod: orderData['paymentMethod'],
        status: orderData['status'],
        kasir: orderData['kasir'] ?? 'System',
        customerDetails: customerDetailsMap,
        paymentStatus: orderData['paymentStatus'] ?? 'Paid',
        stockUpdated: false, 
      );

      await orderService.createOrder(newOrder);
      refreshOrders();
      return true;
    } catch (e, s) {
      log('Error saat membuat pesanan: ${e.toString()}',
          name: 'OrderCreationError', error: e, stackTrace: s);
      return false;
    }
  }

  Future<void> updateOrderStatus(String orderId, String newStatus) async {
    final orderService = ref.read(orderServiceProvider);
    await orderService.updateOrderStatus(orderId, newStatus);
    refreshOrders();
     ref.invalidate(orderDetailsProvider(orderId));
  }

  Future<void> updateOrderDetails(
    String orderId,
    List<OrderItem> newProducts,
    double newSubtotal,
    double newTotal, {
    String? validatorName,
  }) async {
    final orderService = ref.read(orderServiceProvider);
    await orderService.updateOrderDetails(
      orderId,
      newProducts,
      newSubtotal,
      newTotal,
      validatorName: validatorName,
    );
    refreshOrders();
    ref.invalidate(orderDetailsProvider(orderId));
  }

  Future<void> setOrderValidator(String orderId, String validatorName) async {
    final orderService = ref.read(orderServiceProvider);
    await orderService.setOrderValidator(orderId, validatorName);
    refreshOrders();
  }
}

final orderActionsProvider =
    NotifierProvider.autoDispose<OrderActionsNotifier, void>(
  OrderActionsNotifier.new,
);

final orderDetailsProvider =
    FutureProvider.family.autoDispose<Order?, String>((ref, orderId) async {
  final orderService = ref.watch(orderServiceProvider);
  // Dapatkan data order
  final order = await orderService.getOrderById(orderId);
  if (order == null) return null;

  // Dapatkan detail produk dari koleksi 'products'
  final productFutures = order.productIds.map((productId) => 
      FirebaseFirestore.instance.collection('products').doc(productId).get()
  ).toList();

  final productSnapshots = await Future.wait(productFutures);

  final Map<String, Map<String, dynamic>> productDetails = {};
  for (var doc in productSnapshots) {
      if (doc.exists) {
          productDetails[doc.id] = doc.data()!;
      }
  }

  // Ganti data produk di dalam order dengan detail yang baru didapatkan
  final updatedProducts = order.products.map((product) {
      final details = productDetails[product['productId']];
      if (details != null) {
          return {
              ...product,
              'name': details['name'] ?? product['name'],
              'imageUrl': details['imageUrl'] ?? product['imageUrl'],
              'sku': details['sku'] ?? product['sku'],
          };
      }
      return product;
  }).toList();

  // PERBAIKAN: Membuat instance Order baru secara manual, bukan menggunakan copyWith
  return Order(
    id: order.id,
    date: order.date,
    createdAt: order.createdAt,
    updatedAt: order.updatedAt,
    validatedAt: order.validatedAt,
    shippedAt: order.shippedAt,
    customer: order.customer,
    customerId: order.customerId,
    customerDetails: order.customerDetails,
    products: updatedProducts, // Ini adalah data yang diperbarui
    productIds: order.productIds,
    subtotal: order.subtotal,
    total: order.total,
    totalDiscount: order.totalDiscount, // Perbaikan
    shippingFee: order.shippingFee,
    paymentMethod: order.paymentMethod,
    paymentStatus: order.paymentStatus,
    status: order.status,
    kasir: order.kasir,
    stockUpdated: order.stockUpdated,
    shippingMethod: order.shippingMethod,
    cogs: order.cogs,
    grossProfit: order.grossProfit,
  );
});
