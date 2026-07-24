import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../models/user_model.dart';
import '../../providers/user_provider.dart';
import '../../providers/dashboard_provider.dart';
import '../../providers/auth_provider.dart';
import '../../models/dashboard_data.dart';
import '../../models/sales_data.dart';
import '../../models/order.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  DashboardScreenState createState() => DashboardScreenState();
}

class DashboardScreenState extends ConsumerState<DashboardScreen> {
  // --- PERBAIKAN: Menggunakan invalidate untuk refresh ---
  Future<void> _refreshData() async {
    ref.invalidate(dashboardDataProvider);
    ref.invalidate(salesAnalyticsProvider);
    ref.invalidate(userDataProvider);
    // Tunggu semua provider selesai me-refresh
    await Future.wait([
      ref.read(dashboardDataProvider.future),
      ref.read(salesAnalyticsProvider.future),
      ref.read(userDataProvider.future),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final dashboardDataAsync = ref.watch(dashboardDataProvider);
    final salesDataAsync = ref.watch(salesAnalyticsProvider);
    final userDataAsync = ref.watch(userDataProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text(
          'Gallery Makassar',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Color.fromARGB(255, 5, 83, 239),
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 1,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Color(0xFF5DADE2)),
            tooltip: 'Keluar',
            onPressed: () => ref.read(authServiceProvider).signOut(),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refreshData,
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                userDataAsync.when(
                  data: (user) => _buildHeader(user),
                  loading: () => _buildHeader(null),
                  error: (err, stack) =>
                      Center(child: Text('Gagal memuat data user: $err')),
                ),
                const SizedBox(height: 24),
                dashboardDataAsync.when(
                  data: (data) => _buildStatsContainer(data),
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (err, stack) => Center(child: Text('Error: $err')),
                ),
                const SizedBox(height: 24),
                salesDataAsync.when(
                  data: (salesData) => _buildSalesChart(salesData),
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (err, stack) => Center(child: Text('Error: $err')),
                ),
                const SizedBox(height: 24),
                dashboardDataAsync.when(
                  data: (data) => _buildRecentOrders(data.recentOrders),
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (err, stack) => Center(child: Text('Error: $err')),
                ),
                const SizedBox(height: 24),
                _buildSuccessMessage(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(UserModel? user) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        CircleAvatar(
          radius: 28,
          backgroundColor: const Color(0xFFE0E6ED),
          backgroundImage:
              (user?.photoURL != null && user!.photoURL!.isNotEmpty)
                  ? NetworkImage(user.photoURL!)
                  : null,
          child: (user?.photoURL == null || user!.photoURL!.isEmpty)
              ? const Icon(Icons.person, size: 30, color: Color(0xFFBDC3C7))
              : null,
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                user?.name ?? 'Memuat pengguna...',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2C3E50),
                ),
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                'Jabatan : ${user?.position ?? '...'}',
                style: const TextStyle(
                  fontSize: 14,
                  color: Color(0xFF7F8C8D),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatsContainer(DashboardData data) {
    return Column(
      children: [
        Row(
          children: [
            _buildStatCard(
              icon: Icons.account_balance_wallet_outlined,
              iconColor: const Color(0xFF5DADE2),
              value: NumberFormat.currency(
                locale: 'id_ID',
                symbol: 'Rp ',
                decimalDigits: 0,
              ).format(data.totalRevenue),
              label: 'Total Revenue',
              subtext: 'Total dari pesanan yang selesai',
            ),
            const SizedBox(width: 16),
            _buildStatCard(
              icon: Icons.shopping_bag_outlined,
              iconColor: const Color(0xFF27AE60),
              value: '+${data.totalSales}',
              label: 'Sales',
              subtext: 'Jumlah pesanan yang selesai',
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            _buildStatCard(
              icon: Icons.people_outline,
              iconColor: const Color(0xFFE74C3C),
              value: '+${data.newCustomers}',
              label: 'New Customers',
              subtext: 'Total reseller terdaftar',
            ),
            const SizedBox(width: 16),
            _buildStatCard(
              icon: Icons.inventory_2_outlined,
              iconColor: const Color(0xFFF39C12),
              value: '${data.totalProducts}',
              label: 'Products in Stock',
              subtext: '${data.lowStockProducts} produk stok menipis',
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required Color iconColor,
    required String value,
    required String label,
    required String subtext,
  }) {
    return Expanded(
      child: Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 1,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: iconColor, size: 24),
              const SizedBox(height: 12),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2C3E50),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF2C3E50),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtext,
                style: const TextStyle(fontSize: 11, color: Color(0xFF7F8C8D)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSalesChart(List<SalesData> salesData) {
    final spots = salesData.asMap().entries.map((entry) {
      final index = entry.key;
      final data = entry.value;
      return FlSpot(index.toDouble(), data.value.toDouble());
    }).toList();

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(12),
            spreadRadius: 1,
            blurRadius: 2,
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Sales Overview',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF2C3E50),
            ),
          ),
          const Text(
            'Data Penjualan 1 Bulan Terakhir.',
            style: TextStyle(fontSize: 14, color: Color(0xFF7F8C8D)),
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 150,
            child: LineChart(
              LineChartData(
                gridData: const FlGridData(show: false),
                titlesData: const FlTitlesData(show: false),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    color: const Color(0xFF5DADE2),
                    barWidth: 4,
                    isStrokeCapRound: true,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: true,
                      color: const Color(0x4D5DADE2),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentOrders(List<Order> orders) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(12),
            spreadRadius: 1,
            blurRadius: 2,
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Recent Orders',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF2C3E50),
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'A list of the most recent orders.',
            style: TextStyle(fontSize: 14, color: Color(0xFF7F8C8D)),
          ),
          const SizedBox(height: 20),
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                flex: 3,
                child: Text(
                  'Customer',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF7F8C8D),
                  ),
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  'Amount',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF7F8C8D),
                  ),
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  'Status',
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF7F8C8D),
                  ),
                ),
              ),
            ],
          ),
          const Divider(color: Color(0xFFE0E6ED)),
          ...orders.map((order) => _buildOrderRow(order)),
        ],
      ),
    );
  }

  Widget _buildOrderRow(Order order) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  // --- PERBAIKAN: Mengakses nama pelanggan dari Map ---
                  order.customerDetails?['name'] ?? 'N/A',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF2C3E50),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  DateFormat('dd/MM/yy HH:mm').format(order.date.toDate()),
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF7F8C8D),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              // --- PERBAIKAN: Memformat total harga ---
              NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0).format(order.total),
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Color(0xFF2C3E50),
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Align(
              alignment: Alignment.centerRight,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _getStatusColor(order.status).withAlpha(51),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  _getStatusText(order.status),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: _getStatusColor(order.status),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'success':
        return const Color(0xFF27AE60);
      case 'processing':
        return const Color(0xFFF39C12);
      case 'cancelled':
        return const Color(0xFF95A5A6);
      default:
        return const Color(0xFF7F8C8D);
    }
  }

  String _getStatusText(String status) {
    switch (status.toLowerCase()) {
      case 'success':
        return 'Selesai';
      case 'processing':
        return 'Diproses';
      case 'cancelled':
        return 'Dibatalkan';
      default:
        return status;
    }
  }

  Widget _buildSuccessMessage() {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 24),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(12),
            spreadRadius: 1,
            blurRadius: 2,
          ),
        ],
      ),
      child: const Row(
        children: [
          Icon(Icons.check_circle, color: Color(0xFF27AE60)),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Data Terbaru!',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF27AE60),
                  ),
                ),
                Text(
                  'Disinkronkan dari Firestore',
                  style: TextStyle(fontSize: 14, color: Color(0xFF7F8C8D)),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
