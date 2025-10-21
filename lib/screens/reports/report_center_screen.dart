import 'package:flutter/material.dart';
import 'package:ionicons/ionicons.dart';

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
        padding: const EdgeInsets.all(16.0),
        children: [
          _buildReportCard(
            context,
            icon: Ionicons.document_text_outline,
            title: 'Laporan Biaya Operasional',
            subtitle: 'Lacak semua pengeluaran bisnis Anda.',
            color: Colors.orange,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const OperationalCostsScreen()),
              );
            },
          ),
          const SizedBox(height: 16),
          _buildReportCard(
            context,
            icon: Ionicons.analytics_outline,
            title: 'Laporan Laba Rugi',
            subtitle: 'Analisis pendapatan dan keuntungan Anda.',
            color: Colors.green,
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

  Widget _buildReportCard(BuildContext context, {required IconData icon, required String title, required String subtitle, required Color color, required VoidCallback onTap}) {
    final theme = Theme.of(context);
    return Card(
      elevation: 2.0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 16.0),
        leading: CircleAvatar(
          backgroundColor: color.withAlpha(26), // Perbaikan: Menggunakan withAlpha
          child: Icon(icon, color: color, size: 30),
        ),
        title: Text(title, style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
        subtitle: Text(subtitle, style: theme.textTheme.bodyMedium),
        trailing: const Icon(Ionicons.chevron_forward_outline),
        onTap: onTap,
      ),
    );
  }
}
