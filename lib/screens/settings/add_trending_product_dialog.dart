
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:myapp/models/product.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';

class AddTrendingProductDialog extends StatefulWidget {
  // 1. Menerima index urutan berikutnya
  final int nextOrderIndex;
  const AddTrendingProductDialog({super.key, required this.nextOrderIndex});

  @override
  State<AddTrendingProductDialog> createState() => _AddTrendingProductDialogState();
}

class _AddTrendingProductDialogState extends State<AddTrendingProductDialog> {
  bool _isLoading = true;
  bool _isSubmitting = false;
  List<Product> _allProducts = [];
  List<Product> _filteredProducts = [];

  @override
  void initState() {
    super.initState();
    _fetchProducts();
  }

  String _formatCurrency(double value) {
    final format = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
    return format.format(value);
  }

  Future<void> _fetchProducts() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final productsSnapshot = await FirebaseFirestore.instance.collection('products').get();
      final productsData = productsSnapshot.docs.map((doc) => Product.fromFirestore(doc)).toList();
      if (!mounted) return;
      setState(() {
        _allProducts = productsData;
        _filteredProducts = productsData;
        _isLoading = false;
      });
    } catch (e) {
      if(mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Gagal memuat daftar produk.')),
        );
      }
    }
  }

  void _filterProducts(String searchTerm) {
    final lowercasedFilter = searchTerm.toLowerCase();
    setState(() {
      _filteredProducts = _allProducts.where((p) {
        final nameMatch = p.name.toLowerCase().contains(lowercasedFilter);
        final skuMatch = p.sku?.toLowerCase().contains(lowercasedFilter) ?? false;
        return nameMatch || skuMatch;
      }).toList();
    });
  }

  Future<void> _handleAddProduct(Product product) async {
    setState(() => _isSubmitting = true);
    try {
      final query = FirebaseFirestore.instance
          .collection('trending_products')
          .where('productId', isEqualTo: product.id);
      final existing = await query.get();

      if (!mounted) return;

      if (existing.docs.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Produk sudah ada di daftar trending.'), backgroundColor: Colors.amber),
        );
      } else {
        // 2. Menambahkan 'orderIndex' saat membuat dokumen baru
        await FirebaseFirestore.instance.collection('trending_products').add({
          'productId': product.id,
          'orderIndex': widget.nextOrderIndex, 
        });

        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Produk "${product.name}" berhasil ditambahkan.'), backgroundColor: Colors.green),
        );
        
        Navigator.of(context).pop(true); 
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Gagal menambahkan produk.')),
        );
      }
    } finally {
      if(mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Tambah Produk Trending'),
      content: SizedBox(
        width: double.maxFinite,
        height: MediaQuery.of(context).size.height * 0.7,
        child: Column(
          children: [
            TextField(
              onChanged: _filterProducts,
              decoration: const InputDecoration(
                labelText: 'Cari produk berdasarkan nama atau SKU...',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _filteredProducts.isEmpty
                    ? const Center(child: Text('Tidak ada produk yang cocok.'))
                    : ListView.builder(
                      itemCount: _filteredProducts.length,
                      itemBuilder: (context, index) {
                        final product = _filteredProducts[index];
                        return Card(
                          margin: const EdgeInsets.symmetric(vertical: 4.0),
                          child: ListTile(
                            leading: SizedBox(
                              width: 48,
                              height: 48,
                              child: ClipRRect(
                                  borderRadius: BorderRadius.circular(4.0),
                                  child: product.image != null && product.image!.isNotEmpty
                                      ? CachedNetworkImage(
                                          imageUrl: product.image!,
                                          fit: BoxFit.cover,
                                          placeholder: (c, u) => const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                                          errorWidget: (c, u, e) => const Icon(Icons.error),
                                      )
                                      : Container(color: Colors.grey[200], child: const Icon(Icons.image_not_supported)),
                              ),
                            ), 
                            title: Text(product.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                            subtitle: Text('SKU: ${product.sku ?? '-'} | ${_formatCurrency(product.price)}', maxLines: 1, overflow: TextOverflow.ellipsis),
                            trailing: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 12),
                              ),
                              onPressed: _isSubmitting ? null : () => _handleAddProduct(product),
                              child: _isSubmitting 
                                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) 
                                : const Text('Tambah'),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Tutup'),
        ),
      ],
    );
  }
}
