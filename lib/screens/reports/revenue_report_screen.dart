import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:ionicons/ionicons.dart';

import '../../providers/revenue_report_provider.dart';
import '../../utils/formatter.dart' as formatter;

/// Laporan Pendapatan — rincian pendapatan penjualan per hari (POS +
/// Marketplace). Ketuk satu hari untuk melihat Total Pendapatan, Total
/// Transaksi, dan rincian per metode bayar (Cash / Transfer Bank / Midtrans).
class RevenueReportScreen extends ConsumerStatefulWidget {
  const RevenueReportScreen({super.key});

  @override
  ConsumerState<RevenueReportScreen> createState() =>
      _RevenueReportScreenState();
}

class _RevenueReportScreenState extends ConsumerState<RevenueReportScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref
          .read(revenueReportProvider.notifier)
          .setFilter(RevenueFilterType.thisMonth);
    });
  }

  Future<void> _selectDateRange(RevenueReportNotifier notifier) async {
    final state = ref.read(revenueReportProvider);
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      initialDateRange: state.selectedDateRange,
    );
    if (picked != null && picked != state.selectedDateRange) {
      notifier.setDateRange(picked);
      notifier.generateReport();
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(revenueReportProvider);
    final notifier = ref.read(revenueReportProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Laporan Pendapatan'),
        leading: IconButton(
          icon: const Icon(Ionicons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildFilterCard(notifier, state),
            const SizedBox(height: 16),
            if (state.isLoading)
              const Center(
                  child: Padding(
                padding: EdgeInsets.symmetric(vertical: 48.0),
                child: CircularProgressIndicator(),
              ))
            else if (state.errorMessage != null)
              Center(child: Text('Gagal memuat data: ${state.errorMessage}'))
            else if (state.dailyData != null) ...[
              _buildSummaryCard(state),
              const SizedBox(height: 16),
              _buildDailyList(state),
            ] else
              const Center(child: Text('Tidak ada data untuk ditampilkan.')),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterCard(
      RevenueReportNotifier notifier, RevenueReportState state) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Filter Periode',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildFilterChip(
                      notifier, state, RevenueFilterType.today, 'Hari Ini'),
                  _buildFilterChip(
                      notifier, state, RevenueFilterType.yesterday, 'Kemarin'),
                  _buildFilterChip(notifier, state,
                      RevenueFilterType.last7days, '7 Hari Terakhir'),
                  _buildFilterChip(
                      notifier, state, RevenueFilterType.thisMonth, 'Bulan Ini'),
                ],
              ),
            ),
            const SizedBox(height: 12),
            InkWell(
              onTap: () => _selectDateRange(notifier),
              child: InputDecorator(
                decoration: InputDecoration(
                  prefixIcon: const Icon(Ionicons.calendar_outline),
                  border: const OutlineInputBorder(),
                  filled: state.activeFilter == RevenueFilterType.custom,
                  fillColor: Theme.of(context)
                      .primaryColor
                      .withAlpha((255 * 0.1).round()),
                ),
                child: Text(
                  state.selectedDateRange == null
                      ? 'Pilih Tanggal'
                      : '${DateFormat('dd MMM yyyy').format(state.selectedDateRange!.start)} - ${DateFormat('dd MMM yyyy').format(state.selectedDateRange!.end)}',
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Filter kanal penjualan (sama seperti Laporan Penjualan).
            Text('Sumber', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildSourceChip(
                      notifier, state, RevenueSourceFilter.all, 'Semua'),
                  _buildSourceChip(
                      notifier, state, RevenueSourceFilter.pos, 'POS'),
                  _buildSourceChip(notifier, state,
                      RevenueSourceFilter.marketplace, 'Marketplace'),
                ],
              ),
            ),
            if (state.cashiers.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text('Kasir', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 8),
              DropdownButtonFormField<String?>(
                key: ValueKey('cashier-${state.cashierFilter ?? 'all'}'),
                initialValue: state.cashierFilter,
                isExpanded: true,
                decoration: const InputDecoration(
                  prefixIcon: Icon(Ionicons.person_outline),
                  border: OutlineInputBorder(),
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                ),
                items: [
                  const DropdownMenuItem<String?>(
                      value: null, child: Text('Semua Kasir')),
                  ...state.cashiers.map((c) => DropdownMenuItem<String?>(
                        value: c.id,
                        child: Text(c.name, overflow: TextOverflow.ellipsis),
                      )),
                ],
                onChanged: (v) => notifier.setCashierFilter(v),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSourceChip(RevenueReportNotifier notifier,
      RevenueReportState state, RevenueSourceFilter source, String label) {
    final bool isActive = state.sourceFilter == source;
    return Padding(
      padding: const EdgeInsets.only(right: 8.0),
      child: ChoiceChip(
        label: Text(label),
        selected: isActive,
        onSelected: (selected) {
          if (selected) notifier.setSourceFilter(source);
        },
        selectedColor: Theme.of(context).primaryColor,
        labelStyle: TextStyle(color: isActive ? Colors.white : Colors.black),
        backgroundColor: Colors.grey[200],
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  Widget _buildFilterChip(RevenueReportNotifier notifier,
      RevenueReportState state, RevenueFilterType filterType, String label) {
    final bool isActive = state.activeFilter == filterType;
    return Padding(
      padding: const EdgeInsets.only(right: 8.0),
      child: ChoiceChip(
        label: Text(label),
        selected: isActive,
        onSelected: (selected) {
          if (selected) notifier.setFilter(filterType);
        },
        selectedColor: Theme.of(context).primaryColor,
        labelStyle: TextStyle(color: isActive ? Colors.white : Colors.black),
        backgroundColor: Colors.grey[200],
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  Widget _buildSummaryCard(RevenueReportState state) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildMetricCard(
                'Total Pendapatan',
                formatter.formatCurrency(state.totalRevenue),
                Ionicons.cash_outline,
                color: Colors.green.shade700,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildMetricCard(
                'Total Transaksi',
                '${state.totalTransactions} pesanan',
                Ionicons.receipt_outline,
                color: Colors.blue.shade700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildMetricCard(
                'Total Pengeluaran',
                formatter.formatCurrency(state.totalExpenses),
                Ionicons.trending_down_outline,
                color: Colors.red.shade600,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildMetricCard(
                'Pendapatan Bersih',
                formatter.formatCurrency(state.netIncome),
                Ionicons.wallet_outline,
                color: Colors.teal.shade800,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMetricCard(String title, String value, IconData icon,
      {Color? color}) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(title,
                      style: Theme.of(context).textTheme.bodyMedium,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis),
                ),
                Icon(icon, color: color ?? Colors.grey, size: 22),
              ],
            ),
            const SizedBox(height: 8),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(value,
                  style: TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 20, color: color),
                  maxLines: 1),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDailyList(RevenueReportState state) {
    final days = state.dailyData!;
    if (days.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 48.0),
          child: Center(child: Text('Tidak ada transaksi pada periode ini.')),
        ),
      );
    }

    return Card(
      elevation: 1,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text('Rincian Harian',
                  style:
                      TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ),
          const Divider(height: 1),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: days.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final day = days[index];
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor:
                      Theme.of(context).primaryColor.withAlpha(30),
                  child: Icon(Ionicons.calendar_outline,
                      color: Theme.of(context).primaryColor, size: 20),
                ),
                title: Text(
                    DateFormat('EEEE, dd MMM yyyy', 'id_ID').format(day.date),
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text('${day.orderCount} transaksi'),
                trailing: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(formatter.formatCurrency(day.total),
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.green.shade700)),
                    const Icon(Icons.chevron_right, color: Colors.grey),
                  ],
                ),
                onTap: () => _showDayDetail(day),
              );
            },
          ),
        ],
      ),
    );
  }

  void _showDayDetail(DailyRevenue day) {
    final b = day.breakdown;
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                    DateFormat('EEEE, dd MMMM yyyy', 'id_ID').format(day.date),
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                // Judul utama: Total Pendapatan + Total Transaksi
                Row(
                  children: [
                    Expanded(
                      child: _summaryTile(
                          'Total Pendapatan',
                          formatter.formatCurrency(day.total),
                          Colors.green.shade700),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _summaryTile('Total Transaksi',
                          '${day.orderCount} pesanan', Colors.blue.shade700),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                const Text('Rincian Metode Pembayaran',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                _breakdownRow('Cash / Tunai', b.cash, Ionicons.cash_outline),
                _breakdownRow('Transfer Bank', b.transfer,
                    Ionicons.swap_horizontal_outline),
                _breakdownRow(
                    'Midtrans (QRIS)', b.midtrans, Ionicons.qr_code_outline),
                if (b.other > 0)
                  _breakdownRow(
                      'Lainnya', b.other, Ionicons.ellipsis_horizontal),
                const Divider(height: 28),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Total',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold)),
                    Text(formatter.formatCurrency(b.total),
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.green.shade700)),
                  ],
                ),
                const Divider(height: 28),
                _breakdownRow('Pengeluaran', day.expenses,
                    Ionicons.trending_down_outline),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _summaryTile(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withAlpha(20),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: Colors.black54, fontSize: 13)),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(value,
                style: TextStyle(
                    fontSize: 18, fontWeight: FontWeight.bold, color: color)),
          ),
        ],
      ),
    );
  }

  Widget _breakdownRow(String label, double amount, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.grey.shade600),
          const SizedBox(width: 12),
          Expanded(child: Text(label, style: const TextStyle(fontSize: 15))),
          Text(formatter.formatCurrency(amount),
              style: const TextStyle(
                  fontSize: 15, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
