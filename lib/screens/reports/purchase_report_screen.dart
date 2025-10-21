import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:ionicons/ionicons.dart';
import '../purchases/edit_purchase_screen.dart';

import '../../models/purchase_transaction.dart';
import '../../providers/purchase_report_provider.dart';
import '../../providers/product_images_provider.dart'; // Sekarang menggunakan productProvider dari file ini

class PurchaseReportScreen extends ConsumerStatefulWidget {
  const PurchaseReportScreen({super.key});

  @override
  ConsumerState<PurchaseReportScreen> createState() =>
      _PurchaseReportScreenState();
}

class _PurchaseReportScreenState extends ConsumerState<PurchaseReportScreen> {
  DateTimeRange? _selectedDateRange;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedDateRange = DateTimeRange(
        start: now.subtract(const Duration(days: 30)), end: now);
  }

  Future<void> _selectDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      initialDateRange: _selectedDateRange,
      builder: (context, child) {
        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: 800.0,
              maxHeight: 500.0,
            ),
            child: child,
          ),
        );
      },
    );
    if (picked != null && picked != _selectedDateRange) {
      setState(() {
        _selectedDateRange = picked;
      });
    }
  }

  void _resetFilter() {
    setState(() {
      final now = DateTime.now();
      _selectedDateRange = DateTimeRange(
          start: now.subtract(const Duration(days: 30)), end: now);
    });
  }

  @override
  Widget build(BuildContext context) {
    final transactionsAsync = ref.watch(purchaseTransactionsProvider);
    final currencyFormatter =
        NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Laporan Pembelian'),
        leading: IconButton(
          icon: const Icon(Ionicons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: transactionsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Gagal memuat data: $err')),
        data: (allTransactions) {
          final filteredTransactions = allTransactions.where((t) {
            if (_selectedDateRange == null) return true;
            final transactionDate =
                DateTime(t.date.year, t.date.month, t.date.day);
            final startDate = DateTime(_selectedDateRange!.start.year,
                _selectedDateRange!.start.month, _selectedDateRange!.start.day);
            final endDate = DateTime(_selectedDateRange!.end.year,
                _selectedDateRange!.end.month, _selectedDateRange!.end.day);
            return !transactionDate.isBefore(startDate) &&
                !transactionDate.isAfter(endDate);
          }).toList();

          final totalPurchase = filteredTransactions.fold<double>(
              0, (sum, item) => sum + item.totalAmount);
          final transactionCount = filteredTransactions.length;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildFilterCard(),
                const SizedBox(height: 16),
                _buildMetricsGrid(
                    totalPurchase, transactionCount, currencyFormatter),
                const SizedBox(height: 16),
                _buildTrendsCard(filteredTransactions, currencyFormatter),
                const SizedBox(height: 16),
                _buildTransactionsTable(
                    filteredTransactions, currencyFormatter),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildFilterCard() {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Filter Data', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: _selectDateRange,
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Ionicons.calendar_outline),
                        border: OutlineInputBorder(),
                      ),
                      child: Text(
                        _selectedDateRange == null
                            ? 'Pilih Tanggal'
                            : '${DateFormat('dd MMM yyyy').format(_selectedDateRange!.start)} - ${DateFormat('dd MMM yyyy').format(_selectedDateRange!.end)}',
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                IconButton(
                  icon: const Icon(Ionicons.refresh_outline),
                  onPressed: _resetFilter,
                  tooltip: 'Reset Filter',
                  style: IconButton.styleFrom(
                      backgroundColor:
                          Theme.of(context).colorScheme.secondaryContainer),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }

  Widget _buildMetricsGrid(double total, int count, NumberFormat formatter) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 2.2, 
      children: [
        _buildMetricCard(
            'Total Transaksi', formatter.format(total), Ionicons.cash_outline),
        _buildMetricCard(
            'Jumlah Nota', count.toString(), Ionicons.document_text_outline),
      ],
    );
  }

  Widget _buildMetricCard(String title, String value, IconData icon) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Flexible(
                    child: Text(title,
                        style: Theme.of(context).textTheme.bodyMedium)),
                Icon(icon, color: Colors.grey, size: 22),
              ],
            ),
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  value,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 22),
                  maxLines: 1,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTrendsCard(
      List<PurchaseTransaction> transactions, NumberFormat formatter) {
    final Map<DateTime, double> dailyTotals = {};
    for (var t in transactions) {
      final date = DateTime(t.date.year, t.date.month, t.date.day);
      dailyTotals.update(date, (value) => value + t.totalAmount,
          ifAbsent: () => t.totalAmount);
    }

    final spots = dailyTotals.entries.map((entry) {
      return FlSpot(entry.key.millisecondsSinceEpoch.toDouble(), entry.value);
    }).toList();

    spots.sort((a, b) => a.x.compareTo(b.x));

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Tren Pembelian',
                style: Theme.of(context).textTheme.titleLarge),
            Text('Visualisasi pengeluaran harian',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: Colors.grey)),
            const SizedBox(height: 24),
            if (spots.length > 1)
              SizedBox(
                height: 200,
                child: LineChart(
                  LineChartData(
                    gridData:
                        const FlGridData(show: true, drawVerticalLine: false),
                    titlesData: FlTitlesData(
                      show: true,
                      rightTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false)),
                      topTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false)),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 30,
                          getTitlesWidget: (value, meta) {
                            final date = DateTime.fromMillisecondsSinceEpoch(
                                value.toInt());
                            return Padding(
                              padding: const EdgeInsets.only(top: 8.0),
                              child: Text(DateFormat('dd/MM').format(date),
                                  style: const TextStyle(fontSize: 10)),
                            );
                          },
                          interval: spots.length > 5
                              ? (spots.last.x - spots.first.x) / 4
                              : null,
                        ),
                      ),
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 80,
                          getTitlesWidget: (value, meta) {
                            return Padding(
                              padding: const EdgeInsets.only(right: 8.0),
                              child: Text(
                                  NumberFormat.compactCurrency(
                                          locale: 'id_ID', symbol: 'Rp')
                                      .format(value),
                                  style: const TextStyle(fontSize: 10)),
                            );
                          },
                        ),
                      ),
                    ),
                    borderData: FlBorderData(
                        show: true,
                        border: Border.all(color: Colors.grey.shade300)),
                    minX: spots.first.x,
                    maxX: spots.last.x,
                    lineBarsData: [
                      LineChartBarData(
                        spots: spots,
                        isCurved: true,
                        color: Theme.of(context).primaryColor,
                        barWidth: 3,
                        isStrokeCapRound: true,
                        dotData: const FlDotData(show: false),
                        belowBarData: BarAreaData(
                            show: true,
                            color:
                                Theme.of(context).primaryColor.withAlpha(50)),
                      ),
                    ],
                  ),
                ),
              )
            else
              const SizedBox(
                height: 200,
                child: Center(
                    child: Text('Data tidak cukup untuk menampilkan grafik.')),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTransactionsTable(
      List<PurchaseTransaction> transactions, NumberFormat formatter) {
    return Card(
      elevation: 1,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          showCheckboxColumn: false,
          columnSpacing: 24,
          columns: const [
            DataColumn(label: Text('Tanggal')),
            DataColumn(label: Text('Supplier')),
            DataColumn(label: Text('Status Pembayaran')),
            DataColumn(label: Text('Total'), numeric: true),
          ],
          rows: transactions.map((t) {
            return DataRow(
              onSelectChanged: (isSelected) {
                if (isSelected ?? false) {
                  _showInvoiceDialog(context, t, formatter);
                }
              },
              cells: [
                DataCell(Text(DateFormat('dd MMM yyyy').format(t.date))),
                DataCell(Text(t.supplierName, overflow: TextOverflow.ellipsis)),
                DataCell(
                  Chip(
                    label: Text(t.paymentStatus,
                        style: const TextStyle(fontSize: 12)),
                    backgroundColor: t.paymentStatus == 'Lunas'
                        ? Colors.green.shade100
                        : Colors.orange.shade100,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    visualDensity: VisualDensity.compact,
                  ),
                ),
                DataCell(Text(formatter.format(t.totalAmount))),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  void _showInvoiceDialog(BuildContext context, PurchaseTransaction transaction,
      NumberFormat formatter) {
    String getPaymentMethodDisplayName(String paymentMethod) {
      switch (paymentMethod.toLowerCase()) {
        case 'bank_transfer':
          return 'Transfer Bank';
        case 'cash':
          return 'Cash';
        case 'credit':
          return 'Kredit';
        default:
          return paymentMethod;
      }
    }

    showDialog(
      context: context,
      builder: (context) {
        // Hapus Consumer di sini karena akan kita gunakan di dalam baris
        return Dialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: ConstrainedBox(
            constraints:
                const BoxConstraints(maxHeight: 600, maxWidth: 600),
            child: Stack(
              children: [
                Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('Faktur Pembelian',
                          style: Theme.of(context)
                              .textTheme
                              .headlineSmall
                              ?.copyWith(fontWeight: FontWeight.bold)),
                      Text('#${transaction.id}',
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(
                                  color: Colors.grey,
                                  overflow: TextOverflow.ellipsis)),
                      const SizedBox(height: 16),
                      Text(
                          'Tanggal: ${DateFormat('dd MMMM yyyy').format(transaction.date)}'),
                      Text('Supplier: ${transaction.supplierName}'),
                      const Divider(height: 24),
                      Text('Rincian Produk Dibeli',
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Expanded(
                        child: SingleChildScrollView(
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: DataTable(
                              columnSpacing: 10,
                              horizontalMargin: 10,
                              columns: const [
                                DataColumn(label: Text('Produk')),
                                DataColumn(
                                    label: Text('Jml'), numeric: true),
                                DataColumn(
                                    label: Text('Harga'), numeric: true),
                                DataColumn(
                                    label: Text('Subtotal'),
                                    numeric: true),
                              ],
                              rows: transaction.items.map((item) {
                                // Setiap baris sekarang adalah Consumer
                                return DataRow(
                                  cells: [
                                    DataCell(
                                      SizedBox(
                                        width: 180,
                                        child: Row(
                                          children: [
                                            // --- INTI PERBAIKAN ---
                                            Consumer(
                                              builder: (context, ref, _) {
                                                final productAsync = ref.watch(productProvider(item.productId));
                                                return productAsync.when(
                                                  loading: () => const SizedBox(
                                                    width: 37,
                                                    height: 37,
                                                    child: Center(
                                                      child: Padding(
                                                        padding: EdgeInsets.all(8.0),
                                                        child: CircularProgressIndicator(strokeWidth: 2),
                                                      ),
                                                    ),
                                                  ),
                                                  error: (e, s) => Container(
                                                    width: 37,
                                                    height: 37,
                                                    color: Colors.grey.shade200,
                                                    child: const Icon(Ionicons.alert_circle_outline, color: Colors.red),
                                                  ),
                                                  data: (product) {
                                                    final imageUrl = product?.image;
                                                    if (imageUrl != null && imageUrl.isNotEmpty) {
                                                      return Image.network(
                                                        imageUrl,
                                                        width: 37,
                                                        height: 37,
                                                        fit: BoxFit.cover,
                                                        loadingBuilder: (context, child, progress) {
                                                          if (progress == null) return child;
                                                          return const SizedBox(
                                                            width: 37,
                                                            height: 37,
                                                            child: Center(
                                                              child: CircularProgressIndicator(strokeWidth: 2),
                                                            ),
                                                          );
                                                        },
                                                        errorBuilder: (c, e, s) => Container(
                                                          width: 37,
                                                          height: 37,
                                                          color: Colors.grey.shade200,
                                                          child: const Icon(Ionicons.image_outline),
                                                        ),
                                                      );
                                                    } else {
                                                      return Container(
                                                        width: 37,
                                                        height: 37,
                                                        color: Colors.grey.shade200,
                                                        child: const Icon(Ionicons.image_outline),
                                                      );
                                                    }
                                                  },
                                                );
                                              },
                                            ),
                                            // --- AKHIR PERBAIKAN ---
                                            const SizedBox(width: 8),
                                            Flexible(
                                                child: Text(
                                                    item.productName,
                                                    style:
                                                        const TextStyle(
                                                            fontSize: 10),
                                                    maxLines: 2,
                                                    overflow: TextOverflow
                                                        .ellipsis)),
                                          ],
                                        ),
                                      ),
                                    ),
                                    DataCell(Text(
                                        item.quantity.toString(),
                                        style: const TextStyle(
                                            fontSize: 10))),
                                    DataCell(Text(
                                        formatter
                                            .format(item.purchasePrice),
                                        style: const TextStyle(
                                            fontSize: 10))),
                                    DataCell(Text(
                                        formatter.format(item.quantity *
                                            item.purchasePrice),
                                        style: const TextStyle(
                                            fontSize: 10))),
                                  ],
                                );
                              }).toList(),
                            ),
                          ),
                        ),
                      ),
                      const Divider(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                              'Metode: ${getPaymentMethodDisplayName(transaction.paymentMethod)}',
                              style: Theme.of(context).textTheme.bodySmall,
                              overflow: TextOverflow.ellipsis),
                          Flexible(
                              child: Text(
                                  'Total: ${formatter.format(transaction.totalAmount)}',
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleMedium
                                      ?.copyWith(
                                          fontWeight: FontWeight.bold),
                                  overflow: TextOverflow.ellipsis)),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton.icon(
                              onPressed: () {},
                              icon: const Icon(Ionicons.print_outline,
                                  size: 16),
                              label: const Text('Download')),
                          const SizedBox(width: 8),
                          TextButton.icon(
                              onPressed: () {
                                Navigator.of(context).pop(); 
                                Navigator.of(context)
                                    .push(MaterialPageRoute(
                                  builder: (context) => EditPurchaseScreen(
                                      transaction: transaction),
                                ));
                              },
                              icon: const Icon(Ionicons.create_outline,
                                  size: 16),
                              label: const Text('Edit')),
                        ],
                      ),
                    ],
                  ),
                ),
                Positioned(
                  top: 8,
                  right: 8,
                  child: IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
