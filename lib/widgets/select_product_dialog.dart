import 'package:flutter/material.dart';
import 'package:myapp/models/product.dart';

class SelectProductDialog extends StatefulWidget {
  final List<Product> products;
  final Function(Product) onProductSelected;

  const SelectProductDialog({
    super.key,
    required this.products,
    required this.onProductSelected,
  });

  @override
  State<SelectProductDialog> createState() => _SelectProductDialogState();
}

class _SelectProductDialogState extends State<SelectProductDialog> {
  late List<Product> _filteredProducts;

  @override
  void initState() {
    super.initState();
    _filteredProducts = widget.products;
  }

  void _filterProducts(String query) {
    setState(() {
      _filteredProducts = widget.products
          .where((product) =>
              product.name.toLowerCase().contains(query.toLowerCase()))
          .toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Pilih Produk'),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              onChanged: _filterProducts,
              decoration: const InputDecoration(
                labelText: 'Cari produk...',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              autofocus: true,
            ),
            const SizedBox(height: 16),
            Expanded(
              child: _filteredProducts.isEmpty
                  ? const Center(child: Text('Produk tidak ditemukan.'))
                  : ListView.builder(
                      shrinkWrap: true,
                      itemCount: _filteredProducts.length,
                      itemBuilder: (context, index) {
                        final product = _filteredProducts[index];
                        return ListTile(
                          title: Text(product.name),
                          onTap: () {
                            widget.onProductSelected(product);
                            Navigator.of(context).pop();
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
          onPressed: () {
            Navigator.of(context).pop();
          },
          child: const Text('Batal'),
        ),
      ],
    );
  }
}
