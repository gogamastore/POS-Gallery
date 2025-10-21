import 'dart:developer' as developer;
import 'package:cloud_firestore/cloud_firestore.dart' as firestore;
import 'package:myapp/models/order.dart';

import '../models/dashboard_data.dart';
import '../models/sales_data.dart';

class DashboardService {
  final _db = firestore.FirebaseFirestore.instance;

  Future<DashboardData> getDashboardData(String userId, String userRole) async {
    try {
      final now = DateTime.now();
      final startOfToday =
          firestore.Timestamp.fromDate(DateTime(now.year, now.month, now.day, 0, 0, 0));
      final endOfToday = firestore.Timestamp.fromDate(
          DateTime(now.year, now.month, now.day, 23, 59, 59));

      // Kueri dasar untuk pesanan
      firestore.Query<Map<String, dynamic>> ordersQuery = _db.collection('orders');

      // Jika bukan admin, filter berdasarkan customerId
      if (userRole != 'admin') {
        ordersQuery = ordersQuery.where('customerId', isEqualTo: userId);
      }
      
      final revenueOrdersQuery = ordersQuery
          .where('status', whereIn: ['processing', 'shipped', 'delivered'])
          .where('validatedAt', isGreaterThanOrEqualTo: startOfToday)
          .where('validatedAt', isLessThanOrEqualTo: endOfToday);
      
      final revenueOrdersSnapshot = await revenueOrdersQuery.get();

      double totalRevenueToday = 0;
      for (var doc in revenueOrdersSnapshot.docs) {
        final data = doc.data();
        double orderTotal = 0;
        for (var product in (data['products'] as List<dynamic>)) {
          orderTotal += (product['price'] as num).toDouble() *
              (product['quantity'] as num).toInt();
        }
        totalRevenueToday += orderTotal;
      }
      
      final salesOrdersQuery = ordersQuery
          .where('status', whereIn: ['pending', 'Pending', 'processing', 'Processing'])
          .where('date', isGreaterThanOrEqualTo: startOfToday)
          .where('date', isLessThanOrEqualTo: endOfToday);
      
      final salesOrdersSnapshot = await salesOrdersQuery.get();
      final int totalSalesToday = salesOrdersSnapshot.docs.length;

      int newCustomers = 0;
      int totalProducts = 0;
      int lowStockProducts = 0;
      
      if(userRole == 'admin'){
         final oneMonthAgo = now.subtract(const Duration(days: 30));
          final newCustomersQuery = _db
              .collection('user')
              .where('role', isEqualTo: 'reseller')
              .where('createdAt', isGreaterThanOrEqualTo: oneMonthAgo);
          final newCustomersSnapshot = await newCustomersQuery.get();
          newCustomers = newCustomersSnapshot.docs.length;

          final productsSnapshot = await _db.collection('products').get();
          totalProducts = productsSnapshot.docs.length;

         for (var doc in productsSnapshot.docs) {
            final data = doc.data();
            if ((data['stock'] as num? ?? 0) <= 5) {
              lowStockProducts++;
            }
          }
      }

      final recentOrdersSnapshot =
          await ordersQuery.orderBy('date', descending: true).limit(5).get();
      
      final List<Order> recentOrders = recentOrdersSnapshot.docs
          .map((doc) => Order.fromFirestore(doc as firestore.DocumentSnapshot))
          .toList();

      return DashboardData(
        totalRevenue: totalRevenueToday.round(),
        totalSales: totalSalesToday,
        newCustomers: newCustomers,
        totalProducts: totalProducts,
        lowStockProducts: lowStockProducts,
        recentOrders: recentOrders,
      );
    } on firestore.FirebaseException catch (e) {
      if (e.code == 'failed-precondition' && e.message != null) {
        final urlMatch = RegExp(
                r'(https://console.firebase.google.com/project/[^/]+/database/[^/]+/indexes[?]create_composite=.*?)')
            .firstMatch(e.message!);
        if (urlMatch != null) {
          final url = urlMatch.group(1)!;
          developer.log(
            '\n========================================\n'
            'SALIN LINK UNTUK MEMBUAT INDEX FIRESTORE:\n\n'
            '$url\n\n'
            '========================================\n',
            name: 'Firestore Index Trap (Dashboard)',
            level: 1200,
          );
        }
      }
      developer.log('Firebase error in getDashboardData: ${e.toString()}',
          name: 'DashboardService', level: 1000);
      rethrow;
    } catch (e, stackTrace) {
      developer.log('Generic error in getDashboardData: ${e.toString()}',
          name: 'DashboardService',
          level: 1000,
          error: e,
          stackTrace: stackTrace);
      rethrow;
    }
  }

  Future<List<SalesData>> getSalesAnalytics(String userId, String userRole) async {
    final now = DateTime.now();
    final thirtyDaysAgo = now.subtract(const Duration(days: 30));
    Map<int, int> dailySales = {};

    for (int i = 0; i < 30; i++) {
      final day = thirtyDaysAgo.add(Duration(days: i));
      dailySales[day.day] = 0;
    }
    
    // Kueri dasar untuk pesanan
    firestore.Query<Map<String, dynamic>> ordersQuery = _db.collection('orders');

    // Jika bukan admin, filter berdasarkan customerId
    if (userRole != 'admin') {
      ordersQuery = ordersQuery.where('customerId', isEqualTo: userId);
    }

    final querySnapshot = await ordersQuery
        .where('status', whereIn: ['delivered', 'shipped', 'processing'])
        .where('date',
            isGreaterThanOrEqualTo: firestore.Timestamp.fromDate(thirtyDaysAgo))
        .get();

    for (var doc in querySnapshot.docs) {
      final data = doc.data();
      final orderDate = (data['date'] as firestore.Timestamp).toDate();
      final dayKey = orderDate.day;

      final total = data['total'];
      int orderTotal = 0;
      if (total is num) {
        orderTotal = total.toInt();
      } else if (total is String) {
        orderTotal = int.tryParse(total.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
      }

      if (dailySales.containsKey(dayKey)) {
        dailySales[dayKey] = dailySales[dayKey]! + orderTotal;
      }
    }

    return dailySales.entries
        .map((entry) =>
            SalesData(label: entry.key.toString(), value: entry.value))
        .toList();
  }
}
