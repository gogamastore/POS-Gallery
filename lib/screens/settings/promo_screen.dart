import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:ionicons/ionicons.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../models/product.dart';
import '../../models/promotion_model.dart';
import '../../providers/promo_provider.dart';
import '../../utils/formatter.dart';
import '../../widgets/product_selection_dialog.dart';

class PromoScreen extends ConsumerWidget {
  const PromoScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final promoAsync = ref.watch(promoProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pengaturan Promo'),
      ),
      body: promoAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(
          child: Text('Gagal memuat data: $err'),
        ),
        data: (promotions) => promotions.isEmpty
            ? _buildEmptyState()
            : _buildPromoList(context, ref, promotions),
      ),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Ionicons.add),
        label: const Text('Tambah Promo'),
        onPressed: () => _showAddPromoDialog(context),
      ),
    );
  }

  Widget _buildEmptyState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Ionicons.pricetags_outline, size: 80, color: Colors.grey),
          SizedBox(height: 16),
          Text('Belum ada promo aktif.', style: TextStyle(fontSize: 18)),
        ],
      ),
    );
  }

  Widget _buildPromoList(BuildContext context, WidgetRef ref, List<Promotion> promotions) {
    return ListView.builder(
      padding: const EdgeInsets.all(8.0),
      itemCount: promotions.length,
      itemBuilder: (context, index) {
        final promo = promotions[index];
        final bool isExpired = DateTime.now().isAfter(promo.endDate);

        return Card(
          margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8.0),
                  child: CachedNetworkImage(
                    imageUrl: promo.product.image ?? '',
                    width: 70,
                    height: 70,
                    fit: BoxFit.cover,
                    errorWidget: (c, u, e) => const Icon(Icons.error, size: 40),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(promo.product.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Text(
                            // THE REAL FIX: Pass the double directly.
                            formatCurrency(promo.product.price),
                            style: const TextStyle(decoration: TextDecoration.lineThrough, color: Colors.grey, fontSize: 13),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            // THE REAL FIX: Pass the double directly.
                            formatCurrency(promo.discountPrice),
                            style: TextStyle(fontWeight: FontWeight.bold, color: Theme.of(context).primaryColor, fontSize: 15),
                          ),
                        ],
                      ),
                       const SizedBox(height: 4),
                       Text(
                        'Berlaku hingga: ${DateFormat('dd MMM yyyy').format(promo.endDate)}',
                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
                Column(
                  children: [
                     Chip(
                      label: Text(isExpired ? 'Berakhir' : 'Aktif', style: const TextStyle(color: Colors.white, fontSize: 10)),
                      backgroundColor: isExpired ? Colors.grey : Colors.green,
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                    ),
                    IconButton(
                      icon: const Icon(Ionicons.trash_outline, color: Colors.redAccent),
                      onPressed: () => _confirmDelete(context, ref, promo),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showAddPromoDialog(BuildContext context) {
    showDialog(
      context: context, 
      builder: (context) => const AddPromoDialog()
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref, Promotion promo) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Konfirmasi Hapus'),
        content: Text('Anda yakin ingin menghapus promo untuk produk "${promo.product.name}"?'),
        actions: [
          TextButton(child: const Text('Batal'), onPressed: () => Navigator.of(ctx).pop()),
          TextButton(
            child: const Text('Hapus', style: TextStyle(color: Colors.red)),
            onPressed: () async {
              if (!ctx.mounted) return;
              Navigator.of(ctx).pop();
              try {
                await ref.read(promoProvider.notifier).deletePromotion(promo.promoId);
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Promo berhasil dihapus.'), backgroundColor: Colors.green),
                );
              } catch (e) {
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Gagal menghapus: $e'), backgroundColor: Colors.red),
                );
              }
            },
          ),
        ],
      ),
    );
  }
}

class AddPromoDialog extends ConsumerStatefulWidget {
  const AddPromoDialog({super.key});

  @override
  ConsumerState<AddPromoDialog> createState() => _AddPromoDialogState();
}

class _AddPromoDialogState extends ConsumerState<AddPromoDialog> {
  final _formKey = GlobalKey<FormState>();
  Product? _selectedProduct;
  DateTimeRange? _selectedDateRange;
  final _discountPriceController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _selectedDateRange = DateTimeRange(start: DateTime.now(), end: DateTime.now().add(const Duration(days: 7)));
  }

  void _submit() async {
    if (_formKey.currentState!.validate()) {
      if (_selectedProduct == null) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Silakan pilih produk terlebih dahulu.'), backgroundColor: Colors.orange));
        return;
      }

      setState(() => _isSubmitting = true);

      try {
        await ref.read(promoProvider.notifier).addPromotion(
          productId: _selectedProduct!.id,
          discountPrice: double.parse(_discountPriceController.text),
          startDate: _selectedDateRange!.start,
          endDate: _selectedDateRange!.end,
        );
        
        if (!mounted) return;
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Promo berhasil ditambahkan.'), backgroundColor: Colors.green),
        );
      } catch (e) {
         if (!mounted) return;
         ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Gagal menambahkan promo: $e'), backgroundColor: Colors.red),
        );
      } finally {
         if(mounted) setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Tambah Promo Baru'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildProductSelector(),
              const SizedBox(height: 16),
              TextFormField(
                controller: _discountPriceController,
                decoration: const InputDecoration(labelText: 'Harga Diskon (Rp)', border: OutlineInputBorder()),
                keyboardType: TextInputType.number,
                validator: (val) => val == null || val.isEmpty ? 'Harga tidak boleh kosong' : null,
              ),
              const SizedBox(height: 16),
              _buildDateRangePicker(),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Batal')),
        ElevatedButton(
          onPressed: _isSubmitting ? null : _submit,
          child: _isSubmitting ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Simpan'),
        ),
      ],
    );
  }

  Widget _buildProductSelector() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(8)),
      child: Row(
        children: [
          if (_selectedProduct != null)
            Expanded(
              child: Row(
                children: [
                   ClipRRect(
                    borderRadius: BorderRadius.circular(4.0),
                    child: CachedNetworkImage(imageUrl: _selectedProduct!.image ?? '', width: 40, height: 40, fit: BoxFit.cover),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_selectedProduct!.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                        // THE REAL FIX: Pass the double directly.
                        Text(formatCurrency(_selectedProduct!.price), style: const TextStyle(fontSize: 12, color: Colors.grey)),
                      ],
                    ),
                  ),
                ],
              ),
            )
          else
            const Expanded(child: Text('Belum ada produk dipilih')),
          
          ElevatedButton(
            child: const Text('Pilih'),
            onPressed: () {
              showDialog(
                context: context,
                builder: (_) => ProductSelectionDialog(
                  onProductSelect: (product) => setState(() => _selectedProduct = product),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildDateRangePicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Periode Promo', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: () async {
            final range = await showDateRangePicker(
              context: context,
              firstDate: DateTime.now().subtract(const Duration(days: 30)),
              lastDate: DateTime.now().add(const Duration(days: 365)),
              initialDateRange: _selectedDateRange,
            );
            if (range != null) {
              setState(() => _selectedDateRange = range);
            }
          },
          child: Container(
             padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
             decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(8)),
             child: Row(
              children: [
                const Icon(Ionicons.calendar_outline, color: Colors.grey),
                const SizedBox(width: 10),
                Expanded(child: Text(
                  _selectedDateRange == null 
                  ? 'Pilih tanggal' 
                  : '${DateFormat('dd/MM/yy').format(_selectedDateRange!.start)} - ${DateFormat('dd/MM/yy').format(_selectedDateRange!.end)}'
                )),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
