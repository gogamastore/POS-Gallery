import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:ionicons/ionicons.dart';

import '../../models/sales_report_data.dart';
import '../../providers/sales_report_provider.dart';
import '../../providers/product_images_provider.dart';
import '../../providers/user_provider.dart'; // DIIMPOR
import '../../models/user_model.dart'; // DIIMPOR
import '../../utils/formatter.dart' as formatter;

class SalesReportScreen extends ConsumerStatefulWidget {
  const SalesReportScreen({super.key});

  @override
  ConsumerState<SalesReportScreen> createState() => _SalesReportScreenState();
}

class _SalesReportScreenState extends ConsumerState<SalesReportScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref
          .read(salesReportProvider.notifier)
          .setFilter(SalesReportFilterType.today);
    });
  }

  Future<void> _selectDateRange(SalesReportNotifier notifier) async {
    final state = ref.read(salesReportProvider);
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
    final state = ref.watch(salesReportProvider);
    final notifier = ref.read(salesReportProvider.notifier);
    final userData = ref.watch(userDataProvider); // DITAMBAHKAN

    return Scaffold(
      appBar: AppBar(
        title: const Text('Laporan Penjualan'),
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
            else if (state.reportData != null) ...[
              userData.when(
                data: (user) => _buildMetrics(state.reportData!, user),
                loading: () =>
                    const SizedBox.shrink(), // Atau widget loading kecil
                error: (err, stack) =>
                    const SizedBox.shrink(), // Sembunyikan jika error
              ),
              const SizedBox(height: 16),
              _buildTrendsCard(state.reportData!),
              const SizedBox(height: 16),
              _buildTransactionsTable(state.reportData!),
            ] else
              const Center(child: Text('Tidak ada data untuk ditampilkan.')),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterCard(
      SalesReportNotifier notifier, SalesReportState state) {
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
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildFilterChip(
                      notifier, state, SalesReportFilterType.today, 'Hari Ini'),
                  _buildFilterChip(notifier, state,
                      SalesReportFilterType.yesterday, 'Kemarin'),
                  _buildFilterChip(notifier, state,
                      SalesReportFilterType.last7days, '7 Hari Terakhir'),
                  _buildFilterChip(notifier, state,
                      SalesReportFilterType.thisMonth, 'Bulan Ini'),
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
                  filled: state.activeFilter == SalesReportFilterType.custom,
                  fillColor: Theme.of(context).primaryColor.withOpacity(0.1),
                ),
                child: Text(
                  state.selectedDateRange == null
                      ? 'Pilih Tanggal'
                      : '${DateFormat('dd MMM yyyy').format(state.selectedDateRange!.start)} - ${DateFormat('dd MMM yyyy').format(state.selectedDateRange!.end)}',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(SalesReportNotifier notifier, SalesReportState state,
      SalesReportFilterType filterType, String label) {
    final bool isActive = state.activeFilter == filterType;
    return Padding(
      padding: const EdgeInsets.only(right: 8.0),
      child: ChoiceChip(
        label: Text(label),
        selected: isActive,
        onSelected: (selected) {
          if (selected) {
            notifier.setFilter(filterType);
          }
        },
        selectedColor: Theme.of(context).primaryColor,
        labelStyle: TextStyle(color: isActive ? Colors.white : Colors.black),
        backgroundColor: Colors.grey[200],
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  Widget _buildMetrics(SalesReportData data, UserModel? user) {
    final bool canViewFinancials =
        user != null && (user.position == 'Admin' || user.position == 'Owner');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (canViewFinancials)
          Row(
            children: [
              Expanded(
                child: _buildMetricCard(
                  'Total Penjualan',
                  formatter.formatCurrency(data.totalRevenue),
                  Ionicons.cash_outline,
                  color: Colors.blue.shade700,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildMetricCard(
                  'Laba Kotor',
                  formatter.formatCurrency(data.grossProfit),
                  Ionicons.wallet_outline,
                  color: Colors.green.shade700,
                ),
              ),
            ],
          ),
        if (canViewFinancials) const SizedBox(height: 12),
        _buildMetricCard(
          'Total Pesanan',
          data.orders.length.toString(),
          Ionicons.document_text_outline,
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
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.bodyMedium,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Icon(icon, color: color ?? Colors.grey, size: 22),
              ],
            ),
            const SizedBox(height: 8),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                value,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 22,
                  color: color,
                ),
                maxLines: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTrendsCard(SalesReportData data) {
    final Map<DateTime, double> dailyTotals = {};
    for (var order in data.orders) {
      final date = DateTime(order.orderDate.toDate().year,
          order.orderDate.toDate().month, order.orderDate.toDate().day);
      dailyTotals.update(date, (value) => value + order.totalRevenue,
          ifAbsent: () => order.totalRevenue);
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
            Text('Tren Penjualan',
                style: Theme.of(context).textTheme.titleLarge),
            Text('Visualisasi pendapatan harian',
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

  Widget _buildTransactionsTable(SalesReportData data) {
    return Card(
      elevation: 1,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: ConstrainedBox(
          constraints:
              BoxConstraints(minWidth: MediaQuery.of(context).size.width),
          child: DataTable(
            showCheckboxColumn: false,
            columnSpacing: 24,
            columns: const [
              DataColumn(label: Text('Tanggal')),
              DataColumn(label: Text('Pelanggan')),
              DataColumn(label: Text('Total'), numeric: true),
              DataColumn(label: Text('Status')),
            ],
            rows: data.orders.map((order) {
              return DataRow(
                onSelectChanged: (isSelected) {
                  if (isSelected ?? false) {
                    _showInvoiceDialog(context, order);
                  }
                },
                cells: [
                  DataCell(Text(DateFormat('dd MMM yyyy')
                      .format(order.orderDate.toDate()))),
                  DataCell(Text(order.customerName,
                      overflow: TextOverflow.ellipsis)),
                  DataCell(Text(formatter.formatCurrency(order.totalRevenue))),
                  DataCell(Text(_translateStatus(order.status))),
                ],
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  String _translateStatus(String status) {
    switch (status) {
      case 'Processing':
        return 'Perlu Dikirim';
      case 'Shipped':
        return 'Selesai';
      case 'Delivered':
        return 'Dikirim';
      default:
        return status;
    }
  }

  void _showInvoiceDialog(BuildContext context, SalesReportOrder order) {
    final images = ref.watch(productImagesProvider);

    String getPaymentStatusText(String status) {
      switch (status.toLowerCase()) {
        case 'paid':
          return 'Lunas';
        case 'unpaid':
          return 'Belum Bayar';
        default:
          return status;
      }
    }

    Color getPaymentStatusColor(String status) {
      switch (status.toLowerCase()) {
        case 'paid':
          return Colors.green.shade700;
        case 'unpaid':
          return Colors.red.shade700;
        default:
          return Colors.grey.shade700;
      }
    }

    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 600, maxWidth: 600),
            child: Stack(
              children: [
                Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('Faktur Penjualan',
                          style: Theme.of(context)
                              .textTheme
                              .headlineSmall
                              ?.copyWith(fontWeight: FontWeight.bold)),
                      Text('#${order.orderId}',
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(
                                  color: Colors.grey,
                                  overflow: TextOverflow.ellipsis)),
                      const SizedBox(height: 16),
                      Text(
                          'Tanggal: ${DateFormat('dd MMMM yyyy').format(order.orderDate.toDate())}'),
                      Text('Pelanggan: ${order.customerName}'),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Text('Status Pembayaran: '),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: getPaymentStatusColor(order.paymentStatus)
                                  .withAlpha(30),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              getPaymentStatusText(order.paymentStatus),
                              style: TextStyle(
                                color:
                                    getPaymentStatusColor(order.paymentStatus),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const Divider(height: 24),
                      Text('Rincian Produk Terjual',
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Expanded(
                        child: images.when(
                          loading: () =>
                              const Center(child: CircularProgressIndicator()),
                          error: (err, stack) =>
                              const Center(child: Text('Gagal memuat gambar')),
                          data: (imageMap) {
                            return SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: SingleChildScrollView(
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
                                        label: Text('Subtotal'), numeric: true),
                                  ],
                                  rows: order.items.map((item) {
                                    final imageUrl = imageMap[item.productId];
                                    return DataRow(
                                      cells: [
                                        DataCell(
                                          SizedBox(
                                            width: 180,
                                            child: Row(
                                              children: [
                                                if (imageUrl != null &&
                                                    imageUrl.isNotEmpty)
                                                  Image.network(imageUrl,
                                                      width: 37,
                                                      height: 37,
                                                      fit: BoxFit.cover,
                                                      errorBuilder: (c, e, s) =>
                                                          const Icon(
                                                              Ionicons
                                                                  .image_outline,
                                                              size: 37))
                                                else
                                                  Container(
                                                      width: 37,
                                                      height: 37,
                                                      color:
                                                          Colors.grey.shade200,
                                                      child: const Icon(Ionicons
                                                          .image_outline)),
                                                const SizedBox(width: 8),
                                                Flexible(
                                                    child: Text(
                                                        item.productName,
                                                        style: const TextStyle(
                                                            fontSize: 10),
                                                        maxLines: 2,
                                                        overflow: TextOverflow
                                                            .ellipsis)),
                                              ],
                                            ),
                                          ),
                                        ),
                                        DataCell(Text(item.quantity.toString(),
                                            style:
                                                const TextStyle(fontSize: 10))),
                                        DataCell(Text(
                                            formatter
                                                .formatCurrency(item.salePrice),
                                            style:
                                                const TextStyle(fontSize: 10))),
                                        DataCell(Text(
                                            formatter
                                                .formatCurrency(item.totalSale),
                                            style:
                                                const TextStyle(fontSize: 10))),
                                      ],
                                    );
                                  }).toList(),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      const Divider(height: 24),
                      _buildDialogTotalRow(context, 'Total Penjualan',
                          formatter.formatCurrency(order.totalRevenue)),
                      _buildDialogTotalRow(context, 'Total Pokok (HPP)',
                          formatter.formatCurrency(order.totalCogs)),
                      _buildDialogTotalRow(context, 'Laba Kotor',
                          formatter.formatCurrency(order.grossProfit),
                          isProfit: true),
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

  Widget _buildDialogTotalRow(BuildContext context, String label, String value,
      {bool isProfit = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodyLarge),
          Text(
            value,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: isProfit ? Colors.green.shade700 : null,
                ),
          ),
        ],
      ),
    );
  }
}
