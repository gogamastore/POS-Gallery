import 'package:cloud_firestore/cloud_firestore.dart' hide Order;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:ionicons/ionicons.dart';
import 'dart:io';
import 'dart:async';

import '../../models/order.dart';
import '../../models/order_item.dart';
import '../../models/product.dart';
import '../../providers/order_provider.dart';
import 'edit_order_item_dialog.dart';
import 'select_product_screen.dart';

class EditOrderScreen extends ConsumerStatefulWidget {
  final Order order;

  const EditOrderScreen({super.key, required this.order});

  @override
  ConsumerState<EditOrderScreen> createState() => _EditOrderScreenState();
}

class _EditOrderScreenState extends ConsumerState<EditOrderScreen> {
  late List<OrderItem> _items;
  late TextEditingController _shippingFeeController;
  double _subtotal = 0;
  double _total = 0;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _items = widget.order.products.map((p) {
      return OrderItem(
        productId: p.productId,
        name: p.name,
        quantity: p.quantity,
        price: p.price,
        imageUrl: p.imageUrl,
        sku: p.sku,
      );
    }).toList();

    _items.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

    _shippingFeeController = TextEditingController(
      text: (widget.order.shippingFee ?? 0).toStringAsFixed(0),
    );
    _calculateTotals();
  }

  @override
  void dispose() {
    _shippingFeeController.dispose();
    super.dispose();
  }

  void _calculateTotals() {
    _subtotal = _items.fold(
      0.0,
      (previousValue, item) => previousValue + (item.price * item.quantity),
    );
    final shippingFee = double.tryParse(_shippingFeeController.text) ?? 0.0;
    setState(() {
      _total = _subtotal + shippingFee;
    });
  }

  void _editItem(int index) async {
    final itemToEdit = _items[index];

    final productDoc = await FirebaseFirestore.instance
        .collection('products')
        .doc(itemToEdit.productId)
        .get();

    if (!mounted) return; // Guard against async gaps

    if (!productDoc.exists) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Produk tidak ditemukan. Mungkin telah dihapus.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final product = Product.fromFirestore(productDoc);
    final availableStock = product.stock;

    final updatedItem = await showDialog<OrderItem>(
      context: context,
      builder: (context) => EditOrderItemDialog(product: itemToEdit),
    );

    if (updatedItem != null) {
      if (updatedItem.quantity > availableStock) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  'Stok tidak cukup. Kuantitas melebihi stok yang tersedia ($availableStock).'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      } else {
        setState(() {
          _items[index] = updatedItem;
          _calculateTotals();
        });
      }
    }
  }

  void _removeProduct(int index) {
    final removedItem = _items[index];
    setState(() {
      _items.removeAt(index);
      _calculateTotals();
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${removedItem.name} dihapus'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _addProduct() async {
    final Product? selectedProduct = await Navigator.push<Product>(
      context,
      MaterialPageRoute(
        builder: (context) => const SelectProductScreen(),
      ),
    );

    if (selectedProduct != null) {
      setState(() {
        final existingItemIndex =
            _items.indexWhere((item) => item.productId == selectedProduct.id);

        if (existingItemIndex != -1) {
          final existingItem = _items[existingItemIndex];

          if (existingItem.quantity < selectedProduct.stock) {
            _items[existingItemIndex] = existingItem.copyWith(
              quantity: existingItem.quantity + 1,
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Jumlah pesanan sudah mencapai stok maksimal.'),
                backgroundColor: Colors.orange,
              ),
            );
          }
        } else {
          if (selectedProduct.stock > 0) {
            _items.add(OrderItem(
              productId: selectedProduct.id,
              name: selectedProduct.name,
              quantity: 1,
              price: selectedProduct.price,
              imageUrl: selectedProduct.image,
              sku: selectedProduct.sku,
            ));
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Produk ini kehabisan stok.'),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
        _items.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
        _calculateTotals();
      });
    }
  }

  Future<void> _saveChanges() async {
    if (_isSaving) return;
    setState(() => _isSaving = true);

    try {
      final success = await ref.read(orderProvider.notifier).updateOrder(
            widget.order.id,
            _items,
            double.tryParse(_shippingFeeController.text) ?? 0.0,
            _subtotal,
            _total,
          );

      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Pesanan berhasil diperbarui!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.of(context).pop();
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Gagal memperbarui pesanan. Silakan coba lagi.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } on SocketException {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Gagal menyimpan, koneksi internet error'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } on TimeoutException {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Gagal menyimpan, koneksi internet error'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } on FirebaseException {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Gagal menyimpan, unable to update database'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Terjadi error fungsional aplikasi: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Edit Pesanan #${widget.order.id.substring(0, 7)}...'),
        actions: [
          if (_isSaving)
            const Padding(
              padding: EdgeInsets.only(right: 16.0),
              child: Center(
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 3),
                ),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.check),
              onPressed: _items.isNotEmpty ? _saveChanges : null,
              tooltip: 'Simpan Perubahan',
            ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: ElevatedButton.icon(
              onPressed: _addProduct,
              icon: const Icon(Icons.add),
              label: const Text('Tambah Produk'),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          Expanded(
            child: _items.isEmpty ? _buildEmptyState() : _buildProductListView(),
          ),
          _buildTotalsSection(),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Ionicons.cart_outline, size: 80, color: Colors.grey),
          SizedBox(height: 16),
          Text(
            'Ketuk "Tambah Produk" untuk memulai.',
            style: TextStyle(fontSize: 18, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildProductListView() {
    return ListView.builder(
      padding: const EdgeInsets.all(8.0),
      itemCount: _items.length,
      itemBuilder: (context, index) {
        final item = _items[index];
        final currencyFormatter = NumberFormat.currency(
          locale: 'id_ID',
          symbol: 'Rp ',
          decimalDigits: 0,
        );
        return _OrderItemCard(
          item: item,
          currencyFormatter: currencyFormatter,
          onTap: () => _editItem(index),
          onRemove: () => _removeProduct(index),
        );
      },
    );
  }

  Widget _buildTotalsSection() {
    final formatter = NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    );
    return Material(
      elevation: 8,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          16,
          16,
          16,
          16 + MediaQuery.of(context).padding.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _shippingFeeController,
              decoration: InputDecoration(
                labelText: 'Biaya Pengiriman',
                prefixText: 'Rp ',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              keyboardType: TextInputType.number,
              onChanged: (value) => _calculateTotals(),
            ),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Subtotal Produk', style: TextStyle(fontSize: 14)),
                Text(
                  formatter.format(_subtotal),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            const Divider(),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Total Akhir',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                Text(
                  formatter.format(_total),
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).primaryColor,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _OrderItemCard extends ConsumerWidget {
  final OrderItem item;
  final NumberFormat currencyFormatter;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  const _OrderItemCard({
    required this.item,
    required this.currencyFormatter,
    required this.onTap,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Card(
        margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildProductImage(item.imageUrl),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${item.quantity} x ${currencyFormatter.format(item.price)}',
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.black54,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(
                      Ionicons.trash_outline,
                      color: Colors.redAccent,
                    ),
                    onPressed: onRemove,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    currencyFormatter.format(item.price * item.quantity),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProductImage(String? imageUrl) {
    if (imageUrl != null && imageUrl.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8.0),
        child: CachedNetworkImage(
          imageUrl: imageUrl,
          width: 60,
          height: 60,
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
      width: 60,
      height: 60,
      decoration: BoxDecoration(
        color: const Color(0xFFE0E6ED),
        borderRadius: BorderRadius.circular(8.0),
      ),
      child: const Icon(
        Ionicons.cube_outline,
        color: Color(0xFFBDC3C7),
        size: 30,
      ),
    );
  }
}
