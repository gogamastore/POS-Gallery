import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/product_sales_data.dart';
import '../../services/report_service.dart';
import '../../widgets/reports/product_sales_list.dart';

class ProductSalesReportScreen extends StatefulWidget {
  const ProductSalesReportScreen({super.key});

  @override
  State<ProductSalesReportScreen> createState() => _ProductSalesReportScreenState();
}

class _ProductSalesReportScreenState extends State<ProductSalesReportScreen> {
  final ReportService _reportService = ReportService();
  List<ProductSalesData>? _reportData;
  bool _isLoading = false;

  // Default rentang tanggal: 1 bulan terakhir
  DateTime _startDate = DateTime.now().subtract(const Duration(days: 30));
  DateTime _endDate = DateTime.now();

  Future<void> _generateReport() async {
    setState(() {
      _isLoading = true;
      _reportData = null; // Kosongkan data sebelumnya
    });

    try {
      final data = await _reportService.generateProductSalesReport(
        startDate: _startDate,
        endDate: _endDate,
      );
      setState(() {
        _reportData = data;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal menghasilkan laporan: $e')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _selectDate(BuildContext context, bool isStartDate) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: isStartDate ? _startDate : _endDate,
      firstDate: DateTime(2020), // Batas awal
      lastDate: DateTime.now(),   // Batas akhir
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
        title: const Text('Laporan Penjualan Produk'),
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
              minimumSize: const Size.fromHeight(50), // Buat tombol lebih besar
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
        child: Text('Pilih rentang tanggal dan hasilkan laporan untuk melihat data.'),
      );
    }

    if (_reportData!.isEmpty) {
      return const Center(
        child: Text('Tidak ada data penjualan untuk rentang tanggal yang dipilih.'),
      );
    }

    // --- PERBAIKAN DI SINI ---
    return ProductSalesList(
      reportData: _reportData!,
      startDate: _startDate, // Teruskan tanggal mulai
      endDate: _endDate,     // Teruskan tanggal selesai
    );
    // -------------------------
  }
}
