import 'dart:developer' as developer;

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../models/order.dart';
import '../../models/order_item.dart';
import '../../widgets/pos_scanned_item_tile.dart';
import 'scanner_screen.dart';
import 'validated_order_summary_screen.dart';

class PosValidationScreen extends ConsumerStatefulWidget {
  final Order order;
  const PosValidationScreen({super.key, required this.order});

  @override
  ConsumerState<PosValidationScreen> createState() => _PosValidationScreenState();
}

class _PosValidationScreenState extends ConsumerState<PosValidationScreen> {
  final Map<String, OrderItem> _validatedProducts = {};
  final Map<String, int> _confirmedQuantities = {};
  late List<OrderItem> _unscannedProducts;
  
  final TextEditingController _manualInputController = TextEditingController();
  final AudioPlayer _audioPlayer = AudioPlayer();

  @override
  void initState() {
    super.initState();
    _unscannedProducts = widget.order.products.map((p) => OrderItem(
      productId: p.productId,
      name: p.name,
      price: p.price,
      quantity: p.quantity,
      sku: p.sku,
      imageUrl: p.imageUrl,
    )).toList();
  }

  @override
  void dispose() {
    _manualInputController.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  void _findAndAddProduct(String sku) {
    final productInOrder = _unscannedProducts.where((p) => p.sku == sku).firstOrNull;

    if (productInOrder != null) {
      setState(() {
        _unscannedProducts.removeWhere((p) => p.sku == sku);
        _validatedProducts[sku] = productInOrder;
        if (!_confirmedQuantities.containsKey(sku)) {
          _confirmedQuantities[sku] = productInOrder.quantity;
        }
      });
      _manualInputController.clear();
      _playSound('sounds/success.mp3');
      _showQuantityDialog(productInOrder);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('SKU tidak ditemukan atau sudah divalidasi.'), backgroundColor: Colors.orange),
      );
      _playSound('sounds/error.mp3'); // THE FIX: Use the robust play sound method
    }
  }

  // Robust method to play sound and handle errors
  Future<void> _playSound(String soundPath) async {
    try {
      await _audioPlayer.play(AssetSource(soundPath));
    } catch (e, stackTrace) {
      developer.log(
        'Gagal memainkan suara: $soundPath',
        name: 'PosValidationScreen',
        error: e,
        stackTrace: stackTrace,
      );
      // Optional: Show a snackbar if sound fails, but don't pop the screen.
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal memutar efek suara: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _navigateToScanner() async {
    try {
      if (!mounted) return;
      final scannedValue = await Navigator.of(context).push<String>(
        MaterialPageRoute(builder: (context) => const ScannerScreen()),
      );
      if (scannedValue != null && scannedValue.isNotEmpty) {
        _findAndAddProduct(scannedValue);
      }
    } catch (e) {
      developer.log('Error saat navigasi ke pemindai: $e');
       if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal membuka pemindai: $e')));
    }
  }

  void _showQuantityDialog(OrderItem product) {
    int currentQty = _confirmedQuantities[product.sku] ?? product.quantity;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(product.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('SKU: ${product.sku}'),
                  const SizedBox(height: 16),
                  Text('Jumlah Pesanan: ${product.quantity}', style: TextStyle(fontSize: 14, color: Colors.grey.shade600)),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.remove_circle, size: 40, color: Colors.redAccent),
                        onPressed: () {
                          if (currentQty > 0) {
                            setDialogState(() => currentQty--);
                          }
                        },
                      ),
                      Text('$currentQty', style: const TextStyle(fontSize: 36, fontWeight: FontWeight.bold)),
                      IconButton(
                        icon: const Icon(Icons.add_circle, size: 40, color: Colors.green),
                        onPressed: () {
                          if (currentQty < product.quantity) {
                            setDialogState(() => currentQty++);
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                              content: Text('Jumlah tidak boleh melebihi pesanan.'),
                              backgroundColor: Colors.orange,
                            ));
                          }
                        },
                      ),
                    ],
                  ),
                ],
              ),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Batal')),
            ElevatedButton(
              onPressed: () {
                setState(() => _confirmedQuantities[product.sku!] = currentQty);
                Navigator.of(ctx).pop();
              },
              child: const Text('Proses'),
            ),
          ],
        ),
      ),
    );
  }

 void _navigateToSummary() {
     final List<OrderItem> validatedItems = [];
    _confirmedQuantities.forEach((sku, confirmedQty) {
      if (confirmedQty > 0) {
        final originalProduct = _validatedProducts[sku]!;
        validatedItems.add(OrderItem(
          productId: originalProduct.productId,
          name: originalProduct.name,
          price: originalProduct.price,
          quantity: confirmedQty,
          sku: originalProduct.sku,
          imageUrl: originalProduct.imageUrl,
        ));
      }
    });
    if (validatedItems.isEmpty) {
      showDialog(context: context, builder: (ctx) => AlertDialog(
          title: const Text('Belum Ada Produk'),
          content: const Text('Anda harus memvalidasi & memproses setidaknya satu produk.'),
          actions: [TextButton(child: const Text('OK'), onPressed: () => Navigator.of(ctx).pop())],
        ),
      );
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => ValidatedOrderSummaryScreen(
          originalOrder: widget.order,
          validatedItems: validatedItems,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currencyFormatter = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
    final validatedProductList = _validatedProducts.values.toList();

    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) {
        if (didPop) return;
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Konfirmasi Keluar'),
            content: const Text('Apakah Anda yakin ingin keluar dari halaman ini?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(), // Tutup dialog
                child: const Text('Batal'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop(); // Tutup dialog
                  Navigator.of(context).pop(); // Keluar dari halaman
                },
                child: const Text('Ya, Keluar'),
              ),
            ],
          ),
        );
      },
      child: Scaffold(
        appBar: AppBar(title: const Text('Validasi Pesanan POS')),
        body: Column(
          children: [
            _buildInputSection(),
            const Divider(height: 1),
            Expanded(
              child: Column(
                children: [
                  _buildSectionHeader('Produk Pesanan (${_unscannedProducts.length})'),
                  Expanded(
                    child: _unscannedProducts.isEmpty
                        ? const Center(child: Text('Semua produk sudah divalidasi!', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)))
                        : ListView.builder(
                            itemCount: _unscannedProducts.length,
                            itemBuilder: (context, index) {
                              final product = _unscannedProducts[index];
                              return ListTile(
                                leading: CircleAvatar(child: Text('${product.quantity}')),
                                title: Text(product.name),
                                subtitle: Text('SKU: ${product.sku}'),
                              );
                            },
                          ),
                  ),
                  const Divider(thickness: 4),
                  _buildSectionHeader('Keranjang Validasi (${validatedProductList.length})'),
                  Expanded(
                    child: validatedProductList.isEmpty
                        ? const Center(child: Text('Pindai atau input SKU untuk memulai...', style: TextStyle(fontSize: 16, color: Colors.grey)))
                        : ListView.builder(
                            itemCount: validatedProductList.length,
                            itemBuilder: (context, index) {
                              final product = validatedProductList[index];
                              final confirmedQty = _confirmedQuantities[product.sku] ?? 0;
                              return PosScannedItemTile(
                                name: product.name,
                                sku: product.sku,
                                price: product.price,
                                originalQuantity: product.quantity,
                                validatedQuantity: confirmedQty,
                                onTap: () => _showQuantityDialog(product),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
            _buildSummary(currencyFormatter),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
      child: Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blueAccent)),
    );
  }

  Widget _buildInputSection() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _manualInputController,
              decoration: const InputDecoration(labelText: 'Input atau Pindai SKU', border: OutlineInputBorder()),
              onSubmitted: (value) => (value.isNotEmpty) ? _findAndAddProduct(value) : null,
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            height: 55,
            child: ElevatedButton.icon(
              onPressed: _navigateToScanner,
              icon: const Icon(Icons.qr_code_scanner),
              label: const Text('Pindai'),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildSummary(NumberFormat currencyFormatter) {
    double totalValidatedPrice = 0;
    _confirmedQuantities.forEach((sku, qty) {
      if (qty > 0) {
        totalValidatedPrice += (_validatedProducts[sku]!.price * qty);
      }
    });

    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        boxShadow: [BoxShadow(color: Colors.black.withAlpha(25), spreadRadius: 1, blurRadius: 5, offset: const Offset(0, -3))],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Total Validasi:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              Text(currencyFormatter.format(totalValidatedPrice), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.green)),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _navigateToSummary,
              style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
              child: const Text('Lanjutkan ke Ringkasan', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }
}
