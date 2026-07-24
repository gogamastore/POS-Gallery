import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/purchase.dart';
import '../../services/report_service.dart';
import '../../widgets/reports/payable_list.dart';
import '../../widgets/reports/payment_dialog.dart';

class PayableReportScreen extends StatefulWidget {
  const PayableReportScreen({super.key});

  @override
  State<PayableReportScreen> createState() => _PayableReportScreenState();
}

class _PayableReportScreenState extends State<PayableReportScreen> {
  final ReportService _reportService = ReportService();
  List<Purchase>? _reportData;
  bool _isLoading = false;

  DateTime _startDate = DateTime.now().subtract(const Duration(days: 30));
  DateTime _endDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _generateReport();
  }

  Future<void> _generateReport() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _reportData = null;
      });
    }

    try {
      final data = await _reportService.generatePayableReport(
        startDate: _startDate,
        endDate: _endDate,
      );
      final unpaidData = data.where((p) => p.paymentStatus?.toLowerCase() != 'paid').toList();
      if (mounted) {
        setState(() {
          _reportData = unpaidData;
        });
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal menghasilkan laporan utang: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showPaymentDialog(Purchase purchase) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return PaymentDialog(
          transaction: purchase,
          onPaymentSuccess: () {
            _generateReport();
          },
        );
      },
    );
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
        title: const Text('Laporan Utang Dagang'),
      ),
      body: Column(
        children: [
          _buildDateRangeSelector(),
          const Divider(height: 1),
          Expanded(
            child: _buildReportContent(),
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
            style: ElevatedButton.styleFrom(
              minimumSize: const Size.fromHeight(50),
            ),
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
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_reportData == null) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Text(
            'Tekan "Hasilkan Laporan" untuk melihat data utang.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    if (_reportData!.isEmpty) {
      return const Center(
        child: Text('Tidak ada utang dagang untuk rentang tanggal yang dipilih.'),
      );
    }

    final double totalUtang = _reportData!.fold(0, (sum, item) => sum + item.totalAmount);
    final int totalTransaksi = _reportData!.length;

    return Column(
      children: [
        _buildSummaryCard(totalUtang, totalTransaksi),
        const Divider(height: 1, thickness: 1),
        Expanded(
          child: PayableList(
            reportData: _reportData!,
            onInitiatePayment: _showPaymentDialog, // <-- PERBAIKAN DI SINI
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryCard(double totalUtang, int totalTransaksi) {
    final currencyFormatter = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      child: Card(
        elevation: 0,
        color: Colors.blue.withAlpha(13),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(color: Colors.blue.withAlpha(51)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildSummaryItem('Total Utang', currencyFormatter.format(totalUtang), Colors.red[700]!),
              _buildSummaryItem('Total Transaksi', totalTransaksi.toString(), Colors.blue[800]!),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryItem(String label, String value, Color valueColor) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 14, color: Colors.black54),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: valueColor,
          ),
        ),
      ],
    );
  }
}
