import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:ionicons/ionicons.dart';

class CostCategory {
  final String id;
  final String name;
  final IconData icon;

  CostCategory({required this.id, required this.name, required this.icon});
}

final operationalCostCategories = [
  CostCategory(id: "supplies", name: "Pembelian Perlengkapan Usaha", icon: Ionicons.cube_outline),
  CostCategory(id: "electricity", name: "Pembayaran Listrik", icon: Ionicons.flash_outline),
  CostCategory(id: "salary", name: "Pembayaran Gaji Karyawan", icon: Ionicons.people_outline),
  CostCategory(id: "misc", name: "Biaya Lain-lain", icon: Ionicons.document_text_outline),
];

class CostItem {
  final String id;
  final String category;
  final double amount;
  final String description;

  CostItem({
    required this.id,
    required this.category,
    required this.amount,
    required this.description,
  });
}

final costCartProvider = StateProvider<List<CostItem>>((ref) => []);

class OperationalTransactionScreen extends ConsumerWidget {
  const OperationalTransactionScreen({super.key});

  String _formatCurrency(double amount) {
    final format = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
    return format.format(amount);
  }

  Future<void> _showAddCostDialog(BuildContext context, WidgetRef ref, CostCategory category) async {
    final amountController = TextEditingController();
    final descriptionController = TextEditingController();

    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Tambah Biaya: ${category.name}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: amountController,
                decoration: const InputDecoration(labelText: 'Total Harga'),
                keyboardType: TextInputType.number,
              ),
              TextField(
                controller: descriptionController,
                decoration: const InputDecoration(labelText: 'Keterangan'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              onPressed: () {
                final amount = double.tryParse(amountController.text) ?? 0;
                final description = descriptionController.text;
                if (amount > 0) {
                  final newItem = CostItem(
                    id: '${category.id}-${DateTime.now().millisecondsSinceEpoch}',
                    category: category.name,
                    amount: amount,
                    description: description,
                  );
                  ref.read(costCartProvider.notifier).update((state) => [...state, newItem]);
                  Navigator.of(context).pop();
                }
              },
              child: const Text('Simpan Biaya'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _saveTransaction(BuildContext context, WidgetRef ref) async {
    final cart = ref.read(costCartProvider);
    if (cart.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Rincian kosong.')));
      return;
    }

    final firestore = FirebaseFirestore.instance;
    final batch = firestore.batch();

    for (var item in cart) {
      final docRef = firestore.collection('operational_expenses').doc();
      batch.set(docRef, {
        'category': item.category,
        'amount': item.amount,
        'description': item.description,
        'date': FieldValue.serverTimestamp(),
      });
    }

    try {
      await batch.commit();
      if (!context.mounted) return;
      ref.read(costCartProvider.notifier).state = [];
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Transaksi berhasil disimpan.')));
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal menyimpan transaksi: $e')));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cart = ref.watch(costCartProvider);
    final totalCost = cart.fold<double>(0, (total, item) => total + item.amount);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Transaksi Biaya Operasional'),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth > 600) {
            return Row(
              children: [
                Expanded(
                  flex: 2,
                  child: _buildCategoryList(context, ref),
                ),
                Expanded(
                  flex: 1,
                  child: _buildCart(context, ref, cart, totalCost),
                ),
              ],
            );
          } else {
            return Column(
              children: [
                Expanded(
                  flex: 2,
                  child: _buildCategoryList(context, ref),
                ),
                Expanded(
                  flex: 1,
                  child: _buildCart(context, ref, cart, totalCost),
                ),
              ],
            );
          }
        },
      ),
    );
  }

  Widget _buildCategoryList(BuildContext context, WidgetRef ref) {
    return ListView.builder(
      itemCount: operationalCostCategories.length,
      itemBuilder: (context, index) {
        final category = operationalCostCategories[index];
        return ListTile(
          leading: Icon(category.icon),
          title: Text(category.name),
          trailing: ElevatedButton(
            onPressed: () => _showAddCostDialog(context, ref, category),
            child: const Text('Tambah'),
          ),
        );
      },
    );
  }

  Widget _buildCart(BuildContext context, WidgetRef ref, List<CostItem> cart, double totalCost) {
    return Card(
      margin: const EdgeInsets.all(8.0),
      child: Column(
        children: [
          ListTile(
            title: const Text('Rincian Biaya'),
            trailing: IconButton(
              icon: const Icon(Ionicons.trash_outline),
              onPressed: () => ref.read(costCartProvider.notifier).state = [],
            ),
          ),
          Expanded(
            child: cart.isEmpty
                ? const Center(child: Text('Belum ada biaya'))
                : ListView.builder(
                    itemCount: cart.length,
                    itemBuilder: (context, index) {
                      final item = cart[index];
                      return ListTile(
                        title: Text(item.category),
                        subtitle: Text(item.description),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(_formatCurrency(item.amount)),
                            IconButton(
                              icon: const Icon(Ionicons.close_circle_outline, color: Colors.red),
                              onPressed: () {
                                ref.read(costCartProvider.notifier).update((state) => state.where((i) => i.id != item.id).toList());
                              },
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
          const Divider(),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Total Biaya', style: TextStyle(fontWeight: FontWeight.bold)),
                    Text(_formatCurrency(totalCost), style: const TextStyle(fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: cart.isEmpty ? null : () => _saveTransaction(context, ref),
                  child: const Text('Simpan Transaksi Biaya'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
