import 'package:flutter/material.dart';
import 'package:ionicons/ionicons.dart';

import '../reports/customer_report_screen.dart';
import '../reports/operational_costs_screen.dart';
import '../reports/product_sales_report_screen.dart';
import '../reports/purchase_report_screen.dart';
import '../reports/sales_report_screen.dart';
import '../reports/stock_flow_report_screen.dart';
import '../reports/profit_loss_screen.dart'; // 1. IMPORT PROFIT LOSS SCREEN

class ReportsScreen extends StatelessWidget {
  const ReportsScreen({super.key});

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
            onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => const SalesReportScreen())),
          ),
          _buildMenuItem(
            context,
            icon: Ionicons.document_text_outline,
            title: 'Laporan Transaksi Pembelian',
            subtitle: 'Lacak semua transaksi pembelian stok.',
            onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => const PurchaseReportScreen())),
          ),
          _buildMenuItem(
            context,
            icon: Ionicons.swap_horizontal_outline,
            title: 'Laporan Arus Stok',
            subtitle: 'Lacak riwayat pergerakan stok produk.',
            onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => const StockFlowReportScreen())),
          ),
          _buildMenuItem(
            context,
            icon: Ionicons.cube_outline,
            title: 'Penjualan Produk',
            subtitle: 'Analisis penjualan per item produk.',
            onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => const ProductSalesReportScreen())),
          ),
          _buildMenuItem(
            context,
            icon: Ionicons.people_outline,
            title: 'Laporan Pelanggan',
            subtitle: 'Lihat riwayat dan total belanja per pelanggan.',
            onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => const CustomerReportScreen())),
          ),
          // --- MENU AI DITAMBAHKAN DI SINI ---
          _buildMenuItem(
            context,
            icon: Ionicons.wallet_outline,
            title: 'Laporan Biaya Operasional',
            subtitle: 'Lacak semua pengeluaran non-produk.',
            onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => const OperationalCostsScreen())),
          ),
          // ------------------------------------
          _buildMenuItem(
            context,
            icon: Ionicons.analytics_outline,
            title: 'Laporan Laba Rugi',
            subtitle: 'Analisis pendapatan, HPP, dan laba bersih.',
            onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => const ProfitLossScreen())),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuItem(BuildContext context,
      {required IconData icon,
      required String title,
      required String subtitle,
      required VoidCallback onTap}) {
    return ListTile(
      leading: Icon(icon, color: Theme.of(context).primaryColor),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
      subtitle: Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}
