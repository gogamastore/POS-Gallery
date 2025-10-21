import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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

  @override
  void initState() {
    super.initState();
    _soundService = SoundService();
    _searchController.addListener(() {
      if (mounted) {
        setState(() {
          _searchTerm = _searchController.text;
        });
      }
    });
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
        // --- MODIFIKASI: Menghapus tombol kalender ---
        actions: const [],
      ),
      body: Column(
        children: [
          // --- MODIFIKASI: Menambahkan TextField untuk pencarian ---
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
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
                              // --- MODIFIKASI: Menghapus dateRange ---
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
