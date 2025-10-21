import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:ionicons/ionicons.dart';
import '../models/product.dart';
import '../providers/product_provider.dart';
import '../utils/formatter.dart';

class ProductSelectionDialog extends ConsumerStatefulWidget {
  final Function(Product) onProductSelect;

  const ProductSelectionDialog({super.key, required this.onProductSelect});

  @override
  ConsumerState<ProductSelectionDialog> createState() => _ProductSelectionDialogState();
}

class _ProductSelectionDialogState extends ConsumerState<ProductSelectionDialog> {
  String _searchTerm = '';

  @override
  Widget build(BuildContext context) {
    final productsAsync = ref.watch(allProductsProvider);

    return AlertDialog(
      title: const Text('Pilih Produk'),
      contentPadding: const EdgeInsets.symmetric(horizontal: 0, vertical: 20),
      content: SizedBox(
        width: double.maxFinite,
        height: MediaQuery.of(context).size.height * 0.7,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              child: TextField(
                onChanged: (value) => setState(() => _searchTerm = value),
                decoration: const InputDecoration(
                  labelText: 'Cari nama atau SKU produk...',
                  prefixIcon: Icon(Ionicons.search_outline),
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: productsAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (err, stack) => Center(child: Text('Error: $err')),
                data: (products) {
                  final filteredProducts = products.where((p) {
                    final searchTermLower = _searchTerm.toLowerCase();
                    final nameMatch = p.name.toLowerCase().contains(searchTermLower);
                    final skuMatch = (p.sku ?? '').toLowerCase().contains(searchTermLower);
                    return nameMatch || skuMatch;
                  }).toList();

                  if (filteredProducts.isEmpty) {
                    return const Center(child: Text('Produk tidak ditemukan.'));
                  }

                  return ListView.builder(
                    itemCount: filteredProducts.length,
                    itemBuilder: (context, index) {
                      final product = filteredProducts[index];
                      return ListTile(
                        leading: ClipRRect(
                          borderRadius: BorderRadius.circular(8.0),
                          child: CachedNetworkImage(
                            imageUrl: product.image ?? '', 
                            width: 50,
                            height: 50,
                            fit: BoxFit.cover,
                            errorWidget: (c, u, e) => const Icon(Icons.error),
                          ),
                        ),
                        title: Text(product.name),
                        subtitle: Text('SKU: ${product.sku ?? '-'}'),
                        // THE REAL FIX: Pass the double directly.
                        trailing: Text(formatCurrency(product.price)),
                        onTap: () {
                          widget.onProductSelect(product);
                          Navigator.of(context).pop();
                        },
                      );
                    },
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
          child: const Text('Batal'),
        ),
      ],
    );
  }
}
