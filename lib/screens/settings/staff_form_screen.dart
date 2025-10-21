import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/staff_model.dart';
import '../../services/staff_service.dart';

class StaffFormScreen extends ConsumerStatefulWidget {
  final Staff? staff;

  const StaffFormScreen({super.key, this.staff});

  @override
  ConsumerState<StaffFormScreen> createState() => _StaffFormScreenState();
}

class _StaffFormScreenState extends ConsumerState<StaffFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _emailController;
  late TextEditingController _passwordController;
  late TextEditingController _confirmPasswordController;
  
  String _selectedPosition = 'Kasir'; 
  bool _isNewStaff = true;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _isNewStaff = widget.staff == null;
    _nameController = TextEditingController(text: widget.staff?.name ?? '');
    _emailController = TextEditingController(text: widget.staff?.email ?? '');
    _passwordController = TextEditingController();
    _confirmPasswordController = TextEditingController();

    if (!_isNewStaff) {
      _selectedPosition = widget.staff!.position; 
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _submitForm() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);
      final staffService = ref.read(staffServiceProvider);
      try {
        if (_isNewStaff) {
          await staffService.createStaff(
            _nameController.text,
            _emailController.text,
            _passwordController.text,
            _selectedPosition,
          );
        } else {
          // DIPERBARUI: Menggunakan fungsi yang benar untuk hanya memperbarui posisi
          await staffService.updateStaffPosition(
            widget.staff!.id,
            _selectedPosition,
          );
        }
        if (mounted) Navigator.pop(context);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Gagal menyimpan: ${e.toString()}')),
          );
        }
      } finally {
        if (mounted) {
          setState(() => _isLoading = false);
        }
      }
    }
  }

  Future<void> _deleteStaff() async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus Staff'),
        content: const Text('Anda yakin ingin menghapus staff ini? Tindakan ini tidak bisa dibatalkan.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Batal')),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            onPressed: () async {
              try {
                await ref.read(staffServiceProvider).deleteStaff(widget.staff!.id);
                if (mounted) {
                  Navigator.pop(context); // close dialog
                  Navigator.pop(context); // close form screen
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Gagal menghapus: ${e.toString()}')),
                  );
                }
              }
            },
            child: const Text('HAPUS'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isNewStaff ? 'Tambah Staff' : 'Edit Staff'),
        actions: [
          if (!_isNewStaff)
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.red),
              onPressed: _deleteStaff,
              tooltip: 'Hapus Staff',
            ),
        ],
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextFormField(
                    controller: _nameController,
                    decoration: const InputDecoration(labelText: 'Nama Lengkap', border: OutlineInputBorder()),
                    validator: (v) => (v == null || v.isEmpty) ? 'Nama tidak boleh kosong' : null,
                    enabled: _isNewStaff,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _emailController,
                    decoration: const InputDecoration(labelText: 'Email', border: OutlineInputBorder()),
                    keyboardType: TextInputType.emailAddress,
                    enabled: _isNewStaff,
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Email tidak boleh kosong';
                      if (!RegExp(r'^[^@]+@[^@]+\.[^@]+$').hasMatch(v)) return 'Format email salah';
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  if (_isNewStaff)
                    Column(
                      children: [
                        TextFormField(
                          controller: _passwordController,
                          decoration: const InputDecoration(labelText: 'Password', border: OutlineInputBorder()),
                          obscureText: true,
                          validator: (v) {
                            if (v == null || v.isEmpty) return 'Password minimal 6 karakter';
                            if (v.length < 6) return 'Password minimal 6 karakter';
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _confirmPasswordController,
                          decoration: const InputDecoration(labelText: 'Konfirmasi Password', border: OutlineInputBorder()),
                          obscureText: true,
                          validator: (v) => (v != _passwordController.text) ? 'Password tidak cocok' : null,
                        ),
                        const SizedBox(height: 16),
                      ],
                    ),
                  DropdownButtonFormField<String>(
                    initialValue: _selectedPosition,
                    decoration: const InputDecoration(labelText: 'Posisi', border: OutlineInputBorder()),
                    items: ['Kasir', 'Admin', 'Owner'].map((String position) {
                      return DropdownMenuItem<String>(
                        value: position,
                        child: Text(position),
                      );
                    }).toList(),
                    onChanged: (newValue) => setState(() => _selectedPosition = newValue!),
                  ),
                  const SizedBox(height: 32),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.save_alt_outlined),
                    label: const Text('Simpan'),
                    style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
                    onPressed: _isLoading ? null : _submitForm,
                  ),
                ],
              ),
            ),
          ),
          if (_isLoading)
            Container(
              color: Colors.black.withOpacity(0.5),
              child: const Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }
}
