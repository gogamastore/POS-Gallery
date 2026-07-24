import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/order_item.dart';
import 'scanner_screen.dart';
import 'marketplace_validation_summary_screen.dart';

/// Validasi pesanan marketplace non-kurir (COD / Ambil di Tempat) — meniru
/// alur `pos_validation_screen` gogama_office, tapi dibuat mandiri (state
/// lokal, tanpa pos cart provider) dan memakai struktur dokumen `orders` kita.
///
/// Karena `orders.products[]` marketplace TIDAK menyimpan `sku`, SKU tiap
/// produk diambil dari koleksi `products` (via productId) agar bisa discan.
class MarketplaceOrderValidationScreen extends StatefulWidget {
  final String orderId;
  final List<Map<String, dynamic>> products;
  final double shippingFee;
  final String paymentStatus;

  const MarketplaceOrderValidationScreen({
    super.key,
    required this.orderId,
    required this.products,
    required this.shippingFee,
    required this.paymentStatus,
  });

  @override
  State<MarketplaceOrderValidationScreen> createState() =>
      _MarketplaceOrderValidationScreenState();
}

class _MarketplaceOrderValidationScreenState
    extends State<MarketplaceOrderValidationScreen> {
  final _manualController = TextEditingController();
  final _currency =
      NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);

  // Produk pesanan yang belum divalidasi & yang sudah (key = productId).
  final Map<String, OrderItem> _unvalidated = {};
  final Map<String, OrderItem> _validated = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadSkus();
  }

  @override
  void dispose() {
    _manualController.dispose();
    super.dispose();
  }

  /// Bangun daftar item + ambil SKU tiap produk dari koleksi `products`.
  Future<void> _loadSkus() async {
    final db = FirebaseFirestore.instance;
    for (final p in widget.products) {
      final productId = p['productId'] as String? ?? '';
      if (productId.isEmpty) continue;
      String? sku;
      try {
        final snap = await db.collection('products').doc(productId).get();
        sku = snap.data()?['sku'] as String?;
      } catch (_) {
        sku = null;
      }
      _unvalidated[productId] = OrderItem(
        productId: productId,
        name: p['name'] as String? ?? '',
        quantity: (p['quantity'] as num?)?.toInt() ?? 0,
        price: (p['price'] as num?)?.toDouble() ?? 0,
        imageUrl: (p['imageUrl'] as String?) ?? (p['image'] as String?),
        sku: sku,
      );
    }
    if (mounted) setState(() => _loading = false);
  }

  void _snack(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: error ? Colors.orange : Colors.green,
    ));
  }

  /// Validasi berdasarkan SKU (dari scan / input manual).
  void _validateBySku(String sku) {
    final trimmed = sku.trim();
    if (trimmed.isEmpty) return;
    OrderItem? match;
    for (final item in _unvalidated.values) {
      if ((item.sku ?? '').toLowerCase() == trimmed.toLowerCase()) {
        match = item;
        break;
      }
    }
    if (match == null) {
      _snack('SKU tidak ada dalam pesanan ini atau sudah divalidasi.',
          error: true);
      return;
    }
    _validateItem(match);
    _manualController.clear();
  }

  /// Pindahkan item ke "sudah divalidasi" (dengan opsi ubah qty).
  Future<void> _validateItem(OrderItem item) async {
    final result = await _showQtyDialog(item);
    if (result == null) return;
    setState(() {
      _unvalidated.remove(item.productId);
      _validated[item.productId] = result;
    });
  }

  Future<void> _scan() async {
    final value = await Navigator.of(context)
        .push<String>(MaterialPageRoute(builder: (_) => const ScannerScreen()));
    if (value != null && value.isNotEmpty) _validateBySku(value);
  }

  /// Dialog konfirmasi / ubah jumlah saat memvalidasi produk.
  Future<OrderItem?> _showQtyDialog(OrderItem item) {
    int qty = item.quantity;
    return showDialog<OrderItem>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialog) => AlertDialog(
          title: Text(item.name, maxLines: 2, overflow: TextOverflow.ellipsis),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('SKU: ${item.sku ?? '-'}',
                  style: const TextStyle(color: Colors.grey)),
              const SizedBox(height: 16),
              const Text('Jumlah tervalidasi'),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton.filledTonal(
                    onPressed: qty > 1
                        ? () => setDialog(() => qty--)
                        : null,
                    icon: const Icon(Icons.remove),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Text('$qty',
                        style: const TextStyle(
                            fontSize: 22, fontWeight: FontWeight.bold)),
                  ),
                  IconButton.filledTonal(
                    onPressed: () => setDialog(() => qty++),
                    icon: const Icon(Icons.add),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Batal')),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, item.copyWith(quantity: qty)),
              child: const Text('Validasi'),
            ),
          ],
        ),
      ),
    );
  }

  void _openSummary() {
    if (_validated.isEmpty) {
      _snack('Belum ada produk yang divalidasi.', error: true);
      return;
    }
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => MarketplaceValidationSummaryScreen(
        orderId: widget.orderId,
        validatedItems: _validated.values.toList(),
        shippingFee: widget.shippingFee,
        paymentStatus: widget.paymentStatus,
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final navigator = Navigator.of(context);
        final leave = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Keluar Validasi?'),
            content: const Text(
                'Progres validasi yang belum dikonfirmasi akan hilang.'),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Batal')),
              TextButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('Ya, Keluar')),
            ],
          ),
        );
        if (leave == true && mounted) navigator.pop();
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Validasi Pesanan'),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(36),
            child: Container(
              width: double.infinity,
              color: Colors.grey.shade200,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text('${_validated.length} item divalidasi',
                  style: const TextStyle(
                      color: Colors.green, fontWeight: FontWeight.bold)),
            ),
          ),
        ),
        bottomNavigationBar: BottomAppBar(
          child: FilledButton.icon(
            onPressed: _openSummary,
            icon: const Icon(Icons.shopping_cart_checkout),
            label: const Text('Lihat Ringkasan Validasi'),
          ),
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  _buildInput(),
                  const Divider(height: 1),
                  Expanded(child: _buildList()),
                ],
              ),
      ),
    );
  }

  Widget _buildInput() {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _manualController,
              decoration: const InputDecoration(
                labelText: 'Input atau Pindai SKU',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.qr_code),
              ),
              onSubmitted: _validateBySku,
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            height: 56,
            child: FilledButton.icon(
              onPressed: _scan,
              icon: const Icon(Icons.qr_code_scanner),
              label: const Text('Pindai'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildList() {
    return ListView(
      children: [
        _header('Belum Divalidasi (${_unvalidated.length})',
            Icons.inventory_2_outlined, Colors.orange),
        if (_unvalidated.isEmpty)
          const Padding(
            padding: EdgeInsets.all(16),
            child: Center(
                child: Text('Semua produk telah divalidasi.',
                    style: TextStyle(color: Colors.green))),
          )
        else
          ..._unvalidated.values.map((item) => ListTile(
                leading: CircleAvatar(child: Text('x${item.quantity}')),
                title: Text(item.name),
                subtitle: Text('SKU: ${item.sku ?? '-'}'),
                trailing: IconButton(
                  icon:
                      const Icon(Icons.arrow_circle_down, color: Colors.blue),
                  tooltip: 'Validasi manual',
                  onPressed: () => _validateItem(item),
                ),
              )),
        _header('Sudah Divalidasi (${_validated.length})',
            Icons.check_circle_outline, Colors.green),
        if (_validated.isEmpty)
          const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: Text('Pindai produk untuk memulai.')),
          )
        else
          ..._validated.values.map((item) => ListTile(
                leading: CircleAvatar(
                    backgroundColor: Colors.green,
                    child: Text('x${item.quantity}',
                        style: const TextStyle(color: Colors.white))),
                title: Text(item.name),
                subtitle: Text(
                    '${_currency.format(item.price)} × ${item.quantity}'),
                trailing: Text(_currency.format(item.price * item.quantity),
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                onTap: () => _reEdit(item),
              )),
        const SizedBox(height: 12),
      ],
    );
  }

  /// Ubah kembali item yang sudah divalidasi (atau batalkan validasinya).
  Future<void> _reEdit(OrderItem item) async {
    final result = await _showQtyDialog(item);
    if (result == null) return;
    setState(() => _validated[item.productId] = result);
  }

  Widget _header(String title, IconData icon, Color color) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
        child: Row(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 8),
            Text(title,
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: color)),
          ],
        ),
      );
}
