import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:ionicons/ionicons.dart';

import '../../models/product.dart';
import '../../providers/auth_provider.dart';
import '../../providers/product_provider.dart';
import '../../providers/stock_provider.dart';
import '../../services/sound_service.dart';
import '../../widgets/stock_adjustment_dialog.dart';
import '../products/barcode_scanner_screen.dart';

class StockManagementScreen extends ConsumerStatefulWidget {
  const StockManagementScreen({super.key});

  @override
  ConsumerState<StockManagementScreen> createState() =>
      _StockManagementScreenState();
}

class _StockManagementScreenState extends ConsumerState<StockManagementScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchTerm = '';
  bool _sortByLowestStock = false;

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

  void _showStockAdjustmentDialog(Product product) async {
    if (!mounted) return;

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => StockAdjustmentDialog(product: product),
    );

    if (result != null && mounted) {
      // --- PERBAIKAN KRITIS: Menggunakan provider 'authStateChangesProvider' yang benar ---
      final user = ref.read(authStateChangesProvider).value;
      if (user == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Error: Anda tidak terautentikasi.')),
          );
        }
        return;
      }
      
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return const Center(child: CircularProgressIndicator());
        },
      );

      try {
        await ref.read(stockServiceProvider).adjustStock(
              productId: product.id,
              type: result['type'],
              quantity: result['quantity'],
              reason: result['reason'],
              userId: user.uid,
            );

        if (mounted) Navigator.of(context).pop();

        ref.invalidate(allProductsProvider);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Stok berhasil diperbarui'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) Navigator.of(context).pop();
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Gagal memperbarui stok: $e')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final productsAsyncValue = ref.watch(allProductsProvider);
    final currencyFormatter = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Manajemen Stok'),
      ),
      body: productsAsyncValue.when(
        data: (products) {
          List<Product> processedProducts = List.from(products);

          if (_searchTerm.isNotEmpty) {
            processedProducts = processedProducts.where((product) {
              final nameLower = product.name.toLowerCase();
              final skuLower = product.sku?.toLowerCase() ?? '';
              final searchLower = _searchTerm.toLowerCase();
              return nameLower.contains(searchLower) || skuLower.contains(searchLower);
            }).toList();
          }

          if (_sortByLowestStock) {
            processedProducts.sort((a, b) => a.stock.compareTo(b.stock));
          }

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
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
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4.0),
                child: SwitchListTile(
                  title: const Text('Urutkan berdasarkan stok terendah', style: TextStyle(fontSize: 14)),
                  value: _sortByLowestStock,
                  onChanged: (bool value) {
                    setState(() {
                      _sortByLowestStock = value;
                    });
                  },
                  dense: true,
                  activeThumbColor: Theme.of(context).primaryColor,
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: processedProducts.isEmpty
                    ? const Center(child: Text('Produk tidak ditemukan.'))
                    : _buildStockList(processedProducts, currencyFormatter),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Terjadi error: $err')),
      ),
    );
  }

  Widget _buildStockList(List<Product> products, NumberFormat currencyFormatter) {
    return ListView.builder(
      padding: const EdgeInsets.only(top: 8.0),
      itemCount: products.length,
      itemBuilder: (context, index) {
        final product = products[index];
        final stockColor = product.stock <= 10 ? (product.stock == 0 ? Colors.red.shade700 : Colors.orange.shade800) : Colors.blue.shade800;
        final stockBackgroundColor = product.stock <= 10 ? (product.stock == 0 ? Colors.red.shade100 : Colors.orange.shade100) : Colors.blue.shade100;

        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            leading: SizedBox(
              width: 50,
              height: 50,
              child: (product.image != null && product.image!.isNotEmpty)
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(8.0),
                    child: Image.network(product.image!, fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => const Icon(Icons.broken_image, color: Colors.grey)),
                  )
                : Container(
                    decoration: BoxDecoration(
                      color: Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(8.0),
                    ),
                    child: const Icon(Icons.inventory_2_outlined, color: Colors.grey)
                  ),
            ),
            title: Text(product.name, style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('SKU: ${product.sku ?? '-'}'),
                Text('Harga Beli: ${currencyFormatter.format(product.purchasePrice)}'),
              ],
            ),
            trailing: Chip(
              label: Text('Stok: ${product.stock}'),
              labelStyle: TextStyle(color: stockColor, fontWeight: FontWeight.bold),
              backgroundColor: stockBackgroundColor,
              side: BorderSide(color: Color.alphaBlend(stockColor.withAlpha(128), stockBackgroundColor)),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            ),
            onTap: () {
              _showStockAdjustmentDialog(product);
            },
          ),
        );
      },
    );
  }
}
