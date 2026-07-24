
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// Model untuk data supplier
class Supplier {
  final String id;
  final String name;
  final String address;
  final String whatsapp;

  Supplier({
    required this.id,
    required this.name,
    this.address = '',
    this.whatsapp = '',
  });

  factory Supplier.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return Supplier(
      id: doc.id,
      name: data['name'] ?? '',
      address: data['address'] ?? '',
      whatsapp: data['whatsapp'] ?? '',
    );
  }
}

class SupplierManagementScreen extends StatefulWidget {
  const SupplierManagementScreen({super.key});

  @override
  State<SupplierManagementScreen> createState() =>
      _SupplierManagementScreenState();
}

class _SupplierManagementScreenState extends State<SupplierManagementScreen> {
  bool _isLoading = true;
  List<Supplier> _suppliers = [];

  @override
  void initState() {
    super.initState();
    _fetchSuppliers();
  }

  Future<void> _fetchSuppliers() async {
    setState(() => _isLoading = true);
    try {
      final querySnapshot =
          await FirebaseFirestore.instance.collection('suppliers').get();
      final fetchedData = querySnapshot.docs
          .map((doc) => Supplier.fromFirestore(doc))
          .toList();
      if (mounted) {
        setState(() {
          _suppliers = fetchedData;
        });
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Gagal memuat data supplier: ${error.toString()}')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showFormDialog({Supplier? supplier}) {
    showDialog(
      context: context,
      builder: (context) {
        return _SupplierFormDialog(
          supplier: supplier,
          onSave: () {
            _fetchSuppliers(); // Refresh list after saving
          },
        );
      },
    );
  }

  Future<void> _handleDelete(String id, String name) async {
    try {
      await FirebaseFirestore.instance.collection('suppliers').doc(id).delete();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Supplier "$name" berhasil dihapus')),
      );
      _fetchSuppliers(); // Refresh list
    } catch (error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal menghapus supplier: ${error.toString()}')),
      );
    }
  }

  void _showDeleteConfirmation(String id, String name) {
    showDialog(
      context: context,
      builder: (BuildContext ctx) {
        return AlertDialog(
          title: const Text('Anda Yakin?'),
          content: Text(
              'Tindakan ini akan menghapus supplier "$name" secara permanen.'),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Batal'),
            ),
            TextButton(
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              onPressed: () {
                Navigator.of(ctx).pop();
                _handleDelete(id, name);
              },
              child: const Text('Hapus'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pengaturan Supplier'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Card(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              _buildCardHeader(),
              Expanded(child: _buildCardContent()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCardHeader() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Daftar Supplier',
                    style:
                        TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                SizedBox(height: 4),
                Text(
                  'Tambah, edit, atau hapus daftar supplier untuk transaksi pembelian.',
                  style: TextStyle(color: Colors.grey),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          ElevatedButton.icon(
            icon: const Icon(Icons.add_circle_outline),
            label: const Text('Tambah'),
            onPressed: () => _showFormDialog(),
            style: ElevatedButton.styleFrom(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCardContent() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_suppliers.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24.0),
          child: Text(
            'Belum ada supplier yang ditambahkan.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16, color: Colors.grey),
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: _suppliers.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final supplier = _suppliers[index];
        return _buildSupplierTile(supplier);
      },
    );
  }

  Widget _buildSupplierTile(Supplier supplier) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(Icons.business, color: Theme.of(context).primaryColor, size: 32),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(supplier.name,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.phone, size: 14, color: Colors.grey.shade600),
                    const SizedBox(width: 4),
                    Text(supplier.whatsapp.isNotEmpty ? supplier.whatsapp : 'N/A',
                        style: TextStyle(color: Colors.grey.shade600)),
                  ],
                ),
                const SizedBox(height: 2),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.home_work, size: 14, color: Colors.grey.shade600),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                          supplier.address.isNotEmpty ? supplier.address : 'N/A',
                          style: TextStyle(color: Colors.grey.shade600)),
                    ),
                  ],
                ),
              ],
            ),
          ),
          _buildActionMenu(supplier),
        ],
      ),
    );
  }

  Widget _buildActionMenu(Supplier supplier) {
    return PopupMenuButton<String>(
      onSelected: (value) {
        if (value == 'edit') {
          _showFormDialog(supplier: supplier);
        } else if (value == 'delete') {
          _showDeleteConfirmation(supplier.id, supplier.name);
        }
      },
      itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
        const PopupMenuItem<String>(
          value: 'edit',
          child: ListTile(
            leading: Icon(Icons.edit_outlined),
            title: Text('Edit'),
          ),
        ),
        const PopupMenuItem<String>(
          value: 'delete',
          child: ListTile(
            leading: Icon(Icons.delete_outline, color: Colors.red),
            title: Text('Hapus', style: TextStyle(color: Colors.red)),
          ),
        ),
      ],
      icon: const Icon(Icons.more_vert),
    );
  }
}

// Dialog Form untuk Tambah/Edit Supplier
class _SupplierFormDialog extends StatefulWidget {
  final Supplier? supplier;
  final VoidCallback onSave;

  const _SupplierFormDialog({this.supplier, required this.onSave});

  @override
  State<_SupplierFormDialog> createState() => _SupplierFormDialogState();
}

class _SupplierFormDialogState extends State<_SupplierFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _whatsappController;
  late TextEditingController _addressController;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.supplier?.name ?? '');
    _whatsappController = TextEditingController(text: widget.supplier?.whatsapp ?? '');
    _addressController = TextEditingController(text: widget.supplier?.address ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _whatsappController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final data = {
        'name': _nameController.text,
        'whatsapp': _whatsappController.text,
        'address': _addressController.text,
      };

      if (widget.supplier == null) {
        // Create
        await FirebaseFirestore.instance.collection('suppliers').add({
          ...data,
          'createdAt': FieldValue.serverTimestamp(),
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Supplier berhasil ditambahkan')),
        );
      } else {
        // Update
        await FirebaseFirestore.instance
            .collection('suppliers')
            .doc(widget.supplier!.id)
            .update(data);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Supplier berhasil diperbarui')),
        );
      }
      widget.onSave();
      Navigator.of(context).pop();
    } catch (error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal menyimpan: ${error.toString()}')),
      );
    } finally {
      if(mounted){
         setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.supplier != null;
    return AlertDialog(
      title: Text(isEditing ? 'Edit Supplier' : 'Tambah Supplier Baru'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Nama Supplier',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Nama supplier harus diisi';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _whatsappController,
                decoration: const InputDecoration(
                  labelText: 'Nomor WhatsApp',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _addressController,
                decoration: const InputDecoration(
                  labelText: 'Alamat',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
            ],
          ),
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Batal'),
        ),
        ElevatedButton(
          onPressed: _isSubmitting ? null : _handleSave,
          child: _isSubmitting
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Simpan'),
        ),
      ],
    );
  }
}

