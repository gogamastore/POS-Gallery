import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:ionicons/ionicons.dart';

import '../../models/supplier.dart';
import '../../providers/purchase_provider.dart';
import '../../providers/supplier_provider.dart';
import '../../services/purchase_service.dart';

class ProcessPurchaseScreen extends ConsumerStatefulWidget {
  const ProcessPurchaseScreen({super.key});

  @override
  ProcessPurchaseScreenState createState() => ProcessPurchaseScreenState();
}

class ProcessPurchaseScreenState extends ConsumerState<ProcessPurchaseScreen> {
  final _formKey = GlobalKey<FormState>();
  Supplier? _selectedSupplier;
  String _paymentMethod = 'cash';
  bool _isProcessing = false;

  Future<void> _showSupplierSelectionDialog() async {
    final selected = await showDialog<Supplier>(
      context: context,
      builder: (context) => const _SupplierSelectionDialog(),
    );

    if (selected != null) {
      setState(() {
        _selectedSupplier = selected;
      });
    }
  }

  Future<void> _processTransaction() async {
    if (!_formKey.currentState!.validate() || _isProcessing) {
      return;
    }

    final cartItems = ref.read(purchaseCartProvider);
    final totalAmount = ref.read(purchaseTotalProvider);
    final navigator = Navigator.of(context);
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    if (cartItems.isEmpty) {
      scaffoldMessenger.showSnackBar(
        const SnackBar(content: Text('Keranjang tidak boleh kosong!')),
      );
      return;
    }

    setState(() {
      _isProcessing = true;
    });

    try {
      await PurchaseService().processPurchaseTransaction(
        items: cartItems,
        totalAmount: totalAmount,
        paymentMethod: _paymentMethod,
        supplier: _selectedSupplier,
      );

      ref.read(purchaseCartProvider.notifier).clearCart();

      scaffoldMessenger.showSnackBar(
        const SnackBar(content: Text('Transaksi pembelian berhasil diproses dan disimpan!')),
      );
      
      navigator.pop();

    } catch (e) {
      scaffoldMessenger.showSnackBar(
        SnackBar(content: Text('Gagal memproses transaksi: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currencyFormatter = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text('Proses Pembelian', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
        backgroundColor: Colors.white,
        elevation: 1,
        foregroundColor: const Color(0xFF2C3E50),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: LayoutBuilder(
              builder: (context, constraints) {
                if (constraints.maxWidth > 800) {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 2, child: _buildDetailsSection()),
                      const SizedBox(width: 16),
                      Expanded(flex: 1, child: _buildSummarySection(currencyFormatter)),
                    ],
                  );
                } else {
                  return Column(
                    children: [
                      _buildDetailsSection(),
                      const SizedBox(height: 16),
                      _buildSummarySection(currencyFormatter),
                    ],
                  );
                }
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDetailsSection() {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('1. Detail Supplier & Pembayaran', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF2C3E50))),
            const Divider(height: 32),

            const Text('Supplier', style: TextStyle(fontWeight: FontWeight.w500)),
            const SizedBox(height: 8),
            InkWell(
              onTap: _showSupplierSelectionDialog,
              child: InputDecorator(
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  suffixIcon: Icon(Icons.arrow_drop_down),
                ),
                child: Text(
                  _selectedSupplier?.name ?? 'Pilih Supplier (Opsional)',
                  style: _selectedSupplier == null ? const TextStyle(color: Colors.black54) : null,
                ),
              ),
            ),
            const SizedBox(height: 24),

            const Text('Metode Pembayaran', style: TextStyle(fontWeight: FontWeight.w500)),
            const SizedBox(height: 8),
             RadioMenuButton<String>(
              value: 'cash',
              groupValue: _paymentMethod,
              onChanged: (String? value) {
                setState(() {
                  _paymentMethod = value!;
                });
              },
              child: const Text('Cash'),
            ),
            RadioMenuButton<String>(
              value: 'bank_transfer',
              groupValue: _paymentMethod,
              onChanged: (String? value) {
                setState(() {
                  _paymentMethod = value!;
                });
              },
              child: const Text('Bank Transfer'),
            ),
            RadioMenuButton<String>(
              value: 'credit',
              groupValue: _paymentMethod,
              onChanged: (String? value) {
                setState(() {
                  _paymentMethod = value!;
                });
              },
              child: const Text('Credit'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummarySection(NumberFormat currencyFormatter) {
    final cartItems = ref.watch(purchaseCartProvider);
    final totalAmount = ref.watch(purchaseTotalProvider);

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('2. Ringkasan Pembelian', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF2C3E50))),
            const Divider(height: 32),
            if (cartItems.isEmpty)
              const Center(child: Text('Keranjang kosong.'))
            else
              ...cartItems.map((item) => ListTile(
                    title: Text(item.product.name),
                    subtitle: Text('${item.quantity} x ${currencyFormatter.format(item.purchasePrice)}'),
                    trailing: Text(currencyFormatter.format(item.subtotal), style: const TextStyle(fontWeight: FontWeight.w500)),
                  )),
            const Divider(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Total Pembelian', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                Text(currencyFormatter.format(totalAmount), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF27AE60))),
              ],
            ),
            const SizedBox(height: 24),
            if (_isProcessing)
              const Center(child: CircularProgressIndicator())
            else
              ElevatedButton.icon(
                onPressed: cartItems.isNotEmpty ? _processTransaction : null,
                icon: const Icon(Icons.check_circle_outline),
                label: const Text('Konfirmasi & Simpan'),
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
}

// --- WIDGET DIALOG PEMILIHAN SUPPLIER ---
class _SupplierSelectionDialog extends ConsumerStatefulWidget {
  const _SupplierSelectionDialog();

  @override
  __SupplierSelectionDialogState createState() => __SupplierSelectionDialogState();
}

class __SupplierSelectionDialogState extends ConsumerState<_SupplierSelectionDialog> {
  String _searchQuery = '';

  Future<void> _showAddSupplierDialog() async {
    final newSupplier = await showDialog<Supplier>(
      context: context,
      // Barrier dismissible false agar user harus menyelesaikan atau membatalkan
      barrierDismissible: false, 
      builder: (context) => _AddSupplierDialog(initialName: _searchQuery),
    );

    if (newSupplier != null && mounted) {
      // Jika supplier baru berhasil dibuat, langsung pilih dan tutup dialog utama
      Navigator.of(context).pop(newSupplier);
    }
  }

  @override
  Widget build(BuildContext context) {
    final suppliersAsync = ref.watch(supplierProvider);

    return AlertDialog(
      title: const Text('Pilih Supplier'),
      contentPadding: const EdgeInsets.symmetric(vertical: 16.0),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: TextField(
                onChanged: (value) => setState(() => _searchQuery = value),
                decoration: const InputDecoration(
                  hintText: 'Cari nama supplier...',
                  prefixIcon: Icon(Ionicons.search),
                  border: OutlineInputBorder(),
                ),
                autofocus: true,
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: suppliersAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (err, stack) => Center(child: Text('Gagal memuat supplier: $err')),
                data: (suppliers) {
                  final filteredSuppliers = suppliers.where((s) => s.name.toLowerCase().contains(_searchQuery.toLowerCase())).toList();

                  if (filteredSuppliers.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text('Supplier tidak ditemukan.'),
                          const SizedBox(height: 8),
                          ElevatedButton.icon(
                            icon: const Icon(Ionicons.add),
                            label: const Text('Tambah Supplier Baru'),
                            onPressed: _showAddSupplierDialog,
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView.builder(
                    itemCount: filteredSuppliers.length,
                    itemBuilder: (context, index) {
                      final supplier = filteredSuppliers[index];
                      return ListTile(
                        title: Text(supplier.name),
                        subtitle: supplier.address != null ? Text(supplier.address!) : null,
                        onTap: () => Navigator.of(context).pop(supplier),
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


// --- WIDGET DIALOG TAMBAH SUPPLIER ---
final addSupplierProvider = FutureProvider.family<void, Supplier>((ref, supplier) async {
  await FirebaseFirestore.instance.collection('suppliers').add(supplier.toFirestore());
});

class _AddSupplierDialog extends ConsumerStatefulWidget {
  final String initialName;
  const _AddSupplierDialog({required this.initialName});

  @override
  __AddSupplierDialogState createState() => __AddSupplierDialogState();
}

class __AddSupplierDialogState extends ConsumerState<_AddSupplierDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _addressController;
  late TextEditingController _whatsappController;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialName);
    _addressController = TextEditingController();
    _whatsappController = TextEditingController();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    _whatsappController.dispose();
    super.dispose();
  }

  Future<void> _saveSupplier() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isSaving = true);

      final newSupplier = Supplier(
        id: '', // ID akan dibuat oleh Firestore
        name: _nameController.text,
        address: _addressController.text,
        whatsapp: _whatsappController.text,
        createdAt: Timestamp.now(),
      );

      try {
        await ref.read(addSupplierProvider(newSupplier).future);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Supplier baru berhasil ditambahkan!')),
          );
          // Kirim supplier baru kembali ke dialog sebelumnya
          Navigator.of(context).pop(newSupplier);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Gagal menyimpan supplier: $e')),
          );
        }
      } finally {
        if (mounted) {
          setState(() => _isSaving = false);
        }
      }
    }
  }


  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Tambah Supplier Baru'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Nama Supplier'),
              validator: (value) => value == null || value.isEmpty ? 'Nama tidak boleh kosong' : null,
              autofocus: true,
            ),
            TextFormField(
              controller: _addressController,
              decoration: const InputDecoration(labelText: 'Alamat (Opsional)'),
            ),
            TextFormField(
              controller: _whatsappController,
              decoration: const InputDecoration(labelText: 'No. WhatsApp (Opsional)'),
              keyboardType: TextInputType.phone,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Batal')),
        if (_isSaving)
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.0),
            child: CircularProgressIndicator(),
          )
        else
          ElevatedButton(
            onPressed: _saveSupplier,
            child: const Text('Simpan'),
          ),
      ],
    );
  }
}
