
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:ionicons/ionicons.dart';

import '../../models/cash_drawer_shift.dart';
import '../../models/pos_cart_item.dart';
import '../../models/product.dart';
import '../../models/promotion_model.dart';
import '../../models/user_model.dart';
import '../../providers/pos_provider.dart';
import '../../providers/product_provider.dart';
import '../../providers/promo_provider.dart';
import '../../providers/shift_provider.dart';
import '../../services/sound_service.dart';
import '../products/barcode_scanner_screen.dart';
import 'add_temporary_product_dialog.dart';
import 'add_to_pos_cart_dialog.dart';
import 'edit_pos_cart_item_dialog.dart';
import 'pos_cart_screen.dart';

class PosScreen extends ConsumerStatefulWidget {
  const PosScreen({super.key});

  @override
  PosScreenState createState() => PosScreenState();
}

class PosScreenState extends ConsumerState<PosScreen> {
  final TextEditingController _searchController = TextEditingController();
  late final SoundService _soundService;

  @override
  void initState() {
    super.initState();
    _soundService = SoundService();
    _searchController.addListener(() {
      if (mounted) {
        setState(() {});
      }
    });
    // Dihapus: fetchActiveShift sudah dipanggil di konstruktor ShiftNotifier
    // WidgetsBinding.instance.addPostFrameCallback((_) {
    //   ref.read(shiftProvider.notifier).fetchActiveShift();
    // });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _soundService.dispose();
    super.dispose();
  }

  void _showStartShiftDialog() {
    final shiftNotifier = ref.read(shiftProvider.notifier);
    final formKey = GlobalKey<FormState>();
    UserModel? selectedCashier;
    final startingCashController = TextEditingController();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        // Gunakan Consumer untuk akses ref di dalam dialog
        return Consumer(builder: (context, ref, child) {
          return AlertDialog(
            title: const Text('Mulai Shift Baru'),
            content: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Gunakan cashiersProvider yang baru
                  ref.watch(cashiersProvider).when(
                        data: (cashiers) {
                          if (cashiers.isEmpty) {
                             return const Text('Tidak ada user Admin yang ditemukan.');
                          }
                          return DropdownButtonFormField<UserModel>(
                            decoration: const InputDecoration(
                                labelText: 'Pilih Kasir Aktif'),
                            items: cashiers.map((user) {
                              return DropdownMenuItem<UserModel>(
                                value: user,
                                child: Text(user.name),
                              );
                            }).toList(),
                            onChanged: (value) => selectedCashier = value,
                            validator: (value) =>
                                value == null ? 'Kasir harus dipilih' : null,
                          );
                        },
                        loading: () =>
                            const Center(child: CircularProgressIndicator()),
                        error: (error, stack) =>
                            Center(child: Text('Error: $error')),
                      ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: startingCashController,
                    decoration: const InputDecoration(
                        labelText: 'Modal Awal / Cash Drawer Awal'),
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Modal awal harus diisi';
                      }
                      return null;
                    },
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                child: const Text('Batal'),
                onPressed: () => Navigator.of(dialogContext).pop(),
              ),
              ElevatedButton(
                child: const Text('Mulai'),
                onPressed: () async {
                  if (formKey.currentState!.validate() && selectedCashier != null) {
                    final startingCash =
                        double.tryParse(startingCashController.text) ?? 0.0;
                    final success = await shiftNotifier.startShift(
                      selectedCashier!.uid,
                      selectedCashier!.name,
                      startingCash,
                    );
                    if (success && mounted) {
                      Navigator.of(dialogContext).pop();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text('Shift berhasil dimulai.')),
                      );
                    }
                  } else {
                     ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Silakan pilih kasir terlebih dahulu.')),
                    );
                  }
                },
              ),
            ],
          );
        });
      },
    );
  }

  // ... (Sisa kode dari PosScreenState tetap sama)

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

  void _showAddToCartDialog(Product product, Promotion? activePromo) {
    showDialog(
      context: context,
      builder: (context) => ProviderScope(
        parent: ProviderScope.containerOf(context),
        child: AddToPosCartDialog(product: product, activePromo: activePromo),
      ),
    );
  }

  void _showAddTemporaryProductDialog() {
    showDialog(
      context: context,
      builder: (context) => ProviderScope(
        parent: ProviderScope.containerOf(context),
        child: const AddTemporaryProductDialog(),
      ),
    );
  }

  void _showEditCartItemDialog(PosCartItem item) {
    showDialog(
      context: context,
      builder: (context) => ProviderScope(
        parent: ProviderScope.containerOf(context),
        child: EditPosCartItemDialog(cartItem: item),
      ),
    );
  }

  void _showEndShiftDialog(ShiftState shiftState) {
    final shiftNotifier = ref.read(shiftProvider.notifier);
    final shift = shiftState.activeShift!;
    final formKey = GlobalKey<FormState>();
    final countedCashController = TextEditingController();
    final qrisTransferController = TextEditingController();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text('Akhiri Shift'),
            content: SingleChildScrollView(
              child: Form(
                key: formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Nama Kasir: ${shift.cashierName}'),
                    const SizedBox(height: 8),
                    Text(
                        'Modal Awal: ${NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ').format(shift.startingCash)}'),
                    const Divider(height: 24),
                    _buildFutureCalculation(shiftNotifier, shift),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: countedCashController,
                      decoration: const InputDecoration(
                          labelText: 'Uang Tunai'),
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      onChanged: (value) => setDialogState(() {}),
                      validator: (value) =>
                          value == null || value.isEmpty ? 'Wajib diisi' : null,
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: qrisTransferController,
                      decoration:
                          const InputDecoration(labelText: 'QRIS / Transfer'),
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      onChanged: (value) => setDialogState(() {}),
                      validator: (value) =>
                          value == null || value.isEmpty ? 'Wajib diisi' : null,
                    ),
                    const Divider(height: 24),
                    _buildDeclaredIncome(
                        countedCashController, qrisTransferController),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                child: const Text('Batal'),
                onPressed: () => Navigator.of(dialogContext).pop(),
              ),
              ElevatedButton(
                child: const Text('Simpan'),
                onPressed: () async {
                  if (formKey.currentState!.validate()) {
                    final countedCash =
                        double.tryParse(countedCashController.text) ?? 0;
                    final qrisTransfer =
                        double.tryParse(qrisTransferController.text) ?? 0;
                    final success =
                        await shiftNotifier.endShift(countedCash, qrisTransfer);
                    if (success && mounted) {
                      Navigator.of(dialogContext).pop();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text('Shift berhasil diakhiri.')),
                      );
                    }
                  }
                },
              ),
            ],
          );
        });
      },
    );
  }

  Widget _buildDeclaredIncome(
      TextEditingController cash, TextEditingController qris) {
    final double countedCash = double.tryParse(cash.text) ?? 0;
    final double qrisTransfer = double.tryParse(qris.text) ?? 0;
    final total = countedCash + qrisTransfer;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text('Pendapatan Kasir:',
            style: TextStyle(fontWeight: FontWeight.bold)),
        Text(
          NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ').format(total),
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
      ],
    );
  }

  Widget _buildFutureCalculation(
      ShiftNotifier shiftNotifier, CashDrawerShift shift) {
    return FutureBuilder<Map<String, double>>(
      future: shiftNotifier.calculateShiftSummary(shift),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Text('Error: ${snapshot.error}');
        }

        final data = snapshot.data ?? {};
        final totalSales = data['totalSales'] ?? 0;
        final totalExpenses = data['totalExpenses'] ?? 0;
        final endingCash = data['endingCash'] ?? 0;

        final currencyFormat =
            NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ');

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              const Text('Total Penjualan:'),
              Text(currencyFormat.format(totalSales))
            ]),
            const SizedBox(height: 8),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              const Text('Total Pengeluaran:'),
              Text(currencyFormat.format(totalExpenses))
            ]),
            const SizedBox(height: 8),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              const Text('Modal Akhir:',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              Text(currencyFormat.format(endingCash),
                  style: const TextStyle(fontWeight: FontWeight.bold))
            ]),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final cartItemCount = ref.watch(posCartProvider).length;
    final shiftState = ref.watch(shiftProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text('Point of Sale'),
        backgroundColor: Colors.white,
        elevation: 1,
        actions: [
          if (shiftState.isLoading)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.0),
              child: Center(
                  child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2))),
            )
          else
            TextButton.icon(
              icon: Icon(shiftState.isShiftActive
                  ? Icons.stop_circle_outlined
                  : Icons.play_circle_outline),
              label: Text(
                  shiftState.isShiftActive ? 'Akhiri Shift' : 'Mulai Shift'),
              onPressed: () {
                if (shiftState.isShiftActive) {
                  _showEndShiftDialog(shiftState);
                } else {
                  _showStartShiftDialog();
                }
              },
              style: TextButton.styleFrom(
                foregroundColor:
                    shiftState.isShiftActive ? Colors.redAccent : Colors.green,
              ),
            ),
          IconButton(
            icon: const Icon(Ionicons.add_circle_outline),
            onPressed: _showAddTemporaryProductDialog,
            tooltip: 'Tambah Produk Non-Katalog',
          ),
          const SizedBox(width: 8),
        ],
      ),
      bottomNavigationBar: cartItemCount > 0
          ? _buildCartBottomBar(context, cartItemCount)
          : null,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth > 1000) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 2,
                      child: _ProductList(
                        searchController: _searchController,
                        onProductTapped: _showAddToCartDialog,
                        navigateToScanner: _navigateToScanner,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(flex: 1, child: _buildPosCartSideBar()),
                  ],
                );
              } else {
                return _ProductList(
                  searchController: _searchController,
                  onProductTapped: _showAddToCartDialog,
                  navigateToScanner: _navigateToScanner,
                );
              }
            },
          ),
        ),
      ),
    );
  }

  Widget _buildPosCartSideBar() {
    final cartItems = ref.watch(posCartProvider);
    final total = ref.watch(posTotalProvider);
    final currencyFormatter =
        NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);

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
                const Text('Keranjang Penjualan',
                    style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2C3E50))),
                IconButton(
                  icon: const Icon(Icons.delete_sweep_outlined,
                      color: Colors.redAccent),
                  onPressed: cartItems.isNotEmpty
                      ? () => ref.read(posCartProvider.notifier).clearCart()
                      : null,
                  tooltip: 'Kosongkan Keranjang',
                ),
              ],
            ),
            const SizedBox(height: 4),
            const Text('Daftar produk yang akan dijual.',
                style: TextStyle(fontSize: 14, color: Color(0xFF7F8C8D))),
            const Divider(height: 32),
            Expanded(
              child: cartItems.isEmpty
                  ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.shopping_cart_outlined,
                              size: 60, color: Color(0xFFBDC3C7)),
                          SizedBox(height: 16),
                          Text('Keranjang masih kosong',
                              style: TextStyle(color: Color(0xFF7F8C8D)))
                        ],
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
              children: [
                const Text('Total',
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                Text(currencyFormatter.format(total),
                    style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.green))
              ],
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: cartItems.isNotEmpty
                  ? () {
                      Navigator.of(context).push(MaterialPageRoute(
                          builder: (context) => const PosCartScreen()));
                    }
                  : null,
              icon: const Icon(Icons.arrow_forward),
              label: const Text('Lanjutkan'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: const Color(0xFF27AE60),
                foregroundColor: Colors.white,
                textStyle:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                disabledBackgroundColor: Colors.grey,
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildCartItemTile(PosCartItem item, NumberFormat currencyFormatter) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(item.product.name,
          style: const TextStyle(fontWeight: FontWeight.w500)),
      subtitle:
          Text('${item.quantity} x ${currencyFormatter.format(item.PosPrice)}'),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(currencyFormatter.format(item.subtotal),
              style: const TextStyle(fontWeight: FontWeight.bold)),
          IconButton(
              icon: const Icon(Icons.edit, size: 18, color: Colors.blueAccent),
              onPressed: () => _showEditCartItemDialog(item)),
          IconButton(
              icon: const Icon(Icons.delete, size: 18, color: Colors.redAccent),
              onPressed: () => ref
                  .read(posCartProvider.notifier)
                  .removeItem(item.product.id)),
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
            Text('$cartItemCount item di keranjang',
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
            ElevatedButton.icon(
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (context) => const PosCartScreen())),
              icon: const Icon(Icons.shopping_cart_checkout),
              label: const Text('Lihat Keranjang'),
              style: ElevatedButton.styleFrom(
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20))),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProductList extends ConsumerWidget {
  final TextEditingController searchController;
  final Function(Product, Promotion?) onProductTapped;
  final VoidCallback navigateToScanner;

  const _ProductList({
    required this.searchController,
    required this.onProductTapped,
    required this.navigateToScanner,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final productsAsync = ref.watch(allProductsProvider);
    final promosAsync = ref.watch(promoProvider);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 16.0),
          child: TextField(
            controller: searchController,
            decoration: InputDecoration(
              hintText: 'Cari nama atau pindai SKU...',
              prefixIcon: const Icon(Icons.search, color: Color(0xFF7F8C8D)),
              suffixIcon: IconButton(
                icon: const Icon(Ionicons.barcode_outline),
                onPressed: navigateToScanner,
                tooltip: 'Pindai Barcode',
              ),
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              filled: true,
              fillColor: Colors.white,
            ),
          ),
        ),
        Expanded(
          child: productsAsync.when(
            data: (products) {
              return promosAsync.when(
                data: (promotions) {
                  final filteredProducts = products.where((p) {
                    final query = searchController.text.toLowerCase();
                    if (query.isEmpty) return true;
                    return p.name.toLowerCase().contains(query) ||
                        (p.sku ?? '').toLowerCase().contains(query);
                  }).toList();

                  if (filteredProducts.isEmpty) {
                    return const Center(child: Text('Produk tidak ditemukan.'));
                  }

                  return GridView.builder(
                      gridDelegate:
                          const SliverGridDelegateWithMaxCrossAxisExtent(
                        maxCrossAxisExtent: 250,
                        childAspectRatio: 0.8,
                        mainAxisSpacing: 8,
                        crossAxisSpacing: 8,
                      ),
                      itemCount: filteredProducts.length,
                      itemBuilder: (context, index) {
                        final product = filteredProducts[index];
                        Promotion? activePromo;
                        try {
                          activePromo = promotions.firstWhere((promo) =>
                              promo.product.id == product.id &&
                              DateTime.now().isBefore(promo.endDate));
                        } catch (e) {
                          activePromo = null;
                        }
                        return _ProductListItem(
                          product: product,
                          activePromo: activePromo,
                          onTap: () => onProductTapped(product, activePromo),
                        );
                      });
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (err, stack) =>
                    Center(child: Text('Error memuat promo: $err')),
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, stack) =>
                Center(child: Text('Error memuat produk: $err')),
          ),
        ),
      ],
    );
  }
}

class _ProductListItem extends StatelessWidget {
  final Product product;
  final Promotion? activePromo;
  final VoidCallback onTap;

  const _ProductListItem({
    required this.product,
    this.activePromo,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final currencyFormatter =
        NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
    Widget priceWidget;

    if (activePromo != null) {
      priceWidget = Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            currencyFormatter.format(product.price),
            style: TextStyle(
              decoration: TextDecoration.lineThrough,
              color: Colors.grey[600],
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            currencyFormatter.format(activePromo!.discountPrice),
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: Colors.green,
            ),
          ),
        ],
      );
    } else {
      priceWidget = Text(
        currencyFormatter.format(product.price),
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.bold,
          color: Colors.green,
        ),
      );
    }

    return InkWell(
      onTap: onTap,
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Center(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8.0),
                    child: (product.image != null && product.image!.isNotEmpty)
                        ? Image.network(
                            product.image!,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) =>
                                const Icon(Icons.broken_image),
                          )
                        : Container(
                            color: const Color(0xFFE0E6ED),
                            child: const Icon(Icons.image_not_supported,
                                color: Color(0xFFBDC3C7)),
                          ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                product.name,
                style: const TextStyle(
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF2C3E50),
                  fontSize: 15,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Stok: ${product.stock}',
                      style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF3498DB),
                          fontWeight: FontWeight.w500)),
                  if (product.price > 0) priceWidget,
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
