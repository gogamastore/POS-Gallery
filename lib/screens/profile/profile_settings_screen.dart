import 'dart:typed_data'; // DIIMPOR: Untuk Uint8List
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/user_provider.dart';

class ProfileSettingsScreen extends ConsumerStatefulWidget {
  const ProfileSettingsScreen({super.key});

  @override
  ConsumerState<ProfileSettingsScreen> createState() =>
      _ProfileSettingsScreenState();
}

class _ProfileSettingsScreenState extends ConsumerState<ProfileSettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _whatsappController = TextEditingController();

  // DIGANTI: Menggunakan Uint8List untuk kompatibilitas web
  Uint8List? _profileImageData;
  String _initialPhotoURL = '';
  bool _isLoading = false;
  bool _isInitialized = false;

  @override
  void dispose() {
    _nameController.dispose();
    _whatsappController.dispose();
    super.dispose();
  }

  void _initializeData(UserModel? user) {
    if (user != null && !_isInitialized) {
      _nameController.text = user.name;
      _whatsappController.text = user.whatsapp ?? '';
      _initialPhotoURL = user.photoURL ?? '';
      _isInitialized = true;
    }
  }

  // DIPERBAIKI: Mengambil gambar sebagai bytes (Uint8List)
  Future<void> _pickImage() async {
    final pickedFile = await ImagePicker()
        .pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (pickedFile != null) {
      final imageData = await pickedFile.readAsBytes();
      setState(() {
        _profileImageData = imageData;
      });
    }
  }

  // DIPERBAIKI: Mengirim Uint8List ke service
  Future<void> _handleSaveChanges() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final user = ref.read(userDataProvider).value;
      if (user == null) throw Exception('User tidak ditemukan');

      final updates = <String, dynamic>{};

      if (_profileImageData != null) {
        final newPhotoURL = await ref
            .read(userServiceProvider)
            .uploadProfilePicture(user.uid, _profileImageData!);
        updates['photoURL'] = newPhotoURL;
      }

      if (_nameController.text != user.name) {
        updates['name'] = _nameController.text;
      }
      if (_whatsappController.text != (user.whatsapp ?? '')) {
        updates['whatsapp'] = _whatsappController.text;
      }

      if (updates.isNotEmpty) {
        await ref.read(userServiceProvider).updateUser(user.uid, updates);
      }

      ref.invalidate(userDataProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Profil berhasil diperbarui'),
              backgroundColor: Colors.green),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Gagal menyimpan profil: $e'),
              backgroundColor: Colors.red),
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
    final currentUserData = ref.watch(userDataProvider);
    final authUser = ref.watch(authServiceProvider).currentUser;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('Pengaturan Profil',
            style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: currentUserData.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Gagal memuat data: $err')),
        data: (userModel) {
          _initializeData(userModel);

          // DIPERBAIKI: Logika untuk menampilkan gambar dari Uint8List atau URL
          ImageProvider<Object> displayImage;
          if (_profileImageData != null) {
            displayImage =
                MemoryImage(_profileImageData!); // Menampilkan dari memori
          } else if (_initialPhotoURL.isNotEmpty) {
            displayImage =
                NetworkImage(_initialPhotoURL); // Menampilkan dari internet
          } else {
            displayImage = const AssetImage('assets/images/placeholder.png');
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Form(
              key: _formKey,
              child: Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Informasi Akun',
                          style: TextStyle(
                              fontSize: 22, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Text('Perbarui informasi kontak dan nama Anda di sini.',
                          style: Theme.of(context).textTheme.bodySmall),
                      const SizedBox(height: 24),
                      _buildSectionTitle('Foto Profil'),
                      const SizedBox(height: 8),
                      Row(children: [
                        CircleAvatar(
                            radius: 50,
                            backgroundImage: displayImage,
                            backgroundColor: Colors.grey.shade200),
                        const SizedBox(width: 16),
                        Expanded(
                            child: ElevatedButton.icon(
                                icon: const Icon(Icons.upload_file),
                                label: const Text('Pilih Gambar'),
                                onPressed: _pickImage,
                                style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.grey.shade200,
                                    foregroundColor: Colors.black87,
                                    elevation: 0)))
                      ]),
                      const SizedBox(height: 24),
                      _buildTextField(
                          label: 'Nama Lengkap',
                          controller: _nameController,
                          validator: (val) => (val ?? '').isEmpty
                              ? 'Nama tidak boleh kosong'
                              : null),
                      const SizedBox(height: 16),
                      _buildTextField(
                          label: 'Nomor WhatsApp',
                          controller: _whatsappController,
                          keyboardType: TextInputType.phone,
                          placeholder: 'Contoh: 628123456789',
                          validator: (val) => (val ?? '').isEmpty
                              ? 'Nomor WhatsApp tidak boleh kosong'
                              : null),
                      const SizedBox(height: 16),
                      _buildTextField(
                          label: 'Email',
                          initialValue: authUser?.email ?? '',
                          enabled: false),
                      const SizedBox(height: 32),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _handleSaveChanges,
                          style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8))),
                          child: _isLoading
                              ? const CircularProgressIndicator(
                                  color: Colors.white)
                              : const Text('Simpan Perubahan Profil',
                                  style:
                                      TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(title,
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16));
  }

  Widget _buildTextField(
      {required String label,
      TextEditingController? controller,
      String? initialValue,
      bool enabled = true,
      TextInputType? keyboardType,
      String? placeholder,
      String? Function(String?)? validator}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          initialValue: initialValue,
          enabled: enabled,
          keyboardType: keyboardType,
          decoration: InputDecoration(
            hintText: placeholder,
            filled: !enabled,
            fillColor: Colors.grey[200],
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          ),
          validator: validator,
        ),
      ],
    );
  }
}
