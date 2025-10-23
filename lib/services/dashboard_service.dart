import 'dart:developer' as developer;
import 'package:cloud_firestore/cloud_firestore.dart' as firestore;
import 'package:intl/intl.dart'; // PERBAIKAN: Import ditambahkan
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
          .where('status', isEqualTo: 'success')
          .where('validatedAt', isGreaterThanOrEqualTo: startOfToday)
          .where('validatedAt', isLessThanOrEqualTo: endOfToday);
      
      final revenueOrdersSnapshot = await revenueOrdersQuery.get();

      double totalRevenueToday = 0;
      for (var doc in revenueOrdersSnapshot.docs) {
        final data = doc.data();
        totalRevenueToday += (data['total'] as num? ?? 0).toDouble();
      }
      
      final salesOrdersQuery = ordersQuery
          .where('status', whereIn: ['success', 'cancelled'])
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
              .collection('users')
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

      firestore.Query baseRecentOrdersQuery = _db.collection('orders');
       if (userRole != 'admin') {
          baseRecentOrdersQuery = baseRecentOrdersQuery.where('customerId', isEqualTo: userId);
      }

      final recentOrdersSnapshot = await baseRecentOrdersQuery.orderBy('date', descending: true).limit(5).get();
      
      // PERBAIKAN: Menghapus .withConverter dan melakukan casting secara eksplisit.
      final List<Order> recentOrders = recentOrdersSnapshot.docs
          .map((doc) => Order.fromFirestore(doc as firestore.DocumentSnapshot<Map<String, dynamic>>))
          .toList();

      return DashboardData(
        // PERBAIKAN: Mengonversi double ke int
        totalRevenue: totalRevenueToday.round(),
        totalSales: totalSalesToday,
        newCustomers: newCustomers,
        totalProducts: totalProducts,
        lowStockProducts: lowStockProducts,
        recentOrders: recentOrders,
      );
    } on firestore.FirebaseException catch (e) {
      if (e.code == 'failed-precondition' && e.message != null) {
        // PERBAIKAN: RegExp diperbaiki.
        final urlMatch = RegExp(
                r'(https://console.firebase.google.com/project/[^/]+/database/[^/]+/indexes[?]create_composite=.*?)\s')
            .firstMatch(e.message!);
        if (urlMatch != null) {
          final url = urlMatch.group(1)!;
          developer.log(
            '\\n========================================\\n'
            'SALIN LINK UNTUK MEMBUAT INDEX FIRESTORE:\\n\\n'
            '$url\\n\\n'
            '========================================\\n',
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
    Map<DateTime, double> dailySales = {};

    for (int i = 0; i < 30; i++) {
        final day = DateTime(now.year, now.month, now.day - i);
        dailySales[day] = 0;
    }
    
    firestore.Query<Map<String, dynamic>> ordersQuery = _db.collection('orders');

    if (userRole != 'admin') {
      ordersQuery = ordersQuery.where('userId', isEqualTo: userId);
    }

    final querySnapshot = await ordersQuery
        .where('status', isEqualTo: 'success')
        .where('validatedAt',
            isGreaterThanOrEqualTo: firestore.Timestamp.fromDate(thirtyDaysAgo))
        .get();

    for (var doc in querySnapshot.docs) {
      final data = doc.data();
      final orderDate = (data['validatedAt'] as firestore.Timestamp).toDate();
      final dayKey = DateTime(orderDate.year, orderDate.month, orderDate.day);
      
      final total = (data['total'] as num? ?? 0).toDouble();

      if (dailySales.containsKey(dayKey)) {
        dailySales[dayKey] = dailySales[dayKey]! + total;
      }
    }

    final sortedEntries = dailySales.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    return sortedEntries
        .map((entry) =>
            SalesData(label: DateFormat('d/M').format(entry.key), 
            // PERBAIKAN: Mengonversi double ke int
            value: entry.value.round()))
        .toList();
  }
}
