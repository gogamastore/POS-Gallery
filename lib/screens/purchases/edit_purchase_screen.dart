import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:ionicons/ionicons.dart';
import 'package:myapp/models/purchase_cart_item.dart';
import 'package:myapp/services/purchase_service.dart';
import 'package:myapp/widgets/purchases/add_purchase_item_dialog.dart';
import '../../models/purchase_transaction.dart';
import '../../providers/product_provider.dart';
import '../../providers/purchase_report_provider.dart';
import '../../providers/product_images_provider.dart';

final purchaseServiceProvider = Provider<PurchaseService>((ref) => PurchaseService());

class _EditableItem {
  final String productId;
  final String productName;
  int quantity;
  double purchasePrice;
  final String? imageUrl;

  _EditableItem({
    required this.productId,
    required this.productName,
    required this.quantity,
    required this.purchasePrice,
    this.imageUrl,
  });
}

class EditPurchaseScreen extends ConsumerStatefulWidget {
  final PurchaseTransaction transaction;

  const EditPurchaseScreen({super.key, required this.transaction});

  @override
  ConsumerState<EditPurchaseScreen> createState() => _EditPurchaseScreenState();
}

class _EditPurchaseScreenState extends ConsumerState<EditPurchaseScreen> {
  late List<_EditableItem> _items;
  late List<TextEditingController> _priceControllers;
  bool _isInitialized = false;
  bool _isSaving = false;
  final _currencyFormatter = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);

  @override
  void initState() {
    super.initState();
    _items = [];
    _priceControllers = [];
    _initializeItemsFromWidget();
  }

  void _initializeItemsFromWidget() {
    final productImages = ref.read(productImagesProvider).asData?.value ?? {};

    _items = widget.transaction.items.map((item) {
      return _EditableItem(
        productId: item.productId,
        productName: item.productName,
        quantity: item.quantity,
        purchasePrice: item.purchasePrice,
        imageUrl: productImages[item.productId],
      );
    }).toList();

    _priceControllers = _items.map((item) {
      final controller = TextEditingController(text: item.purchasePrice.toStringAsFixed(0));
      controller.addListener(() {
        final newPrice = double.tryParse(controller.text) ?? 0.0;
        if (item.purchasePrice != newPrice) {
           setState(() {
             item.purchasePrice = newPrice;
           });
        }
      });
      return controller;
    }).toList();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() {
          _isInitialized = true;
        });
      }
    });
  }
  
  @override
  void dispose() {
    for (var controller in _priceControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  // --- FUNGSI BARU UNTUK MENAMBAH ITEM ---
  Future<void> _addItem() async {
    final newItem = await showDialog<PurchaseCartItem>(
      context: context,
      builder: (context) => const AddPurchaseItemDialog(),
    );

    if (newItem != null && mounted) {
      final productImages = ref.read(productImagesProvider).asData?.value ?? {};
      setState(() {
        final newEditableItem = _EditableItem(
          productId: newItem.product.id,
          productName: newItem.product.name,
          quantity: newItem.quantity,
          purchasePrice: newItem.purchasePrice,
          imageUrl: productImages[newItem.product.id],
        );
        _items.add(newEditableItem);

        final newController = TextEditingController(text: newEditableItem.purchasePrice.toStringAsFixed(0));
        newController.addListener(() {
           final newPrice = double.tryParse(newController.text) ?? 0.0;
           if (newEditableItem.purchasePrice != newPrice) {
              setState(() {
                newEditableItem.purchasePrice = newPrice;
              });
           }
        });
        _priceControllers.add(newController);
      });
    }
  }

  void _updateQuantity(int index, int newQuantity) {
    if (newQuantity > 0) {
      setState(() {
        _items[index].quantity = newQuantity;
      });
    }
  }

  void _removeItem(int index) {
    setState(() {
      _items.removeAt(index);
      _priceControllers.removeAt(index).dispose();
    });
  }

  double get _totalBaru {
    if (!_isInitialized) return 0;
    return _items.fold(0, (total, item) => total + (item.quantity * item.purchasePrice));
  }

  Future<void> _saveChanges() async {
    if (!_isInitialized) return;

    setState(() {
      _isSaving = true;
    });

    try {
      final updatedItems = _items.map((item) {
        return {
          'productId': item.productId,
          'productName': item.productName,
          'quantity': item.quantity,
          'purchasePrice': item.purchasePrice,
          'subtotal': item.quantity * item.purchasePrice,
        };
      }).toList();

      final newTotalAmount = _totalBaru;

      await ref.read(purchaseServiceProvider).updatePurchaseTransaction(
            transactionId: widget.transaction.id,
            originalItems: widget.transaction.items,
            newItems: updatedItems,
            newTotalAmount: newTotalAmount,
          );

      ref.invalidate(purchaseTransactionsProvider);
      ref.invalidate(allProductsProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Transaksi berhasil diperbarui dan stok disesuaikan'),
              backgroundColor: Colors.green,
          ),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal menyimpan perubahan: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Edit Transaksi #${widget.transaction.id.substring(0, 7)}...'),
        // --- TOMBOL TAMBAH PRODUK ---
        actions: [
          IconButton(
            icon: const Icon(Ionicons.add_outline),
            onPressed: _addItem,
            tooltip: 'Tambah Produk',
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: !_isInitialized
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16.0),
                    itemCount: _items.length,
                    itemBuilder: (context, index) {
                      final item = _items[index];
                      final priceController = _priceControllers[index];
                      return _buildEditableItemCard(item, index, priceController);
                    },
                  ),
                ),
                _buildSummary(),
              ],
            ),
    );
  }

  Widget _buildEditableItemCard(_EditableItem item, int index, TextEditingController priceController) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12.0),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    item.imageUrl ?? '',
                    width: 60,
                    height: 60,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) =>
                        Container(width: 60, height: 60, color: Colors.grey[200], child: const Icon(Ionicons.image_outline, color: Colors.grey)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item.productName, style: const TextStyle(fontWeight: FontWeight.bold), maxLines: 2, overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 8),
                      SizedBox(
                        height: 40,
                        child: TextField(
                          controller: priceController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: const InputDecoration(
                            labelText: 'Harga Beli',
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(horizontal: 10),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Ionicons.trash_outline, color: Colors.redAccent),
                  onPressed: () => _removeItem(index),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Jumlah'),
                Row(
                  children: [
                    IconButton(icon: const Icon(Ionicons.remove_circle_outline), onPressed: () => _updateQuantity(index, item.quantity - 1)),
                    Text(item.quantity.toString(), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    IconButton(icon: const Icon(Ionicons.add_circle_outline), onPressed: () => _updateQuantity(index, item.quantity + 1)),
                  ],
                ),
                Text(
                  _currencyFormatter.format(item.quantity * item.purchasePrice),
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }

  Widget _buildSummary() {
    return Material(
      elevation: 8,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Total Baru:', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                Text(
                  _currencyFormatter.format(_totalBaru),
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.green),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
                    child: const Text('Batal'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isSaving ? null : _saveChanges,
                    style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12)),
                    child: _isSaving
                        ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Text('Simpan Perubahan'),
                  ),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }
}
