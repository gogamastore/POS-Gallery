import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:ionicons/ionicons.dart';

import '../../providers/product_provider.dart';
import '../../services/sound_service.dart';
import '../products/barcode_scanner_screen.dart';
import 'stock_history_dialog.dart';

class StockFlowReportScreen extends ConsumerStatefulWidget {
  const StockFlowReportScreen({super.key});

  @override
  ConsumerState<StockFlowReportScreen> createState() =>
      _StockFlowReportScreenState();
}

class _StockFlowReportScreenState extends ConsumerState<StockFlowReportScreen> {
  // --- MODIFIKASI: Menambahkan state untuk pencarian ---
  final TextEditingController _searchController = TextEditingController();
  String _searchTerm = '';
  late final SoundService _soundService;
  // Rentang tanggal riwayat — default 30 hari terakhir (sama seperti web).
  late DateTimeRange _dateRange;

  @override
  void initState() {
    super.initState();
    _soundService = SoundService();
    final now = DateTime.now();
    _dateRange = DateTimeRange(
      start: DateTime(now.year, now.month, now.day).subtract(const Duration(days: 30)),
      end: DateTime(now.year, now.month, now.day, 23, 59, 59),
    );
    _searchController.addListener(() {
      if (mounted) {
        setState(() {
          _searchTerm = _searchController.text;
        });
      }
    });
  }

  Future<void> _pickDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: _dateRange,
    );
    if (picked != null && mounted) {
      setState(() {
        _dateRange = DateTimeRange(
          start: DateTime(picked.start.year, picked.start.month, picked.start.day),
          end: DateTime(picked.end.year, picked.end.month, picked.end.day, 23, 59, 59),
        );
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _soundService.dispose();
    super.dispose();
  }

  // --- MODIFIKASI: Menambahkan fungsi navigasi ke pemindai barcode ---
  Future<void> _navigateToScanner() async {
    if (!mounted) return;
    final sku = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (context) => const BarcodeScannerScreen()),
    );

    if (sku != null) {
      _searchController.text = sku;
      await _soundService.playSuccessSound();
    } else {
      await _soundService.playErrorSound();
    }
  }

  @override
  Widget build(BuildContext context) {
    final productsAsyncValue = ref.watch(allProductsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Laporan Arus Stok'),
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_today),
            tooltip: 'Filter tanggal',
            onPressed: _pickDateRange,
          ),
        ],
      ),
      body: Column(
        children: [
          // --- MODIFIKASI: Menambahkan TextField untuk pencarian ---
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Cari nama atau pindai SKU...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: IconButton(
                  icon: const Icon(Ionicons.barcode_outline),
                  onPressed: _navigateToScanner,
                  tooltip: 'Pindai Barcode',
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8.0),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12),
              ),
            ),
          ),
          // Indikator rentang tanggal riwayat (ketuk untuk ubah).
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: InkWell(
              onTap: _pickDateRange,
              borderRadius: BorderRadius.circular(6),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    const Icon(Icons.date_range, size: 16, color: Colors.grey),
                    const SizedBox(width: 6),
                    Text(
                      'Riwayat: ${DateFormat('d MMM yyyy').format(_dateRange.start)} – ${DateFormat('d MMM yyyy').format(_dateRange.end)}',
                      style: const TextStyle(fontSize: 13, color: Colors.black87),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: productsAsyncValue.when(
              data: (products) {
                // --- MODIFIKASI: Logika untuk memfilter produk ---
                final filteredProducts = products.where((product) {
                  if (_searchTerm.isEmpty) {
                    return true; // Tampilkan semua jika tidak ada pencarian
                  }
                  final nameLower = product.name.toLowerCase();
                  final skuLower = product.sku?.toLowerCase() ?? '';
                  final searchLower = _searchTerm.toLowerCase();
                  return nameLower.contains(searchLower) || skuLower.contains(searchLower);
                }).toList();

                if (filteredProducts.isEmpty) {
                  return const Center(child: Text('Tidak ada produk yang cocok.'));
                }
                return ListView.builder(
                  itemCount: filteredProducts.length,
                  itemBuilder: (context, index) {
                    final product = filteredProducts[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.grey[200],
                          backgroundImage: product.image != null && product.image!.isNotEmpty
                              ? NetworkImage(product.image!)
                              : null,
                          child: product.image == null || product.image!.isEmpty
                              ? const Icon(Icons.inventory_2, color: Colors.grey)
                              : null,
                        ),
                        title: Text(product.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text('SKU: ${product.sku ?? '-'}'),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            const Text('Stok Saat Ini', style: TextStyle(fontSize: 12)),
                            Text(
                              product.stock.toString(),
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.blue),
                            ),
                          ],
                        ),
                        onTap: () {
                          showDialog(
                            context: context,
                            builder: (context) => StockHistoryDialog(
                              productId: product.id,
                              dateRange: _dateRange,
                            ),
                          );
                        },
                      ),
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, stack) => Center(child: Text('Error: $err')),
            ),
          ),
        ],
      ),
    );
  }
}
