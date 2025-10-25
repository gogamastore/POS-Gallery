import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:ionicons/ionicons.dart';

import '../../models/customer.dart';
import '../../providers/pos_provider.dart';
import '../../providers/customer_provider.dart';
import '../../providers/user_provider.dart';
import '../../services/pos_service.dart';

class ProcessPosScreen extends ConsumerStatefulWidget {
  const ProcessPosScreen({super.key});

  @override
  ProcessPosScreenState createState() => ProcessPosScreenState();
}

class ProcessPosScreenState extends ConsumerState<ProcessPosScreen> {
  final _formKey = GlobalKey<FormState>();
  Customer? _selectedCustomer;
  String _paymentMethod = 'cash';
  bool _isProcessing = false;

  Future<void> _showCustomerSelectionDialog() async {
    final selected = await showDialog<Customer>(
      context: context,
      builder: (context) => const _CustomerSelectionDialog(),
    );

    if (selected != null) {
      setState(() {
        _selectedCustomer = selected;
      });
    }
  }

  Future<void> _saveAsProcessing() async {
    if (!_formKey.currentState!.validate() || _isProcessing) return;

    final cartItems = ref.read(posCartProvider);
    final totalAmount = ref.read(posTotalProvider);
    final user = ref.read(userDataProvider).value;
    final kasirName = user?.name ?? 'Kasir';
    final navigator = Navigator.of(context);
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    if (cartItems.isEmpty) {
      scaffoldMessenger.showSnackBar(const SnackBar(content: Text('Keranjang kosong.')));
      return;
    }

    setState(() => _isProcessing = true);

    try {
      await PosService().saveOrderAsProcessing(
        items: cartItems,
        totalAmount: totalAmount,
        paymentMethod: _paymentMethod,
        kasir: kasirName,
        customer: _selectedCustomer,
      );
      ref.read(posCartProvider.notifier).clearCart();
      scaffoldMessenger.showSnackBar(const SnackBar(content: Text('Pesanan disimpan sebagai Draf.')));
      navigator.popUntil((route) => route.isFirst);
    } catch (e) {
      scaffoldMessenger.showSnackBar(SnackBar(content: Text('Gagal menyimpan draf: $e')));
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _processTransaction() async {
    if (!_formKey.currentState!.validate() || _isProcessing) {
      return;
    }

    final cartItems = ref.read(posCartProvider);
    final totalAmount = ref.read(posTotalProvider);
    final user = ref.read(userDataProvider).value;
    final kasirName = user?.name ?? 'Kasir';

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
      await PosService().processSaleTransaction(
        items: cartItems,
        totalAmount: totalAmount,
        paymentMethod: _paymentMethod,
        kasir: kasirName,
        customer: _selectedCustomer,
      );

      ref.read(posCartProvider.notifier).clearCart();

      scaffoldMessenger.showSnackBar(
        const SnackBar(content: Text('Transaksi penjualan berhasil diproses dan disimpan!')),
      );
      
      navigator.popUntil((route) => route.isFirst);

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
        title: const Text('Proses Penjualan', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
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
            const Text('1. Detail Customer & Pembayaran', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF2C3E50))),
            const Divider(height: 32),

            const Text('Customer (Member)', style: TextStyle(fontWeight: FontWeight.w500)),
            const SizedBox(height: 8),
            InkWell(
              onTap: _showCustomerSelectionDialog,
              child: InputDecorator(
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  suffixIcon: Icon(Icons.arrow_drop_down),
                ),
                child: Text(
                  _selectedCustomer?.name ?? 'Pilih Customer (Opsional)',
                  style: _selectedCustomer == null ? const TextStyle(color: Colors.black54) : null,
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
              value: 'qris',
              groupValue: _paymentMethod,
              onChanged: (String? value) {
                setState(() {
                  _paymentMethod = value!;
                });
              },
              child: const Text('QRIS'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummarySection(NumberFormat currencyFormatter) {
    final cartItems = ref.watch(posCartProvider);
    final totalAmount = ref.watch(posTotalProvider);

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('2. Ringkasan Penjualan', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF2C3E50))),
            const Divider(height: 32),
            if (cartItems.isEmpty)
              const Center(child: Text('Keranjang kosong.'))
            else
              ...cartItems.map((item) => ListTile(
                    title: Text(item.product.name),
                    subtitle: Text('${item.quantity} x ${currencyFormatter.format(item.PosPrice)}'),
                    trailing: Text(currencyFormatter.format(item.subtotal), style: const TextStyle(fontWeight: FontWeight.w500)),
                  )),
            const Divider(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Total Penjualan', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                Text(currencyFormatter.format(totalAmount), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF27AE60))),
              ],
            ),
            const SizedBox(height: 24),
            if (_isProcessing)
              const Center(child: CircularProgressIndicator())
            else
             Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: cartItems.isNotEmpty ? _saveAsProcessing : null,
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        side: const BorderSide(color: Colors.grey),
                        foregroundColor: Colors.black54,
                      ),
                      child: const Text('Simpan'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: cartItems.isNotEmpty ? _processTransaction : null,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        backgroundColor: const Color(0xFF27AE60),
                        foregroundColor: Colors.white,
                        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        disabledBackgroundColor: Colors.grey,
                      ),
                      child: const Text('Konfirmasi'),
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

class _CustomerSelectionDialog extends ConsumerStatefulWidget {
  const _CustomerSelectionDialog();

  @override
  __CustomerSelectionDialogState createState() => __CustomerSelectionDialogState();
}

class __CustomerSelectionDialogState extends ConsumerState<_CustomerSelectionDialog> {
  String _searchQuery = '';

  Future<void> _showAddCustomerDialog() async {
    final newCustomer = await showDialog<Customer>(
      context: context,
      barrierDismissible: false,
      builder: (context) => _AddCustomerDialog(initialName: _searchQuery),
    );

    if (newCustomer != null && mounted) {
      Navigator.of(context).pop(newCustomer);
    }
  }

  @override
  Widget build(BuildContext context) {
    final customersAsync = ref.watch(customerProvider);

    return AlertDialog(
      title: const Text('Pilih Customer'),
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
                  hintText: 'Cari nama customer...',
                  prefixIcon: Icon(Ionicons.search),
                  border: OutlineInputBorder(),
                ),
                autofocus: true,
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: customersAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (err, stack) => Center(child: Text('Gagal memuat customer: $err')),
                data: (customers) {
                  final filteredCustomers = customers.where((s) => s.name.toLowerCase().contains(_searchQuery.toLowerCase())).toList();

                  if (filteredCustomers.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text('Customer tidak ditemukan.'),
                          const SizedBox(height: 8),
                          ElevatedButton.icon(
                            icon: const Icon(Ionicons.add),
                            label: const Text('Tambah Customer Baru'),
                            onPressed: _showAddCustomerDialog,
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView.builder(
                    itemCount: filteredCustomers.length,
                    itemBuilder: (context, index) {
                      final customer = filteredCustomers[index];
                      return ListTile(
                        title: Text(customer.name),
                        subtitle: customer.address != null ? Text(customer.address!) : null,
                        onTap: () => Navigator.of(context).pop(customer),
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

final addCustomerProvider = FutureProvider.family<void, Customer>((ref, customer) async {
  await FirebaseFirestore.instance.collection('customers').add(customer.toFirestore());
});

class _AddCustomerDialog extends ConsumerStatefulWidget {
  final String initialName;
  const _AddCustomerDialog({required this.initialName});

  @override
  __AddCustomerDialogState createState() => __AddCustomerDialogState();
}

class __AddCustomerDialogState extends ConsumerState<_AddCustomerDialog> {
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

  Future<void> _saveCustomer() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isSaving = true);

      final newCustomer = Customer(
        id: '',
        name: _nameController.text,
        address: _addressController.text,
        whatsapp: _whatsappController.text,
        createdAt: Timestamp.now(),
      );

      try {
        await ref.read(addCustomerProvider(newCustomer).future);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Customer baru berhasil ditambahkan!')),
          );
          Navigator.of(context).pop(newCustomer);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Gagal menyimpan customer: $e')),
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
      title: const Text('Tambah Customer Baru'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Nama Customer'),
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
            onPressed: _saveCustomer,
            child: const Text('Simpan'),
          ),
      ],
    );
  }
}
