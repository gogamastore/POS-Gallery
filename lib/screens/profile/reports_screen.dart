import 'package:flutter/material.dart';
import 'package:ionicons/ionicons.dart';

import '../reports/customer_report_screen.dart';
import '../reports/operational_costs_screen.dart';
import '../reports/payable_report_screen.dart';
import '../reports/product_sales_report_screen.dart';
import '../reports/purchase_report_screen.dart';
import '../reports/receivable_report_screen.dart';
import '../reports/sales_report_screen.dart';
import '../reports/stock_flow_report_screen.dart';
import '../reports/profit_loss_screen.dart'; // 1. IMPORT PROFIT LOSS SCREEN

class ReportCardData {
  final IconData icon;
  final String title;
  final String description;
  final VoidCallback onView;

  ReportCardData({
    required this.icon,
    required this.title,
    required this.description,
    required this.onView,
  });
}

class ReportsScreen extends StatelessWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final List<ReportCardData> reports = [
      ReportCardData(
        icon: Ionicons.document_text_outline,
        title: 'Laporan Transaksi Pembelian',
        description: 'Lacak semua transaksi pembelian stok.',
        onView: () => Navigator.of(context).push(MaterialPageRoute(
          builder: (context) => const PurchaseReportScreen(),
        )),
      ),
      ReportCardData(
        icon: Ionicons.swap_horizontal_outline,
        title: 'Laporan Arus Stok',
        description: 'Lacak riwayat pergerakan stok produk.',
        onView: () => Navigator.of(context).push(MaterialPageRoute(
          builder: (context) => const StockFlowReportScreen(),
        )),
      ),
      ReportCardData(
        icon: Ionicons.cash_outline,
        title: 'Laporan Penjualan',
        description: 'Lihat semua transaksi penjualan.',
        onView: () => Navigator.of(context).push(MaterialPageRoute(
          builder: (context) => const SalesReportScreen(),
        )),
      ),
      ReportCardData(
        icon: Ionicons.cube_outline,
        title: 'Penjualan Produk',
        description: 'Analisis penjualan per item produk.',
        onView: () => Navigator.of(context).push(MaterialPageRoute(
          builder: (context) => const ProductSalesReportScreen(),
        )),
      ),
      ReportCardData(
        icon: Ionicons.document_attach_outline,
        title: 'Laporan Piutang Usaha',
        description: 'Lacak pesanan yang belum dibayar.',
        onView: () => Navigator.of(context).push(MaterialPageRoute(
          builder: (context) => const ReceivableReportScreen(),
        )),
      ),
      ReportCardData(
        icon: Ionicons.receipt_outline,
        title: 'Laporan Utang Dagang',
        description: 'Lacak pembelian kredit yang belum lunas.',
        onView: () => Navigator.of(context).push(MaterialPageRoute(
          builder: (context) => const PayableReportScreen(),
        )),
      ),
      ReportCardData(
        icon: Ionicons.people_outline,
        title: 'Laporan Pelanggan',
        description: 'Analisis data dan perilaku pelanggan.',
        onView: () => Navigator.of(context).push(MaterialPageRoute(
          builder: (context) => const CustomerReportScreen(),
        )),
      ),
      ReportCardData(
        icon: Ionicons.wallet_outline,
        title: 'Biaya Operasional',
        description: 'Lacak semua biaya operasional bisnis.',
        onView: () => Navigator.of(context).push(MaterialPageRoute(
          builder: (context) => const OperationalCostsScreen(),
        )),
      ),
      // 2. TAMBAHKAN MENU LAPORAN LABA RUGI DI SINI
      ReportCardData(
        icon: Ionicons.analytics_outline,
        title: 'Laporan Laba Rugi',
        description: 'Analisis pendapatan, biaya, dan laba.',
        onView: () => Navigator.of(context).push(MaterialPageRoute(
          builder: (context) => const ProfitLossScreen(),
        )),
      ),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pusat Laporan'),
        backgroundColor: Theme.of(context).cardColor,
        foregroundColor: Theme.of(context).textTheme.titleLarge?.color,
        elevation: 1,
      ),
      backgroundColor: Theme.of(context).scaffoldBackgroundColor.withAlpha(245),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Wawasan Bisnis Anda',
              style: Theme.of(context)
                  .textTheme
                  .headlineSmall
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Pilih laporan yang ingin Anda lihat untuk mendapatkan wawasan mendalam tentang bisnis Anda.',
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: Colors.grey[600]),
            ),
            const SizedBox(height: 24),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 0.85,
              ),
              itemCount: reports.length,
              itemBuilder: (context, index) {
                return ReportCard(data: reports[index]);
              },
            ),
          ],
        ),
      ),
    );
  }
}

class ReportCard extends StatelessWidget {
  final ReportCardData data;

  const ReportCard({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Text(
                    data.title,
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold),
                    maxLines: 2,
                  ),
                ),
                Icon(data.icon, color: Colors.grey[600], size: 28),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              data.description,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: Colors.grey[600]),
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: data.onView,
                child: const Text('Lihat Laporan'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
