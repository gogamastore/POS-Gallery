// lib/models/dashboard_data.dart
import 'order.dart';

class DashboardData {
  final int totalRevenue;
  final int totalSales;
  final int newCustomers;
  final int totalProducts;
  final int lowStockProducts;
  final List<Order> recentOrders;

  DashboardData({
    required this.totalRevenue,
    required this.totalSales,
    required this.newCustomers,
    required this.totalProducts,
    required this.lowStockProducts,
    required this.recentOrders,
  });
}