// lib/providers/dashboard_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:myapp/providers/auth_provider.dart';
import 'package:myapp/providers/user_provider.dart'; // Import yang benar

import '../models/dashboard_data.dart';
import '../models/sales_data.dart';
import '../services/dashboard_service.dart';

final dashboardServiceProvider =
    Provider<DashboardService>((ref) => DashboardService());

final dashboardDataProvider = FutureProvider<DashboardData>((ref) async {
  final authState = ref.watch(authStateChangesProvider);
  final userData = ref.watch(userDataProvider);

  final user = authState.asData?.value;
  final userModel = userData.asData?.value;

  // Pastikan role tidak null sebelum memanggil service
  if (user != null && userModel != null && userModel.role != null) {
    return ref
        .watch(dashboardServiceProvider)
        .getDashboardData(user.uid, userModel.role!); // Gunakan ! untuk menegaskan tidak null
  } else {
    // Kembalikan data kosong atau handle kasus di mana pengguna/role tidak ada
    return Future.value(DashboardData(
        totalRevenue: 0,
        totalSales: 0,
        newCustomers: 0,
        totalProducts: 0,
        lowStockProducts: 0,
        recentOrders: []));
  }
});

final salesAnalyticsProvider = FutureProvider<List<SalesData>>((ref) async {
  final authState = ref.watch(authStateChangesProvider);
  final userData = ref.watch(userDataProvider);

  final user = authState.asData?.value;
  final userModel = userData.asData?.value;

  // Pastikan role tidak null sebelum memanggil service
  if (user != null && userModel != null && userModel.role != null) {
    return ref
        .watch(dashboardServiceProvider)
        .getSalesAnalytics(user.uid, userModel.role!); // Gunakan ! untuk menegaskan tidak null
  } else {
    return Future.value([]);
  }
});
