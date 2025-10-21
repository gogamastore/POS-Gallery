import 'dart:async';
import 'dart:developer';

import 'package:cloud_firestore/cloud_firestore.dart' hide Order;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/order.dart';
import '../models/order_item.dart';
import '../services/order_service.dart';

final orderServiceProvider = Provider<OrderService>((ref) => OrderService());

// Helper map to translate UI filter labels to Firestore status values.
const Map<String, List<String>> _statusQueryMap = {
  'pending': ['pending', 'Pending'],
  'processing': ['processing', 'Processing'],
  'shipped': ['shipped', 'Shipped'],
  'delivered': ['delivered', 'Delivered'],
  'cancelled': ['cancelled', 'Cancelled'],
};

class OrderNotifier extends StateNotifier<AsyncValue<List<Order>>> {
  final OrderService _orderService;
  final Ref _ref;

  // Caches all fetched orders to avoid re-fetching. Key is order ID.
  final Map<String, Order> _masterOrderCache = {};
  // Tracks which status filters have already been fetched.
  final Set<String> _fetchedStatuses = {};

  StreamSubscription? _filterSubscription;

  OrderNotifier(this._orderService, this._ref) : super(const AsyncValue.loading()) {
    _filterSubscription?.cancel();

    // Initial fetch for the default status.
    _fetchOrdersForStatus(_ref.read(orderFilterProvider));

    // Listen to changes in the active filter and fetch data accordingly.
    _ref.listen<String>(orderFilterProvider, (_, nextStatus) {
      _fetchOrdersForStatus(nextStatus);
    });
  }

  @override
  void dispose() {
    _filterSubscription?.cancel();
    super.dispose();
  }

  Future<void> _fetchOrdersForStatus(String status) async {
    if (_fetchedStatuses.contains(status)) {
      // Data already in cache, just make sure state is updated.
      // This ensures the UI rebuilds with the full list if it was in a loading state.
      if (state is! AsyncData) {
         state = AsyncValue.data(_masterOrderCache.values.toList());
      }
      return;
    }

    state = const AsyncValue.loading();

    try {
      final queryStatuses = _statusQueryMap[status] ?? [status];
      final newOrders = await _orderService.getOrdersByStatus(queryStatuses);

      for (final order in newOrders) {
        _masterOrderCache[order.id] = order;
      }
      
      _fetchedStatuses.add(status);

      if (mounted) {
        state = AsyncValue.data(_masterOrderCache.values.toList());
      }
    } catch (e, s) {
      if (mounted) {
        state = AsyncValue.error(e, s);
      }
    }
  }

  Future<void> refresh() async {
    _masterOrderCache.clear();
    _fetchedStatuses.clear();
    
    state = const AsyncValue.loading();
    await _fetchOrdersForStatus(_ref.read(orderFilterProvider));
  }

  Future<bool> createOrder(Order order) async {
    try {
      await _orderService.createOrder(order);
      await refresh();
      return true;
    } catch (e, s) {
      log('Gagal membuat pesanan', error: e, stackTrace: s);
      return false;
    }
  }

  Future<bool> createCustomerOrder(Map<String, dynamic> orderData) async {
    try {
      await _orderService.createOrderFromMap(orderData);
      await refresh();
      return true;
    } on FirebaseException catch (e, s) {
      log('Error Firebase saat membuat pesanan:', name: 'FirebaseError', error: 'Code: ${e.code}\nMessage: ${e.message}', stackTrace: s);
      return false;
    } catch (e, s) {
      log('Error umum saat membuat pesanan pelanggan. TIPE ERROR: ${e.runtimeType.toString()}', name: 'GeneralError', error: e, stackTrace: s);
      return false;
    }
  }

  Future<bool> updateOrder(String orderId, List<OrderItem> products,
      double shippingFee, double newSubtotal, double newTotal, {String? validatorName}) async {
    try {
      await _orderService.updateOrderDetails(
          orderId, products, shippingFee, newSubtotal, newTotal, validatorName: validatorName);
      await refresh();
      return true;
    } catch (e, s) {
      log('Gagal memperbarui pesanan', error: e, stackTrace: s);
      return false;
    }
  }
}

final orderProvider = StateNotifierProvider<OrderNotifier, AsyncValue<List<Order>>>((ref) {
  return OrderNotifier(ref.watch(orderServiceProvider), ref);
});

final orderStatusCountsProvider = Provider.autoDispose<Map<String, int>>((ref) {
  final orders = ref.watch(orderProvider).value ?? [];
  final counts = {
    'pending': 0,
    'processing': 0,
    'shipped': 0,
    'delivered': 0,
    'cancelled': 0
  };
  for (var order in orders) {
     final statusKey = order.status.toLowerCase();
    if (counts.containsKey(statusKey)) {
      counts[statusKey] = (counts[statusKey] ?? 0) + 1;
    }
  }
  return counts;
});

final orderFilterProvider = StateProvider<String>((ref) => 'pending');

final orderSearchQueryProvider = StateProvider<String>((ref) => '');

final filteredOrdersProvider = Provider.autoDispose<List<Order>>((ref) {
  final allOrdersAsync = ref.watch(orderProvider);
  
  return allOrdersAsync.when(
    data: (allOrders) {
      final statusFilter = ref.watch(orderFilterProvider);
      final searchQuery = ref.watch(orderSearchQueryProvider).toLowerCase();

      final ordersFilteredByStatus = allOrders
          .where((order) => (_statusQueryMap[statusFilter] ?? [statusFilter]).contains(order.status))
          .toList();

      if (searchQuery.isEmpty) {
        return ordersFilteredByStatus;
      }

      return ordersFilteredByStatus.where((order) {
        final customerNameMatch = order.customer.toLowerCase().contains(searchQuery);
        final orderIdMatch = order.id.toLowerCase().contains(searchQuery);
        final skuMatch = order.products.any((product) {
          final sku = product.sku;
          return sku != null && sku.toLowerCase().contains(searchQuery);
        });

        return customerNameMatch || orderIdMatch || skuMatch;
      }).toList();
    },
    loading: () => [],
    error: (e, s) => [],
  );
});

final ordersByStatusProvider =
    Provider.family.autoDispose<AsyncValue<List<Order>>, String>((ref, status) {
  final allOrdersAsync = ref.watch(orderProvider);
  return allOrdersAsync.when(
    data: (orders) =>
        AsyncValue.data(orders.where((o) => o.status.toLowerCase() == status.toLowerCase()).toList()),
    loading: () => const AsyncValue.loading(),
    error: (e, s) => AsyncValue.error(e, s),
  );
});

final orderDetailsProvider =
    FutureProvider.family.autoDispose<Order?, String>((ref, orderId) async {
  final order = await ref.watch(orderServiceProvider).getOrderById(orderId);
  
  ref.onDispose(() {
    ref.read(orderProvider.notifier).refresh();
  });
  
  return order;
});
