import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:ionicons/ionicons.dart';

import '../../models/product.dart';
import '../../models/purchase_cart_item.dart';
import '../../providers/product_provider.dart';
import '../../providers/purchase_provider.dart';
import '../../services/sound_service.dart'; // DIPERBARUI: Impor SoundService
import '../products/barcode_scanner_screen.dart';
import 'add_to_purchase_cart_dialog.dart';
import 'edit_purchase_cart_item_dialog.dart';
import 'purchase_cart_screen.dart';

class PurchasesScreen extends ConsumerStatefulWidget {
  const PurchasesScreen({super.key});

  @override
  PurchasesScreenState createState() => PurchasesScreenState();
}

class PurchasesScreenState extends ConsumerState<PurchasesScreen> {
  final TextEditingController _searchController = TextEditingController();
  
  // DIPERBARUI: Buat instance SoundService
  late final SoundService _soundService;

  @override
  void initState() {
    super.initState();
    _soundService = SoundService(); // Inisialisasi SoundService

    _searchController.addListener(() {
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _soundService.dispose(); // DIPERBARUI: Hapus SoundService
    super.dispose();
  }

  // DIPERBARUI: Menggunakan SoundService untuk memutar suara
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

  void _showAddToCartDialog(Product product) {
    showDialog(
      context: context,
      builder: (context) => AddToPurchaseCartDialog(product: product),
    );
  }

  void _showEditCartItemDialog(PurchaseCartItem item) {
    showDialog(
      context: context,
      builder: (context) => EditPurchaseCartItemDialog(cartItem: item),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cartItemCount = ref.watch(purchaseCartProvider).length;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      bottomNavigationBar:
          cartItemCount > 0 ? _buildCartBottomBar(context, cartItemCount) : null,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth > 1000) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 2, child: _buildProductList()),
                    const SizedBox(width: 16),
                    Expanded(flex: 1, child: _buildPurchaseCartSideBar()),
                  ],
                );
              } else {
                return _buildProductList();
              }
            },
          ),
        ),
      ),
    );
  }

  Widget _buildProductList() {
    final productsAsync = ref.watch(allProductsProvider);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 16.0),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Cari nama atau pindai SKU...',
              prefixIcon: const Icon(Icons.search, color: Color(0xFF7F8C8D)),
              suffixIcon: IconButton(
                icon: const Icon(Ionicons.barcode_outline),
                onPressed: _navigateToScanner,
                tooltip: 'Pindai Barcode',
              ),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              filled: true,
              fillColor: Colors.white,
            ),
          ),
        ),
        Expanded(
          child: productsAsync.when(
            data: (products) {
              final filteredProducts = products.where((p) {
                final query = _searchController.text.toLowerCase();
                if (query.isEmpty) return true;
                return p.name.toLowerCase().contains(query) ||
                    (p.sku ?? '').toLowerCase().contains(query);
              }).toList();

              if (filteredProducts.isEmpty) {
                return const Center(child: Text('Produk tidak ditemukan.'));
              }

              return ListView.builder(
                padding: const EdgeInsets.only(top: 4),
                itemCount: filteredProducts.length,
                itemBuilder: (context, index) {
                  final product = filteredProducts[index];
                  return _buildProductItem(context, product);
                },
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, stack) => Center(child: Text('Error: $err')),
          ),
        ),
      ],
    );
  }

  Widget _buildProductItem(BuildContext context, Product product) {
    final currencyFormatter = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);

    return InkWell(
      onTap: () => _showAddToCartDialog(product),
      borderRadius: BorderRadius.circular(12),
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 0, vertical: 6),
        elevation: 1,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: Colors.grey.shade200, width: 1),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8.0),
                child: (product.image != null && product.image!.isNotEmpty)
                    ? Image.network(
                        product.image!,
                        width: 50,
                        height: 50,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => const Icon(Icons.broken_image),
                      )
                    : Container(
                        width: 50,
                        height: 50,
                        color: const Color(0xFFE0E6ED),
                        child: const Icon(Icons.image_not_supported, color: Color(0xFFBDC3C7)),
                      ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(product.name, style: const TextStyle(fontWeight: FontWeight.w500, color: Color(0xFF2C3E50), fontSize: 15), maxLines: 2, overflow: TextOverflow.ellipsis),
                    if (product.sku != null && product.sku!.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 2.0),
                        child: Text('SKU: ${product.sku}', style: const TextStyle(fontSize: 12, color: Color(0xFF7F8C8D))),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('Stok: ${product.stock}', style: const TextStyle(fontSize: 12, color: Color(0xFF3498DB), fontWeight: FontWeight.w500)),
                  const SizedBox(height: 4),
                  if (product.purchasePrice != null && product.purchasePrice! > 0)
                    Text(currencyFormatter.format(product.purchasePrice), style: const TextStyle(fontSize: 13, color: Color(0xFF7F8C8D))),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPurchaseCartSideBar() {
    final cartItems = ref.watch(purchaseCartProvider);
    final total = ref.watch(purchaseTotalProvider);
    final currencyFormatter = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Keranjang Pembelian', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF2C3E50))),
                IconButton(
                  icon: const Icon(Icons.delete_sweep_outlined, color: Colors.redAccent),
                  onPressed: cartItems.isNotEmpty ? () => ref.read(purchaseCartProvider.notifier).clearCart() : null,
                  tooltip: 'Kosongkan Keranjang',
                ),
              ],
            ),
            const SizedBox(height: 4),
            const Text('Daftar produk yang akan dibeli.', style: TextStyle(fontSize: 14, color: Color(0xFF7F8C8D))),
            const Divider(height: 32),
            Expanded(
              child: cartItems.isEmpty
                  ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [Icon(Icons.shopping_cart_outlined, size: 60, color: Color(0xFFBDC3C7)), SizedBox(height: 16), Text('Keranjang masih kosong', style: TextStyle(color: Color(0xFF7F8C8D)))],
                      ),
                    )
                  : ListView.builder(
                      itemCount: cartItems.length,
                      itemBuilder: (context, index) {
                        final item = cartItems[index];
                        return _buildCartItemTile(item, currencyFormatter);
                      },
                    ),
            ),
            const Divider(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [const Text('Total', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)), Text(currencyFormatter.format(total), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold))],
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: cartItems.isNotEmpty ? () {
                Navigator.of(context).push(MaterialPageRoute(builder: (context) => const PurchaseCartScreen()));
              } : null,
              icon: const Icon(Icons.arrow_forward),
              label: const Text('Lanjutkan'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: const Color(0xFF27AE60),
                foregroundColor: Colors.white,
                textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                disabledBackgroundColor: Colors.grey,
              ),
            )
          ],
        ),
      ),
    );
  }
  
  Widget _buildCartItemTile(PurchaseCartItem item, NumberFormat currencyFormatter) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(item.product.name, style: const TextStyle(fontWeight: FontWeight.w500)),
      subtitle: Text('${item.quantity} x ${currencyFormatter.format(item.purchasePrice)}'),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(currencyFormatter.format(item.subtotal), style: const TextStyle(fontWeight: FontWeight.bold)),
          IconButton(icon: const Icon(Icons.edit, size: 18, color: Colors.blueAccent), onPressed: () => _showEditCartItemDialog(item)),
          IconButton(icon: const Icon(Icons.delete, size: 18, color: Colors.redAccent), onPressed: () => ref.read(purchaseCartProvider.notifier).removeItem(item.product.id)),
        ],
      ),
    );
  }

  Widget _buildCartBottomBar(BuildContext context, int cartItemCount) {
    return BottomAppBar(
      height: 70,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('$cartItemCount item di keranjang', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
            ElevatedButton.icon(
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (context) => const PurchaseCartScreen())),
              icon: const Icon(Icons.shopping_cart_checkout),
              label: const Text('Lihat Keranjang'),
              style: ElevatedButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))),
            ),
          ],
        ),
      ),
    );
  }
}
