import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:ionicons/ionicons.dart'; // Impor ionicons
import '../../models/receivable_data.dart';
import '../../services/report_service.dart';
import '../../utils/pdf_receivable_exporter.dart'; // Impor utilitas PDF
import '../../widgets/reports/order_invoice_dialog.dart';

class ReceivableReportScreen extends StatefulWidget {
  const ReceivableReportScreen({super.key});

  @override
  State<ReceivableReportScreen> createState() => _ReceivableReportScreenState();
}

class _ReceivableReportScreenState extends State<ReceivableReportScreen> {
  final ReportService _reportService = ReportService();
  List<ReceivableData>? _reportData;
  bool _isLoading = false;
  final _currencyFormatter =
      NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);

  DateTime _startDate = DateTime.now().subtract(const Duration(days: 30));
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
      final data = await _reportService.generateReceivableReport(
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

  Future<void> _showInvoiceDialog(ReceivableData receivable) async {
    try {
      final order = await _reportService.getOrderById(receivable.orderId);
      if (!mounted) return;

      showDialog(
        context: context,
        builder: (context) {
          return OrderInvoiceDialog(
            order: order,
            onMarkAsPaid: () async {
              try {
                await _reportService.markOrderAsPaid(order.id);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Pesanan berhasil ditandai lunas.'),
                      backgroundColor: Colors.green,
                    ),
                  );
                  _generateReport();
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Gagal: $e')),
                  );
                }
              }
            },
          );
        },
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal memuat detail pesanan: $e')),
      );
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

  // --- FUNGSI UNTUK EKSPOR PDF ---
  void _exportToPdf() {
    if (_reportData == null || _reportData!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tidak ada data untuk diekspor.')),
      );
      return;
    }
    PdfReceivableExporter.exportToPdf(_reportData!, _startDate, _endDate);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Laporan Piutang Usaha'),
        actions: [
          // --- TOMBOL DOWNLOAD PDF ---
          IconButton(
            icon: const Icon(Ionicons.download_outline),
            onPressed: (_reportData != null && _reportData!.isNotEmpty) ? _exportToPdf : null,
            tooltip: 'Download Laporan (PDF)',
          ),
        ],
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
      return const Center(child: Text('Tidak ada piutang untuk rentang tanggal ini.'));
    }

    final double totalPiutang = _reportData!
        .fold(0, (sum, item) => sum + item.totalReceivable);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
              'Total Piutang: ${_currencyFormatter.format(totalPiutang)}',
              style: Theme.of(context).textTheme.titleLarge),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: _reportData!.length,
            itemBuilder: (context, index) {
              final receivable = _reportData![index];
              return InkWell(
                onTap: () => _showInvoiceDialog(receivable),
                child: Card(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  child: ListTile(
                    title: Text(receivable.customerName, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text(
                        'ID Pesanan: ${receivable.orderId}\nTanggal: ${DateFormat('dd MMM yyyy', 'id_ID').format(receivable.orderDate)}'),
                    trailing: Text(
                      _currencyFormatter.format(receivable.totalReceivable),
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, color: Colors.orange),
                    ),
                    isThreeLine: true,
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
