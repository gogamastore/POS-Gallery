import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ionicons/ionicons.dart';

import '../../providers/auth_provider.dart';

class AddCustomerScreen extends ConsumerStatefulWidget {
  const AddCustomerScreen({super.key});

  @override
  ConsumerState<AddCustomerScreen> createState() => _AddCustomerScreenState();
}

class _AddCustomerScreenState extends ConsumerState<AddCustomerScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _whatsappController = TextEditingController();
  final _addressController = TextEditingController();
  
  String _selectedRole = 'reseller';
  bool _isLoading = false;
  bool _isPasswordVisible = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _whatsappController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isLoading = true);

    try {
      final authService = ref.read(authServiceProvider);
      await authService.createCustomer(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
        name: _nameController.text.trim(),
        whatsapp: _whatsappController.text.trim(),
        address: _addressController.text.trim(),
        role: _selectedRole,
      );
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Customer berhasil ditambahkan!'), backgroundColor: Colors.green),
        );
        // Kirim 'true' untuk menandakan sukses
        Navigator.of(context).pop(true);
      }

    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal menambahkan customer: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tambah Customer Baru'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildTextFormField(
                controller: _nameController,
                labelText: 'Nama Lengkap',
                prefixIcon: Ionicons.person_outline,
                validator: (value) => value!.isEmpty ? 'Nama tidak boleh kosong' : null,
              ),
              const SizedBox(height: 16),
              _buildTextFormField(
                controller: _emailController,
                labelText: 'Email',
                prefixIcon: Ionicons.at_outline,
                keyboardType: TextInputType.emailAddress,
                validator: (value) {
                  if (value!.isEmpty) return 'Email tidak boleh kosong';
                  if (!value.contains('@')) return 'Masukkan email yang valid';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              _buildTextFormField(
                  controller: _passwordController,
                  labelText: 'Password',
                  prefixIcon: Ionicons.lock_closed_outline,
                  obscureText: !_isPasswordVisible,
                  validator: (value) => value!.length < 6 ? 'Password minimal 6 karakter' : null,
                  suffixIcon: IconButton(
                    icon: Icon(_isPasswordVisible ? Ionicons.eye_off_outline : Ionicons.eye_outline),
                    onPressed: () => setState(() => _isPasswordVisible = !_isPasswordVisible),
                  )),
              const SizedBox(height: 16),
              _buildTextFormField(
                controller: _whatsappController,
                labelText: 'Nomor WhatsApp',
                prefixIcon: Ionicons.logo_whatsapp,
                keyboardType: TextInputType.phone,
                validator: (value) => value!.isEmpty ? 'Nomor WhatsApp tidak boleh kosong' : null,
              ),
              const SizedBox(height: 16),
               _buildTextFormField(
                controller: _addressController,
                labelText: 'Alamat',
                prefixIcon: Ionicons.location_outline,
                 maxLines: 3,
                validator: (value) => value!.isEmpty ? 'Alamat tidak boleh kosong' : null,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: _selectedRole,
                decoration: const InputDecoration(
                  labelText: 'Role',
                  prefixIcon: Icon(Ionicons.ribbon_outline),
                  border: OutlineInputBorder(),
                ),
                items: ['reseller', 'customer', 'admin'].map((String value) {
                  return DropdownMenuItem<String>(
                    value: value,
                    child: Text(value[0].toUpperCase() + value.substring(1)), // Capitalize first letter
                  );
                }).toList(),
                onChanged: (newValue) {
                  setState(() {
                    _selectedRole = newValue!;
                  });
                },
              ),
              const SizedBox(height: 32),
              ElevatedButton.icon(
                onPressed: _isLoading ? null : _submit,
                icon: _isLoading
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Icon(Ionicons.add_circle_outline, color: Colors.white),
                label: Text(_isLoading ? 'Menyimpan...' : 'Simpan Customer', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: Theme.of(context).primaryColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  TextFormField _buildTextFormField({
    required TextEditingController controller,
    required String labelText,
    required IconData prefixIcon,
    String? Function(String?)? validator,
    TextInputType? keyboardType,
    bool obscureText = false,
    Widget? suffixIcon,
    int? maxLines = 1,
  }) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: labelText,
        prefixIcon: Icon(prefixIcon),
        border: const OutlineInputBorder(),
        suffixIcon: suffixIcon,
      ),
      keyboardType: keyboardType,
      obscureText: obscureText,
      validator: validator,
      maxLines: obscureText ? 1 : maxLines,
    );
  }
}
