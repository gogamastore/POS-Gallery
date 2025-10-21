import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:myapp/models/product.dart';
import 'package:myapp/models/trending_product.dart';
import 'package:cached_network_image/cached_network_image.dart';

import 'add_trending_product_dialog.dart';

class TrendingProductsScreen extends StatefulWidget {
  const TrendingProductsScreen({super.key});

  @override
  State<TrendingProductsScreen> createState() => _TrendingProductsScreenState();
}

class _TrendingProductsScreenState extends State<TrendingProductsScreen> {
  bool _isLoading = true;
  List<TrendingProduct> _trendingProducts = [];

  @override
  void initState() {
    super.initState();
    _fetchTrendingProducts();
  }

  Future<void> _fetchTrendingProducts() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      final trendingSnapshot = await FirebaseFirestore.instance
          .collection('trending_products')
          .orderBy('orderIndex', descending: false)
          .get();

      final trendingData = trendingSnapshot.docs
          .map((doc) {
            final data = doc.data();
            return {
              'trendingId': doc.id,
              'productId': data['productId'] as String?,
              'orderIndex': (data['orderIndex'] as num?)?.toInt() ?? 0,
            };
          })
          .where((data) => data['productId'] != null)
          .toList();

      if (trendingData.isEmpty) {
        if (mounted) {
          setState(() => _trendingProducts = []);
        }
        return;
      }

      final productFutures = trendingData.map((ref) async {
        final productDoc = await FirebaseFirestore.instance
            .collection('products')
            .doc(ref['productId'] as String)
            .get();

        if (productDoc.exists) {
          try {
            return TrendingProduct(
              trendingId: ref['trendingId'] as String,
              product: Product.fromFirestore(productDoc),
              orderIndex: ref['orderIndex'] as int,
            );
          } catch (e) {
            print(
                'Gagal parse produk dengan ID: ${ref['productId']}. Error: $e');
            return null;
          }
        }
        return null;
      }).toList();

      final resolvedProducts = (await Future.wait(productFutures))
          .whereType<TrendingProduct>()
          .toList();

      // Meskipun server sudah mengurutkan, `Future.wait` tidak menjamin urutan.
      // Sorting di sisi klien adalah jaring pengaman yang baik.
      resolvedProducts.sort((a, b) => a.orderIndex.compareTo(b.orderIndex));

      if (mounted) {
        setState(() => _trendingProducts = resolvedProducts);
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal memuat data: ${error.toString()}')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _handleDelete(String trendingId, String productName) async {
    setState(() {
      _trendingProducts.removeWhere((p) => p.trendingId == trendingId);
    });

    try {
      await FirebaseFirestore.instance
          .collection('trending_products')
          .doc(trendingId)
          .delete();
      await _updateAllOrderIndexes();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Produk "$productName" dihapus.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Gagal menghapus. Memuat ulang...')),
      );
      _fetchTrendingProducts();
    }
  }

  Future<void> _updateAllOrderIndexes() async {
    final batch = FirebaseFirestore.instance.batch();
    for (int i = 0; i < _trendingProducts.length; i++) {
      final product = _trendingProducts[i];
      product.orderIndex = i;
      final docRef = FirebaseFirestore.instance
          .collection('trending_products')
          .doc(product.trendingId);
      batch.update(docRef, {'orderIndex': i});
    }
    await batch.commit();
  }

  Future<void> _onReorder(int oldIndex, int newIndex) async {
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }
    final TrendingProduct item = _trendingProducts.removeAt(oldIndex);
    _trendingProducts.insert(newIndex, item);

    setState(() {});
    await _updateAllOrderIndexes();
  }

  void _showDeleteConfirmation(TrendingProduct trendingProduct) {
    showDialog(
      context: context,
      builder: (BuildContext ctx) {
        return AlertDialog(
          title: const Text('Anda Yakin?'),
          content: Text(
              'Hapus "${trendingProduct.product.name}" dari daftar trending?'),
          actions: <Widget>[
            TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Batal')),
            TextButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                _handleDelete(
                    trendingProduct.trendingId, trendingProduct.product.name);
              },
              child:
                  const Text('Ya, Hapus', style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Atur Produk Trending'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _buildContent(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final newIndex = _trendingProducts.length;
          final result = await showDialog<bool>(
            context: context,
            builder: (context) =>
                AddTrendingProductDialog(nextOrderIndex: newIndex),
          );
          if (result == true) {
            _fetchTrendingProducts();
          }
        },
        label: const Text('Tambah Produk'),
        icon: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildContent() {
    if (_trendingProducts.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.style, size: 60, color: Colors.grey),
            SizedBox(height: 16),
            Text('Belum ada produk trending.',
                style: TextStyle(fontSize: 16, color: Colors.grey)),
            SizedBox(height: 8),
            Text('Tekan tombol "+" untuk menambahkan.',
                style: TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }

    return ReorderableListView.builder(
      padding: const EdgeInsets.all(8.0),
      itemCount: _trendingProducts.length,
      itemBuilder: (context, index) {
        final item = _trendingProducts[index];
        return Card(
          key: ValueKey(item.trendingId),
          margin: const EdgeInsets.symmetric(vertical: 6.0),
          child: ListTile(
            leading: SizedBox(
              width: 56,
              height: 56,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8.0),
                child: item.product.image != null &&
                        item.product.image!.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: item.product.image!,
                        fit: BoxFit.cover,
                        placeholder: (c, u) => const Center(
                            child: CircularProgressIndicator(strokeWidth: 2.0)),
                        errorWidget: (c, u, e) => const Icon(Icons.error),
                      )
                    : Container(
                        color: Colors.grey[200],
                        child: const Icon(Icons.image_not_supported),
                      ),
              ),
            ),
            title: Text(item.product.name,
                style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text('SKU: ${item.product.sku ?? '-'}'),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  onPressed: () => _showDeleteConfirmation(item),
                ),
                ReorderableDragStartListener(
                  index: index,
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8.0),
                    child: Icon(Icons.drag_handle),
                  ),
                ),
              ],
            ),
          ),
        );
      },
      onReorder: _onReorder,
    );
  }
}
