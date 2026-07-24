import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ionicons/ionicons.dart';

import '../../providers/product_provider.dart';
import '../../services/sound_service.dart';
import '../products/barcode_scanner_screen.dart';

class SelectProductScreen extends ConsumerStatefulWidget {
  const SelectProductScreen({super.key});

  @override
  ConsumerState<SelectProductScreen> createState() =>
      _SelectProductScreenState();
}

class _SelectProductScreenState extends ConsumerState<SelectProductScreen> {
  final TextEditingController _searchController = TextEditingController();
  late final SoundService _soundService;

  @override
  void initState() {
    super.initState();
    _soundService = SoundService();
    // Listener untuk memicu rebuild saat teks pencarian berubah
    _searchController.addListener(() {
      if (mounted) {
        setState(() {});
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
    final sku = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (context) => const BarcodeScannerScreen()),
    );
    if (sku != null && mounted) {
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
        title: const Text('Pilih Produk'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                labelText: 'Cari Produk atau Pindai Barcode',
                prefixIcon: const Icon(Ionicons.search),
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
          Expanded(
            child: productsAsyncValue.when(
              data: (products) {
                final searchQuery = _searchController.text.toLowerCase();
                final filteredProducts = products.where((product) {
                  final nameLower = product.name.toLowerCase();
                  final skuLower = product.sku?.toLowerCase() ?? '';
                  return nameLower.contains(searchQuery) ||
                      skuLower.contains(searchQuery);
                }).toList();

                if (filteredProducts.isEmpty) {
                  return Center(
                      child: Text(_searchController.text.isEmpty
                          ? 'Mulai ketik untuk mencari produk.'
                          : 'Tidak ada produk yang cocok.'));
                }

                return ListView.builder(
                  itemCount: filteredProducts.length,
                  itemBuilder: (context, index) {
                    final product = filteredProducts[index];
                    return ListTile(
                      leading: _buildProductImage(product.image),
                      title: Text(product.name),
                      subtitle: Text('Stok: ${product.stock}'),
                      onTap: () {
                        // Kembalikan produk yang dipilih ke layar sebelumnya
                        Navigator.of(context).pop(product);
                      },
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stackTrace) =>
                  Center(child: Text('Gagal memuat produk: $error')),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductImage(String? imageUrl) {
    if (imageUrl != null && imageUrl.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8.0),
        child: CachedNetworkImage(
          imageUrl: imageUrl,
          width: 50,
          height: 50,
          fit: BoxFit.cover,
          placeholder: (context, url) => _buildImagePlaceholder(),
          errorWidget: (context, url, error) => _buildImagePlaceholder(),
        ),
      );
    } else {
      return _buildImagePlaceholder();
    }
  }

  Widget _buildImagePlaceholder() {
    return Container(
      width: 50,
      height: 50,
      decoration: BoxDecoration(
        color: const Color(0xFFE0E6ED),
        borderRadius: BorderRadius.circular(8.0),
      ),
      child: const Icon(
        Ionicons.cube_outline,
        color: Color(0xFFBDC3C7),
        size: 24,
      ),
    );
  }
}
