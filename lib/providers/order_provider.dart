import 'dart:async';
import 'dart:developer';

import 'package:cloud_firestore/cloud_firestore.dart' hide Order;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/order.dart'; 
import '../models/order_item.dart';
import '../services/order_service.dart';

final orderServiceProvider = Provider<OrderService>((ref) => OrderService());

final allOrdersProvider = FutureProvider.autoDispose<List<Order>>((ref) async {
  return ref.watch(orderServiceProvider).getAllOrders();
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
        paymentMethod: orderData['paymentMethod'],
        status: orderData['status'],
        kasir: orderData['kasir'] ?? 'System',
        customerDetails: customerDetailsMap,
        paymentStatus: orderData['paymentStatus'] ?? 'Paid',
        // PERBAIKAN: Menambahkan parameter 'stockUpdated' yang wajib
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
  return ref.watch(orderServiceProvider).getOrderById(orderId);
});
