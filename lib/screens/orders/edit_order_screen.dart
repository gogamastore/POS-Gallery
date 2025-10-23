import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ionicons/ionicons.dart';

import '../../models/order.dart';
import '../../models/order_item.dart';
import '../../models/product.dart';
import '../../providers/order_provider.dart';
import 'edit_order_item_dialog.dart';
import 'select_product_screen.dart';
import '../../utils/formatter.dart';

class EditOrderScreen extends ConsumerStatefulWidget {
  final Order order;

  const EditOrderScreen({super.key, required this.order});

  @override
  ConsumerState<EditOrderScreen> createState() => _EditOrderScreenState();
}

class _EditOrderScreenState extends ConsumerState<EditOrderScreen> {
  final List<OrderItem> _items = [];
  double _subtotal = 0.0;
  double _total = 0.0;

  @override
  void initState() {
    super.initState();
    for (var p in widget.order.products) {
      _items.add(OrderItem(
        productId: p['productId'] as String,
        name: p['name'] as String,
        quantity: p['quantity'] as int,
        price: (p['price'] as num).toDouble(),
        imageUrl: p['image'] as String?,
        sku: p['sku'] as String?,
      ));
    }
    _subtotal = widget.order.subtotal;
    _total = widget.order.total;
  }

  void _updateTotals() {
    double newSubtotal = 0;
    for (var item in _items) {
      newSubtotal += item.price * item.quantity;
    }
    setState(() {
      _subtotal = newSubtotal;
      _total = newSubtotal;
    });
  }

  void _addOrUpdateProduct(Product product) {
    final existingIndex =
        _items.indexWhere((item) => item.productId == product.id);

    if (existingIndex != -1) {
      setState(() {
        final existingItem = _items[existingIndex];
        _items[existingIndex] =
            existingItem.copyWith(quantity: existingItem.quantity + 1);
      });
    } else {
      setState(() {
        _items.add(OrderItem(
          productId: product.id,
          name: product.name,
          quantity: 1,
          price: product.price,
          imageUrl: product.image,
          sku: product.sku,
        ));
      });
    }
    _updateTotals();
  }

  void _editItem(OrderItem item) {
    // --- PERBAIKAN TOTAL: Menyesuaikan dengan konstruktor dialog yang benar ---
    showDialog(
      context: context,
      builder: (context) {
        return EditOrderItemDialog(
          item: item, // Mengirim OrderItem
          onUpdate: (newQuantity, newPrice) { // Menggunakan callback onUpdate
            setState(() {
              final index = _items.indexOf(item);
              if (index != -1) {
                _items[index] = item.copyWith(quantity: newQuantity, price: newPrice);
                _updateTotals();
              }
            });
          },
        );
      },
    );
  }

  void _removeItem(OrderItem item) {
    setState(() {
      _items.remove(item);
      _updateTotals();
    });
  }

  Future<void> _saveOrder() async {
    if (!mounted) return;
    if (_items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tidak ada produk dalam pesanan.')),
      );
      return;
    }

    try {
      await ref.read(orderActionsProvider.notifier).updateOrderDetails(
            widget.order.id!,
            _items,
            _subtotal,
            _total,
          );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pesanan berhasil diperbarui!')),
      );
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal menyimpan pesanan: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Edit Pesanan #${widget.order.id?.substring(0, 8) ?? '...'}'),
        actions: [
          IconButton(
            icon: const Icon(Ionicons.checkmark_done_outline),
            onPressed: _saveOrder,
            tooltip: 'Simpan Perubahan',
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _items.isEmpty
                ? const Center(
                    child: Text('Tidak ada produk. Tambahkan produk di bawah.'),
                  )
                : ListView.builder(
                    itemCount: _items.length,
                    itemBuilder: (context, index) {
                      final item = _items[index];
                      return _buildProductTile(item);
                    },
                  ),
          ),
          _buildSummary(),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Ionicons.add_outline),
        label: const Text('Tambah Produk'),
        onPressed: () async {
          final selectedProduct = await Navigator.of(context).push<Product>(
            MaterialPageRoute(
              builder: (context) => const SelectProductScreen(),
            ),
          );
          if (selectedProduct != null) {
            _addOrUpdateProduct(selectedProduct);
          }
        },
      ),
    );
  }

  Widget _buildProductTile(OrderItem item) {
    return ListTile(
      leading: item.imageUrl != null && item.imageUrl!.isNotEmpty
          ? CachedNetworkImage(
              imageUrl: item.imageUrl!,
              width: 50,
              height: 50,
              fit: BoxFit.cover,
              placeholder: (context, url) =>
                  const CircularProgressIndicator(),
              errorWidget: (context, url, error) =>
                  const Icon(Ionicons.image_outline),
            )
          : const Icon(Ionicons.cube_outline, size: 40),
      title: Text(item.name),
      subtitle: Text('${item.quantity} x ${formatCurrency(item.price)}'),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Ionicons.create_outline),
            onPressed: () => _editItem(item),
          ),
          IconButton(
            icon: const Icon(Ionicons.trash_outline, color: Colors.red),
            onPressed: () => _removeItem(item),
          ),
        ],
      ),
    );
  }

  Widget _buildSummary() {
    return Card(
      margin: const EdgeInsets.all(8.0),
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Ringkasan',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const Divider(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Subtotal'),
                Text(formatCurrency(_subtotal)),
              ],
            ),
            const SizedBox(height: 8),
            const Divider(),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Total', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                Text(
                  formatCurrency(_total),
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
