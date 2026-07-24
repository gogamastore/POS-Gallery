import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';

import '../../models/expense_item.dart';
import '../../providers/report_provider.dart';
import '../../utils/date_utils.dart';

final dateRangeProvider = StateProvider<DateTimeRange>((ref) {
  final now = DateTime.now();
  final startOfMonth = startOfDay(DateTime(now.year, now.month, 1));
  final endOfMonth = endOfDay(DateTime(now.year, now.month + 1, 0));
  return DateTimeRange(start: startOfMonth, end: endOfMonth);
});

class OperationalCostsScreen extends ConsumerWidget {
  const OperationalCostsScreen({super.key});

  void _selectDateRange(BuildContext context, WidgetRef ref) async {
    final currentRange = ref.read(dateRangeProvider);
    final picked = await showDateRangePicker(
      context: context,
      initialDateRange: currentRange,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null && picked != currentRange) {
      ref.read(dateRangeProvider.notifier).state = DateTimeRange(
        start: startOfDay(picked.start),
        end: endOfDay(picked.end),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedDateRange = ref.watch(dateRangeProvider);
    final expensesAsync = ref.watch(operationalExpensesProvider(selectedDateRange));
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Biaya Operasional'),
      ),
      body: expensesAsync.when(
        data: (expenses) {
          final totalExpense = expenses.fold<double>(
              0, (sum, item) => sum + item.amount);
          final totalTransactions = expenses.length;
          final chartData = _prepareChartData(expenses);

          return ListView(
            padding: const EdgeInsets.all(16.0),
            children: [
              _buildDateFilter(context, ref, theme, selectedDateRange),
              const SizedBox(height: 16),
              _buildSummaryCards(totalExpense, totalTransactions, theme),
              const SizedBox(height: 16),
              _buildChartCard(chartData, theme),
              const SizedBox(height: 16),
              _buildDetailsCard(context, expenses, theme),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(child: Text('Error: $error')),
      ),
    );
  }

  Widget _buildDateFilter(BuildContext context, WidgetRef ref, ThemeData theme, DateTimeRange selectedDateRange) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '${DateFormat('dd MMM yyyy', 'id_ID').format(selectedDateRange.start)} - ${DateFormat('dd MMM yyyy', 'id_ID').format(selectedDateRange.end)}',
              style: theme.textTheme.titleMedium,
            ),
            ElevatedButton(onPressed: () => _selectDateRange(context, ref), child: const Text('Ubah Tanggal')),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCards(
      double totalExpense, int totalTransactions, ThemeData theme) {
    final currencyFormatter = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ');
    return Row(
      children: [
        Expanded(
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Total Pengeluaran', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 36, // Memberi batasan tinggi untuk FittedBox
                    child: FittedBox(
                      fit: BoxFit.contain,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        currencyFormatter.format(totalExpense),
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Jumlah Transaksi', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 36, // Memberi batasan tinggi untuk FittedBox
                    child: FittedBox(
                      fit: BoxFit.contain,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        totalTransactions.toString(),
                         style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Map<DateTime, double> _prepareChartData(List<ExpenseItem> expenses) {
    final Map<DateTime, double> data = {};
    for (var expense in expenses) {
      final date = DateTime(expense.date.year, expense.date.month, expense.date.day);
      data.update(date, (value) => value + expense.amount, ifAbsent: () => expense.amount);
    }
    return data;
  }

  Widget _buildChartCard(Map<DateTime, double> chartData, ThemeData theme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Tren Beban Operasional'),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  barGroups: chartData.entries.map((entry) {
                    return BarChartGroupData(
                      x: entry.key.day,
                      barRods: [
                        BarChartRodData(
                           toY: entry.value,
                           width: 15,
                           color: theme.primaryColor
                        ),
                      ],
                    );
                  }).toList(),
                  titlesData: FlTitlesData(
                      leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, getTitlesWidget: (value, meta) => Text(value.toInt().toString())))
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }


  Widget _buildDetailsCard(BuildContext context, List<ExpenseItem> expenses, ThemeData theme) {
    final currencyFormatter = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ');
    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text('Rincian Beban Operasional'),
          ),
          DataTable(
            // 1. Menghapus kolom 'Detail'
            columns: const [
              DataColumn(label: Text('Tanggal')),
              DataColumn(label: Text('Kategori')),
              DataColumn(label: Text('Jumlah')),
            ],
            rows: expenses.map((expense) {
              return DataRow(
                // 2. Menambahkan event onSelectChanged
                onSelectChanged: (isSelected) {
                  if (isSelected != null && isSelected) {
                    _showDetailDialog(context, expense, theme);
                  }
                },
                cells: [
                  DataCell(Text(DateFormat('dd/MM/yy').format(expense.date))),
                  DataCell(Text(expense.category)),
                  DataCell(Text(currencyFormatter.format(expense.amount))),
                  // 3. Menghapus DataCell untuk tombol
                ],
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  void _showDetailDialog(BuildContext context, ExpenseItem expense, ThemeData theme) {
     final currencyFormatter = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ');
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Detail Biaya Operasional'),
        content: SingleChildScrollView(
          child: ListBody(
            children: <Widget>[
              Text('ID Transaksi: ${expense.id}'),
              const SizedBox(height: 8),
              Text('Tanggal: ${DateFormat('dd MMMM yyyy', 'id_ID').format(expense.date)}'),
              const SizedBox(height: 8),
              Text('Kategori: ${expense.category}'),
              const SizedBox(height: 8),
              Text('Deskripsi: ${expense.description}'),
               const SizedBox(height: 8),
              Text('Jumlah: ${currencyFormatter.format(expense.amount)}', style: theme.textTheme.titleLarge),
            ],
          ),
        ),
        actions: <Widget>[
          TextButton(
            child: const Text('Tutup'),
            onPressed: () {
              Navigator.of(context).pop();
            },
          ),
        ],
      ),
    );
  }
}
