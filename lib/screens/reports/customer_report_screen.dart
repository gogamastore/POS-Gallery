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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal membuat laporan: $e')),
        );
      }
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
    return SingleChildScrollView(
      scrollDirection: Axis.vertical,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: _buildCustomerDataTable(),
      ),
    );
  }

  Widget _buildCustomerDataTable() {
    return DataTable(
      columns: const [
        DataColumn(label: Text('Pelanggan')),
        DataColumn(label: Text('Total Transaksi'), numeric: true),
        DataColumn(label: Text('Total Belanja'), numeric: true),
        DataColumn(label: Text('Total Piutang'), numeric: true),
      ],
      rows: _reportData!.map((customer) {
        return DataRow(
          cells: [
            DataCell(
              SizedBox(
                width: 200,
                child: Text(customer.name, overflow: TextOverflow.ellipsis),
              ),
              onTap: () => _showCustomerDetails(customer),
            ),
            DataCell(
              Text(customer.transactionCount.toString()),
              onTap: () => _showCustomerDetails(customer),
            ),
            DataCell(
              Text(_currencyFormatter.format(customer.totalSpent)),
              onTap: () => _showCustomerDetails(customer),
            ),
            DataCell(
              Text(_currencyFormatter.format(customer.receivables)),
              onTap: () => _showCustomerDetails(customer),
            ),
          ],
        );
      }).toList(),
    );
  }

  void _showCustomerDetails(CustomerReport customer) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Detail Transaksi - ${customer.name}'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: customer.orders.length,
              itemBuilder: (context, index) {
                final order = customer.orders[index];
                return Card(
                  child: ListTile(
                    title: Text('ID Pesanan: ${order.id}'),
                    subtitle: Text('Tanggal: ${DateFormat('dd/MM/yy').format(order.date.toDate())}\n'
                        'Status: ${order.status} (${order.paymentStatus})'),
                    trailing: Text(_currencyFormatter.format(order.total)),
                    onTap: () {
                       _showOrderDetailsDialog(context, order);
                    },
                  ),
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

  void _showOrderDetailsDialog(BuildContext dialogContext, app_order.Order order) {
    showDialog(
      context: dialogContext,
      builder: (context) {
        return OrderInvoiceDialog(
          order: order,
          onMarkAsPaid: () async {
            final orderId = order.id;
            // PERBAIKAN: Memastikan orderId tidak null
            if (orderId == null || orderId.isEmpty) {
              // PERBAIKAN: Pemeriksaan mounted sebelum menggunakan context
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Error: ID Pesanan tidak valid.')),
                );
              }
              return;
            }

            try {
              await _reportService.markOrderAsPaid(orderId);
              // PERBAIKAN: Pemeriksaan mounted sebelum menggunakan context
              if (mounted) {
                Navigator.of(context).pop(); // Tutup dialog faktur
                Navigator.of(dialogContext).pop(); // Tutup dialog detail pelanggan
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Pesanan berhasil ditandai LUNAS.'),
                    backgroundColor: Colors.green,
                  ),
                );
              }
              _generateReport(); // Muat ulang laporan
            } catch (e) {
              // PERBAIKAN: Pemeriksaan mounted sebelum menggunakan context
              if (mounted) {
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Gagal memperbarui status: $e')),
                );
              }
            }
          },
        );
      },
    );
  }
}
