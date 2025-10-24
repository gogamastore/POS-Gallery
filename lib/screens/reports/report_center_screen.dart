import 'package:flutter/material.dart';
import 'package:ionicons/ionicons.dart';
import 'sales_report_screen.dart'; // Import Laporan Penjualan
import 'customer_report_screen.dart'; // Import Laporan Pelanggan
import 'operational_costs_screen.dart';
import 'profit_loss_screen.dart';

class ReportCenterScreen extends StatelessWidget {
  const ReportCenterScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pusat Laporan'),
      ),
      body: ListView(
        children: [
          _buildMenuItem(
            context,
            icon: Ionicons.cart_outline,
            title: 'Laporan Penjualan',
            subtitle: 'Analisis detail transaksi dan performa produk.',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SalesReportScreen()),
              );
            },
          ),
          _buildMenuItem(
            context,
            icon: Ionicons.people_outline,
            title: 'Laporan Pelanggan',
            subtitle: 'Lihat riwayat dan total belanja per pelanggan.',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const CustomerReportScreen()),
              );
            },
          ),
          const Divider(),
          _buildMenuItem(
            context,
            icon: Ionicons.wallet_outline,
            title: 'Laporan Biaya Operasional',
            subtitle: 'Lacak semua pengeluaran non-produk.',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const OperationalCostsScreen()),
              );
            },
          ),
          _buildMenuItem(
            context,
            icon: Ionicons.analytics_outline,
            title: 'Laporan Laba Rugi',
            subtitle: 'Analisis pendapatan, HPP, dan laba bersih.',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ProfitLossScreen()),
              );
            },
          ),
        ],
      ),
    );
  }

  // Mengadopsi gaya dari SettingsScreen
  Widget _buildMenuItem(BuildContext context, {required IconData icon, required String title, required String subtitle, required VoidCallback onTap}) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0), // Menambahkan padding vertikal
      leading: Icon(icon, color: Theme.of(context).primaryColor, size: 28), // Ikon sedikit lebih besar
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
      subtitle: Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}
