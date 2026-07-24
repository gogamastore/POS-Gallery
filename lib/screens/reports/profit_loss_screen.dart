import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:ionicons/ionicons.dart';

import '../../providers/profit_loss_provider.dart';
import '../../models/profit_loss_data.dart';

class ProfitLossScreen extends ConsumerWidget {
  const ProfitLossScreen({super.key});

  Future<void> _selectDate(BuildContext context, WidgetRef ref, bool isStartDate) async {
    final notifier = ref.read(profitLossProvider.notifier);
    final state = ref.read(profitLossProvider);
    final initialDate = isStartDate ? state.startDate : state.endDate;

    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );

    if (picked != null && picked != initialDate) {
      if (isStartDate) {
        notifier.setStartDate(picked);
      } else {
        notifier.setEndDate(picked);
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(profitLossProvider);
    final notifier = ref.read(profitLossProvider.notifier);
    // final theme = Theme.of(context); // DIHAPUS KARENA TIDAK DIGUNAKAN

    return Scaffold(
      appBar: AppBar(
        title: const Text('Laporan Laba Rugi'),
      ),
      body: Column(
        children: [
          _buildDateFilter(context, ref, state, notifier),
          Expanded(
            child: state.data.when(
              data: (data) => _buildReportView(context, data, state.startDate, state.endDate),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stack) => Center(
                child: Text('Gagal memuat laporan: $error'),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDateFilter(BuildContext context, WidgetRef ref, ProfitLossState state, ProfitLossNotifier notifier) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _datePicker(context, ref, 'Mulai', state.startDate, true),
              _datePicker(context, ref, 'Selesai', state.endDate, false),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => notifier.generateReport(),
              icon: const Icon(Ionicons.calculator_outline),
              label: const Text('Buat Laporan'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _datePicker(BuildContext context, WidgetRef ref, String label, DateTime date, bool isStartDate) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        InkWell(
          onTap: () => _selectDate(context, ref, isStartDate),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(Ionicons.calendar_outline, size: 20),
                const SizedBox(width: 8),
                Text(DateFormat('dd MMM yyyy').format(date)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildReportView(BuildContext context, ProfitLossData data, DateTime startDate, DateTime endDate) {
    if (data.totalRevenue == 0 && data.totalCOGS == 0 && data.totalOperationalExpenses == 0) {
      return const Center(
        child: Text('Tidak ada data untuk periode yang dipilih. Silakan buat laporan.'),
      );
    }

    final currencyFormatter = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 2);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
           Text(
            'Menampilkan Laporan Periode',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          Text(
            '${DateFormat('dd MMM yyyy').format(startDate)} - ${DateFormat('dd MMM yyyy').format(endDate)}',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 24),
          _buildSummaryCard(context, 'Total Pendapatan', currencyFormatter.format(data.totalRevenue), Ionicons.trending_up_outline, Colors.green),
          const SizedBox(height: 16),
          _buildSummaryCard(context, 'Total HPP', currencyFormatter.format(data.totalCOGS), Ionicons.cart_outline, Colors.orange),
          const SizedBox(height: 16),
          _buildSummaryCard(context, 'Laba Kotor', currencyFormatter.format(data.grossProfit), Ionicons.cash_outline, Colors.blue, isHighlighted: true),
          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 16),
          _buildSummaryCard(context, 'Total Biaya Operasional', currencyFormatter.format(data.totalOperationalExpenses), Ionicons.receipt_outline, Colors.red),
          const SizedBox(height: 16),
          _buildSummaryCard(context, 'Laba Bersih', currencyFormatter.format(data.netProfit), Ionicons.trophy_outline, Colors.purple, isHighlighted: true),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(BuildContext context, String title, String value, IconData icon, Color color, {bool isHighlighted = false}) {
    return Card(
      elevation: isHighlighted ? 4.0 : 2.0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: isHighlighted ? color.withAlpha(30) : Theme.of(context).cardColor,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Icon(icon, size: 32, color: color),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.grey[700])),
                  const SizedBox(height: 4),
                  Text(value, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold, color: color)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
