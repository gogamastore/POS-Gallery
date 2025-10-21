import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:ionicons/ionicons.dart';

import '../../models/app_user.dart';
import '../../models/order_item.dart';
import '../../models/order_product.dart';
import '../../models/product.dart';
import '../customers/customer_list_screen.dart';
import 'confirm_order_screen.dart';
import 'edit_order_item_dialog.dart';
import 'select_product_screen.dart';

class CreateOrderScreen extends ConsumerStatefulWidget {
  const CreateOrderScreen({super.key});

  @override
  ConsumerState<CreateOrderScreen> createState() => _CreateOrderScreenState();
}

class _CreateOrderScreenState extends ConsumerState<CreateOrderScreen> {
  final List<OrderItem> _items = [];
  AppUser? _selectedCustomer;

  double get _subtotal => _items.fold(
        0.0,
        (previousValue, item) => previousValue + (item.price * item.quantity),
      );

  void _editItem(int index) async {
    final itemToEdit = _items[index];

    final productDoc = await FirebaseFirestore.instance
        .collection('products')
        .doc(itemToEdit.productId)
        .get();

    if (!mounted) return;

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
                  'Stok tidak cukup. Sisa stok: $availableStock'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      } else {
        setState(() {
          _items[index] = updatedItem;
        });
      }
    }
  }

  void _removeProduct(int index) {
    final removedItem = _items[index];
    setState(() {
      _items.removeAt(index);
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
      });
    }
  }

  void _selectCustomer() async {
    final AppUser? selectedCustomer = await Navigator.push<AppUser>(
      context,
      MaterialPageRoute(
        builder: (context) => const CustomerListScreen(),
      ),
    );

    if (selectedCustomer != null) {
      setState(() {
        _selectedCustomer = selectedCustomer;
      });
    }
  }

  void _proceedToConfirmation() {
    if (_selectedCustomer == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Pilih customer terlebih dahulu.'),
            backgroundColor: Colors.red),
      );
      return;
    }

    final productsForOrder = _items
        .map((item) => OrderProduct(
              productId: item.productId,
              name: item.name,
              quantity: item.quantity,
              price: item.price,
              sku: item.sku,
              imageUrl: item.imageUrl,
            ))
        .toList();

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ConfirmOrderScreen(
          selectedCustomer: _selectedCustomer!,
          products: productsForOrder,
          subtotal: _subtotal,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Buat Pesanan Baru'),
        actions: [
          IconButton(
            icon: const Icon(Icons.arrow_forward_rounded),
            onPressed: _items.isNotEmpty && _selectedCustomer != null
                ? _proceedToConfirmation
                : null,
            tooltip: 'Lanjutkan ke Konfirmasi',
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: ElevatedButton.icon(
              onPressed: _selectCustomer,
              icon: const Icon(Icons.person_add_alt_1),
              label: Text(
                _selectedCustomer == null
                    ? 'Pilih Customer'
                    : 'Customer: ${_selectedCustomer!.name}',
              ),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: ElevatedButton.icon(
              onPressed: _addProduct,
              icon: const Icon(Icons.add_shopping_cart_rounded),
              label: const Text('Tambah Produk'),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
          const Divider(height: 1),
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
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Subtotal',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            Text(
              formatter.format(_subtotal),
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).primaryColor,
              ),
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
                      style:
                          const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${item.quantity} x ${currencyFormatter.format(item.price)}',
                      style: const TextStyle(
                          fontSize: 14,
                          color: Colors.black54,
                          fontWeight: FontWeight.w500),
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
                    icon: const Icon(Ionicons.trash_outline,
                        color: Colors.redAccent),
                    onPressed: onRemove,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    currencyFormatter.format(item.price * item.quantity),
                    style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue),
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
      child: const Icon(Ionicons.cube_outline, color: Color(0xFFBDC3C7), size: 30),
    );
  }
}
