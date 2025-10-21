import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../models/product.dart';
import '../../models/promotion_model.dart';
import '../../providers/product_provider.dart';
import '../../providers/promo_provider.dart';
import 'edit_product_screen.dart';
import 'purchase_history_dialog.dart';

class ProductDetailScreen extends ConsumerStatefulWidget {
  final Product product;

  const ProductDetailScreen({super.key, required this.product});

  @override
  ProductDetailScreenState createState() => ProductDetailScreenState();
}

class ProductDetailScreenState extends ConsumerState<ProductDetailScreen> {
  late Product _currentProduct;

  @override
  void initState() {
    super.initState();
    _currentProduct = widget.product;
  }

  void _navigateToEditScreen() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => EditProductScreen(product: _currentProduct),
      ),
    );
  }

  void _showPurchaseHistory() {
    showDialog(
      context: context,
      builder: (context) =>
          PurchaseHistoryDialog(productId: _currentProduct.id),
    );
  }

  Future<void> _deleteProduct() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Konfirmasi Hapus'),
        content: Text(
          'Apakah Anda yakin ingin menghapus produk "${_currentProduct.name}"?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Hapus', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await ref
            .read(productServiceProvider)
            .deleteProduct(_currentProduct.id);

        if (mounted) {
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('"${_currentProduct.name}" berhasil dihapus.'),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Gagal menghapus produk: $e')));
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currencyFormatter = NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    );
    
    final promosAsync = ref.watch(promoProvider);

    ref.listen(allProductsProvider, (_, state) {
      state.whenData((products) {
        try {
          final updatedProduct = products.firstWhere((p) => p.id == widget.product.id);
          if (_currentProduct != updatedProduct) {
            if (mounted) {
              setState(() {
                _currentProduct = updatedProduct;
              });
            }
          }
        } catch (e) {
          if (mounted) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (Navigator.of(context).canPop()) {
                Navigator.of(context).pop();
              }
            });
          }
        }
      });
    });

    return Scaffold(
      appBar: AppBar(
        title: Text(_currentProduct.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            tooltip: 'Edit Produk',
            onPressed: _navigateToEditScreen,
          ),
          IconButton(
            icon: const Icon(Icons.history),
            tooltip: 'Lihat Log Stok',
            onPressed: _showPurchaseHistory,
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: 'Hapus Produk',
            onPressed: _deleteProduct,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildImageSection(),
            const SizedBox(height: 24),
            _buildInfoSection(currencyFormatter, promosAsync),
            const Divider(height: 40, thickness: 1),
            _buildDescriptionSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildImageSection() {
    return Center(
      child: Hero(
        tag: 'product-image-${_currentProduct.id}',
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12.0),
          child:
              (_currentProduct.image != null &&
                  _currentProduct.image!.isNotEmpty)
              ? Image.network(
                  _currentProduct.image!,
                  fit: BoxFit.cover,
                  height: 250,
                  width: double.infinity,
                  errorBuilder: (context, error, stackTrace) =>
                      _buildImagePlaceholder(),
                )
              : _buildImagePlaceholder(),
        ),
      ),
    );
  }

  Widget _buildImagePlaceholder() {
    return Container(
      height: 250,
      width: double.infinity,
      color: const Color(0xFFE0E6ED),
      child: const Center(
        child: Icon(
          Icons.image_not_supported,
          color: Color(0xFFBDC3C7),
          size: 80,
        ),
      ),
    );
  }

  // --- PERUBAHAN TATA LETAK DI SINI ---
  Widget _buildInfoSection(NumberFormat currencyFormatter, AsyncValue<List<Promotion>> promosAsync) {
    final activePromo = promosAsync.whenData((promos) {
      try {
        return promos.firstWhere((p) => 
            p.product.id == _currentProduct.id && 
            DateTime.now().isBefore(p.endDate));
      } catch (e) {
        return null;
      }
    });

    Widget priceDisplayWidget;
    if (activePromo.asData?.value != null) {
      final promo = activePromo.asData!.value!;
      priceDisplayWidget = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Harga Promo',
              style: TextStyle(fontSize: 14, color: Color(0xFF7F8C8D)),
            ),
            const SizedBox(height: 4),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                 Text(
                  currencyFormatter.format(promo.discountPrice),
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2980B9),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  currencyFormatter.format(_currentProduct.price),
                  style: const TextStyle(
                    fontSize: 16, 
                    decoration: TextDecoration.lineThrough,
                    color: Color(0xFF95A5A6),
                  ),
                ),
              ],
            )
          ],
        );
    } else {
      priceDisplayWidget = _buildInfoTile(
        title: 'Harga Jual',
        value: currencyFormatter.format(_currentProduct.price),
        valueColor: const Color(0xFF2980B9),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _currentProduct.name,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Color(0xFF2C3E50),
          ),
        ),
        if (_currentProduct.sku != null && _currentProduct.sku!.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 4.0),
            child: Text(
              'SKU: ${_currentProduct.sku}',
              style: const TextStyle(fontSize: 16, color: Color(0xFF7F8C8D)),
            ),
          ),
        const SizedBox(height: 20),
        // Baris pertama: Harga Beli dan Stok
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildInfoTile(
              title: 'Harga Beli',
              value: currencyFormatter.format(_currentProduct.purchasePrice ?? 0.0),
            ),
            _buildInfoTile(
              title: 'Stok Saat Ini',
              value: _currentProduct.stock.toString(),
              valueColor: _currentProduct.stock > 10
                  ? const Color(0xFF27AE60)
                  : const Color(0xFFE74C3C),
              isRightAligned: true,
            ),
          ],
        ),
        const SizedBox(height: 20), 
        // Baris kedua: Harga Jual atau Promo
        priceDisplayWidget,
      ],
    );
  }

  Widget _buildInfoTile({
    required String title,
    required String value,
    Color? valueColor,
    bool isRightAligned = false,
  }) {
    return Column(
      crossAxisAlignment: isRightAligned
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 14, color: Color(0xFF7F8C8D)),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: valueColor ?? const Color(0xFF2C3E50),
          ),
        ),
      ],
    );
  }

  Widget _buildDescriptionSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Deskripsi',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Color(0xFF2C3E50),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          (_currentProduct.description != null &&
                  _currentProduct.description!.isNotEmpty)
              ? _currentProduct.description!
              : 'Tidak ada deskripsi untuk produk ini.',
          style: const TextStyle(
            fontSize: 16,
            color: Color(0xFF34495E),
            height: 1.5,
          ),
        ),
      ],
    );
  }
}
