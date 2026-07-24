import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:firebase_storage/firebase_storage.dart';

import '../../models/product.dart';
import '../../models/product_category.dart';
import '../../providers/category_provider.dart';
import '../../providers/product_provider.dart';

class AddProductScreen extends ConsumerStatefulWidget {
  const AddProductScreen({super.key});

  @override
  AddProductScreenState createState() => AddProductScreenState();
}

class AddProductScreenState extends ConsumerState<AddProductScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _skuController;
  late TextEditingController _priceController;
  late TextEditingController _purchasePriceController;
  late TextEditingController _stockController;
  late TextEditingController _descriptionController;

  String? _selectedCategoryId;
  Uint8List? _imageBytes;
  String? _imageName;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _skuController = TextEditingController();
    _priceController = TextEditingController();
    _purchasePriceController = TextEditingController();
    _stockController = TextEditingController();
    _descriptionController = TextEditingController();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _skuController.dispose();
    _priceController.dispose();
    _purchasePriceController.dispose();
    _stockController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: source, imageQuality: 80, maxWidth: 1024);
    if (pickedFile != null) {
      final bytes = await pickedFile.readAsBytes();
      setState(() {
        _imageBytes = bytes;
        _imageName = pickedFile.name;
      });
    }
  }

  Future<String?> _uploadImage(Uint8List imageBytes, String imageName) async {
    try {
      final fileName = '${DateTime.now().millisecondsSinceEpoch}_$imageName';
      final ref = FirebaseStorage.instance.ref().child('product_images').child(fileName);
      final uploadTask = ref.putData(imageBytes, SettableMetadata(contentType: 'image/jpeg'));
      final snapshot = await uploadTask.whenComplete(() => {});
      return await snapshot.ref.getDownloadURL();
    } catch (e) {
      if (!mounted) return null;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal mengunggah gambar: $e')),
      );
      return null;
    }
  }

  Future<void> _saveProduct() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isSaving = true;
      });

      final navigator = Navigator.of(context);
      final scaffoldMessenger = ScaffoldMessenger.of(context);

      String? imageUrl;
      if (_imageBytes != null && _imageName != null) {
        imageUrl = await _uploadImage(_imageBytes!, _imageName!);
        if (imageUrl == null) {
          setState(() {
            _isSaving = false;
          });
          return; 
        }
      }

      final name = _nameController.text;
      final sku = _skuController.text;
      final price = double.tryParse(_priceController.text) ?? 0.0;
      final purchasePrice = double.tryParse(_purchasePriceController.text) ?? 0.0;
      final stock = int.tryParse(_stockController.text) ?? 0;
      final description = _descriptionController.text;

      final newProduct = Product(
        id: '', 
        name: name,
        sku: sku,
        price: price,
        purchasePrice: purchasePrice,
        stock: stock,
        description: description,
        categoryId: _selectedCategoryId,
        image: imageUrl,
      );

      try {
        await ref.read(productServiceProvider).addProduct(newProduct);
        if (!mounted) return;
        scaffoldMessenger.showSnackBar(
          SnackBar(content: Text('Produk "$name" berhasil ditambahkan!'), backgroundColor: Colors.green),
        );
        navigator.pop();
      } catch (e) {
        if (!mounted) return;
        scaffoldMessenger.showSnackBar(
          SnackBar(content: Text('Gagal menambah produk: $e')),
        );
      } finally {
         if (mounted) {
          setState(() {
            _isSaving = false;
          });
        }
      }
    }
  }

   void _showAddCategoryDialog() {
    final categoryNameController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) {
        final navigator = Navigator.of(context);
        final scaffoldMessenger = ScaffoldMessenger.of(context);

        return AlertDialog(
          title: const Text('Tambah Kategori Baru'),
          content: TextField(
            controller: categoryNameController,
            decoration: const InputDecoration(hintText: "Nama Kategori"),
            autofocus: true,
          ),
          actions: [
            TextButton(onPressed: () => navigator.pop(), child: const Text('Batal')),
            TextButton(
              child: const Text('Tambah'),
              onPressed: () async {
                final name = categoryNameController.text;
                if (name.isNotEmpty) {
                  try {
                    await ref.read(addCategoryProvider(name).future);
                    if (!mounted) return;
                    navigator.pop();
                    scaffoldMessenger.showSnackBar(
                      SnackBar(content: Text('Kategori "$name" berhasil ditambahkan.')),
                    );
                  } catch (e) {
                     if (!mounted) return;
                     scaffoldMessenger.showSnackBar(
                      SnackBar(content: Text('Gagal menambah kategori: $e')),
                    );
                  }
                }
              },
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
        title: const Text('Tambah Produk Baru'),
        actions: [
          IconButton(
            icon: _isSaving ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Icon(Icons.save),
            onPressed: _isSaving ? null : _saveProduct,
            tooltip: 'Simpan',
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              _buildImageEditor(),
              const SizedBox(height: 24),
              _buildTextField(_nameController, 'Nama Produk', 'Masukkan nama produk'),
              const SizedBox(height: 16),
              _buildTextField(_skuController, 'SKU (Stock Keeping Unit)', 'Masukkan SKU', optional: true),
              const SizedBox(height: 16),
              _buildCategoryDropdown(),
              const SizedBox(height: 16),
              _buildPriceFields(),
              const SizedBox(height: 16),
              _buildTextField(_descriptionController, 'Deskripsi', 'Masukkan deskripsi produk', maxLines: 4, optional: true),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildImageEditor() {
    return Center(
      child: Stack(
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: const Color(0xFFE0E6ED),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 4),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(26), // Menggunakan withAlpha untuk menghindari deprecation warning
                  blurRadius: 10,
                  offset: const Offset(0, 5),
                )
              ]
            ),
            child: ClipOval(
              child: _imageBytes != null
                  ? Image.memory(
                      _imageBytes!,
                      fit: BoxFit.cover,
                      width: 120,
                      height: 120,
                    )
                  : const Icon(Icons.camera_alt, size: 50, color: Color(0xFFBDC3C7)),
            ),
          ),
          Positioned(
            bottom: 0,
            right: 0,
            child: CircleAvatar(
              radius: 20,
              backgroundColor: Theme.of(context).primaryColor,
              child: IconButton(
                icon: const Icon(Icons.edit, color: Colors.white, size: 20),
                onPressed: () {
                  showModalBottomSheet(
                    context: context,
                    builder: (BuildContext context) {
                      return SafeArea(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            ListTile(
                              leading: const Icon(Icons.photo_library),
                              title: const Text('Pilih dari Galeri'),
                              onTap: () {
                                _pickImage(ImageSource.gallery);
                                Navigator.of(context).pop();
                              },
                            ),
                            ListTile(
                              leading: const Icon(Icons.camera_alt),
                              title: const Text('Ambil Foto'),
                              onTap: () {
                                _pickImage(ImageSource.camera);
                                Navigator.of(context).pop();
                              },
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String label, String hint, {bool optional = false, int maxLines = 1}) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label + (optional ? ' (Opsional)' : ''),
        hintText: hint,
        border: const OutlineInputBorder(),
      ),
      validator: (value) {
        if (!optional && (value == null || value.isEmpty)) {
          return '$label tidak boleh kosong';
        }
        return null;
      },
    );
  }

  Widget _buildCategoryDropdown() {
    final categoriesAsync = ref.watch(categoriesStreamProvider);
    return categoriesAsync.when(
      data: (categories) {
        if (_selectedCategoryId != null && !categories.any((c) => c.id == _selectedCategoryId)) {
           _selectedCategoryId = null;
        }

        return DropdownButtonFormField<String>(
          initialValue: _selectedCategoryId,
          hint: const Text('Pilih Kategori'),
          isExpanded: true,
          items: categories.map((ProductCategory category) {
            return DropdownMenuItem<String>(
              value: category.id,
              child: Text(category.name),
            );
          }).toList(),
          onChanged: (value) => setState(() => _selectedCategoryId = value),
          decoration: InputDecoration(
            labelText: 'Kategori',
            border: const OutlineInputBorder(),
            suffixIcon: IconButton(
              icon: const Icon(Icons.add_circle_outline),
              onPressed: _showAddCategoryDialog,
              tooltip: 'Tambah Kategori Baru',
            ),
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, stack) => Text('Gagal memuat kategori: $err'),
    );
  }

  Widget _buildPriceFields() {
    final currencyFormatter = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          controller: _priceController,
          decoration: const InputDecoration(
            labelText: 'Harga Jual',
            border: OutlineInputBorder(),
            prefixText: 'Rp ',
          ),
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Harga Jual tidak boleh kosong';
            }
            final price = double.tryParse(value) ?? 0.0;
            final purchasePrice = double.tryParse(_purchasePriceController.text) ?? 0.0;
            if (purchasePrice > 0 && price < purchasePrice) {
              return 'Harga Jual tidak boleh lebih rendah dari Harga Beli (${currencyFormatter.format(purchasePrice)})';
            }
            return null;
          },
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _purchasePriceController,
          decoration: const InputDecoration(
            labelText: 'Harga Beli',
            border: OutlineInputBorder(),
            prefixText: 'Rp ',
          ),
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
           validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Harga Beli tidak boleh kosong';
            }
            return null;
          },
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _stockController,
          decoration: const InputDecoration(
            labelText: 'Stok Awal',
            border: OutlineInputBorder(),
          ),
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
           validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Stok Awal tidak boleh kosong';
            }
            return null;
          },
        ),
      ],
    );
  }
}
