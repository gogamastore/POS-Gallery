import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:ionicons/ionicons.dart';
import 'package:myapp/models/product.dart';
import 'package:myapp/models/purchase_cart_item.dart';
import 'package:myapp/providers/product_provider.dart';

class AddPurchaseItemDialog extends ConsumerStatefulWidget {
  const AddPurchaseItemDialog({super.key});

  @override
  ConsumerState<AddPurchaseItemDialog> createState() =>
      _AddPurchaseItemDialogState();
}

class _AddPurchaseItemDialogState extends ConsumerState<AddPurchaseItemDialog> {
  Product? _selectedProduct;
  final _quantityController = TextEditingController();
  final _priceController = TextEditingController();
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text;
      });
    });
  }

  void _onProductSelected(Product product) {
    setState(() {
      _selectedProduct = product;
      final formattedPrice = NumberFormat.currency(
        locale: 'id_ID',
        symbol: '',
        decimalDigits: 0,
      ).format(product.price);
      _priceController.text = formattedPrice.replaceAll('.', '');
    });
  }

  void _saveItem() {
    if (_selectedProduct == null ||
        _quantityController.text.isEmpty ||
        _priceController.text.isEmpty) {
      return;
    }

    final quantity = int.tryParse(_quantityController.text);
    final price = double.tryParse(_priceController.text.replaceAll('.', ''));

    if (quantity == null || price == null) return;

    final newItem = PurchaseCartItem(
      product: _selectedProduct!,
      quantity: quantity,
      purchasePrice: price,
    );

    Navigator.of(context).pop(newItem);
  }

  Widget _buildProductSearchView() {
    final productsAsyncValue = ref.watch(allProductsProvider);

    return productsAsyncValue.when(
      data: (products) {
        final filteredProducts = products
            .where((p) =>
                p.name.toLowerCase().contains(_searchQuery.toLowerCase()))
            .toList();

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: TextField(
                controller: _searchController,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: 'Cari Produk',
                  prefixIcon: const Icon(Ionicons.search_outline),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: filteredProducts.length,
                itemBuilder: (context, index) {
                  final product = filteredProducts[index];
                  return ListTile(
                    title: Text(product.name),
                    subtitle: Text('Stok: ${product.stock}'),
                    onTap: () => _onProductSelected(product),
                  );
                },
              ),
            ),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, s) => Center(child: Text('Gagal memuat produk: $e')),
    );
  }

  Widget _buildItemDetailView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(
                icon: const Icon(Ionicons.arrow_back_outline),
                onPressed: () => setState(() => _selectedProduct = null),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  _selectedProduct!.name,
                  style: Theme.of(context).textTheme.titleLarge,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          TextFormField(
            controller: _quantityController,
            autofocus: true,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Jumlah Barang',
              border: OutlineInputBorder(),
            ),
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _priceController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Harga Beli per Barang',
              prefixText: 'Rp ',
              border: OutlineInputBorder(),
            ),
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
             onChanged: (value) {
              String digitsOnly = value.replaceAll(RegExp(r'\D'), '');
              if (digitsOnly.isNotEmpty) {
                  final formatter = NumberFormat('#,###', 'id_ID');
                  String formatted = formatter.format(int.parse(digitsOnly));
                  
                  final newText = formatted;
                  _priceController.value = TextEditingValue(
                      text: newText,
                      selection: TextSelection.collapsed(offset: newText.length),
                  );
              }
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 500, maxWidth: 500),
        child: Column(
          children: [
            Expanded(
              child: _selectedProduct == null
                  ? _buildProductSearchView()
                  : _buildItemDetailView(),
            ),
            if (_selectedProduct != null)
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Batal'),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: _saveItem,
                      child: const Text('Simpan Barang'),
                    ),
                  ],
                ),
              )
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _quantityController.dispose();
    _priceController.dispose();
    _searchController.dispose();
    super.dispose();
  }
}
