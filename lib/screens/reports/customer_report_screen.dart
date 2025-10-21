import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/customer_report.dart';
import '../../services/report_service.dart';
import '../../widgets/reports/order_invoice_dialog.dart';
import '../../models/order.dart' as app_order;

class CustomerReportScreen extends StatefulWidget {
  const CustomerReportScreen({super.key});

  @override
  State<CustomerReportScreen> createState() => _CustomerReportScreenState();
}

class _CustomerReportScreenState extends State<CustomerReportScreen> {
  final ReportService _reportService = ReportService();
  List<CustomerReport>? _reportData;
  bool _isLoading = false;
  final _currencyFormatter =
      NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);

  DateTime _startDate = DateTime.now().subtract(const Duration(days: 365));
  DateTime _endDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _generateReport();
  }

  Future<void> _generateReport() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
    });
    try {
      final data = await _reportService.generateCustomerReport(
        startDate: _startDate,
        endDate: _endDate,
      );
      if (mounted) {
        setState(() {
          _reportData = data;
        });
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal menghasilkan laporan: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _selectDate(BuildContext context, bool isStartDate) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: isStartDate ? _startDate : _endDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() {
        if (isStartDate) {
          _startDate = picked;
        } else {
          _endDate = picked;
        }
      });
    }
  }

  void _showHistoryDialog(BuildContext context, CustomerReport customer) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Riwayat Transaksi: ${customer.name}'),
          content: SizedBox(
            width: double.maxFinite,
            child: customer.orders.isEmpty
                ? const Text('Tidak ada transaksi pada periode ini.')
                : ListView.builder(
                    shrinkWrap: true,
                    itemCount: customer.orders.length,
                    itemBuilder: (context, index) {
                      final order = customer.orders[index];
                      return ListTile(
                        title: Text('ID: ${order.id}'),
                        subtitle: Text(DateFormat('dd MMM yyyy', 'id_ID').format(order.date.toDate())),
                        trailing: Text(_currencyFormatter.format(double.tryParse(order.total.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0.0)),
                        onTap: () {
                          Navigator.of(context).pop(); // Tutup dialog riwayat
                          _showInvoiceDialog(order); // Buka dialog faktur
                        },
                      );
                    },
                  ),
          ),
          actions: [
            TextButton(
              child: const Text('Tutup'),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showInvoiceDialog(app_order.Order order) async {
    // Simpan BuildContext sebelum async gap
    final currentContext = context;
    
    showDialog(
      context: currentContext,
      builder: (dialogContext) { // Gunakan context dari builder dialog
        return OrderInvoiceDialog(
          order: order,
          onMarkAsPaid: () async {
            try {
              await _reportService.markOrderAsPaid(order.id);
              if (!mounted) return; // Cek mounted tepat sebelum menggunakan context
              Navigator.of(dialogContext).pop(); // Gunakan context dialog untuk menutup
              ScaffoldMessenger.of(currentContext).showSnackBar(
                const SnackBar(
                  content: Text('Pesanan berhasil ditandai lunas.'),
                  backgroundColor: Colors.green,
                ),
              );
              _generateReport(); // Perbarui laporan setelah menandai lunas
            } catch (e) {
              if (!mounted) return; // Cek mounted tepat sebelum menggunakan context
              ScaffoldMessenger.of(currentContext).showSnackBar(
                SnackBar(content: Text('Gagal: $e')),
              );
            }
          },
        );
      },
    );
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Laporan Pelanggan'),
      ),
      body: Column(
        children: [
          _buildDateRangeSelector(),
          const Divider(height: 1),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _buildReportContent(),
          ),
        ],
      ),
    );
  }

  Widget _buildDateRangeSelector() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildDateButton(true, 'Mulai', _startDate),
              const Icon(Icons.arrow_forward, color: Colors.grey),
              _buildDateButton(false, 'Selesai', _endDate),
            ],
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            icon: const Icon(Icons.analytics),
            label: const Text('Hasilkan Laporan'),
            style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(50)),
            onPressed: _isLoading ? null : _generateReport,
          ),
        ],
      ),
    );
  }

  Widget _buildDateButton(bool isStartDate, String label, DateTime date) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(label, style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 4),
        TextButton(
          child: Text(DateFormat('dd MMM yyyy', 'id_ID').format(date)),
          onPressed: () => _selectDate(context, isStartDate),
        ),
      ],
    );
  }

  Widget _buildReportContent() {
    if (_reportData == null) {
      return const Center(child: Text('Pilih rentang tanggal dan hasilkan laporan.'));
    }
    if (_reportData!.isEmpty) {
      return const Center(child: Text('Tidak ada data pelanggan untuk rentang tanggal ini.'));
    }

    return ListView.builder(
      itemCount: _reportData!.length,
      itemBuilder: (context, index) {
        final customer = _reportData![index];
        return InkWell(
          onTap: () => _showHistoryDialog(context, customer),
          child: Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(customer.name, style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildStatItem('Total Transaksi', '${customer.transactionCount}x'),
                      _buildStatItem('Total Belanja', _currencyFormatter.format(customer.totalSpent)),
                    ],
                  ),
                  const SizedBox(height: 12),
                   if (customer.receivables > 0)
                    Align(
                      alignment: Alignment.centerRight,
                      child: Chip(
                        label: Text('Piutang: ${_currencyFormatter.format(customer.receivables)}'),
                        backgroundColor: Colors.orange.shade100,
                        labelStyle: TextStyle(color: Colors.orange.shade900, fontWeight: FontWeight.bold),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatItem(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 4),
        Text(value, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
      ],
    );
  }
}
