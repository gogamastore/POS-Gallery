import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

/// Pengaturan notifikasi popup (pesan ramah / iklan) yang muncul di halaman
/// reseller web saat pertama membuka aplikasi. Menulis ke dokumen
/// `settings/popup_notification` (dibaca oleh web reseller).
class PopupNotificationScreen extends StatefulWidget {
  const PopupNotificationScreen({super.key});

  @override
  State<PopupNotificationScreen> createState() =>
      _PopupNotificationScreenState();
}

class _PopupNotificationScreenState extends State<PopupNotificationScreen> {
  final _docRef = FirebaseFirestore.instance
      .collection('settings')
      .doc('popup_notification');

  String _type = 'text'; // 'text' | 'image'
  bool _enabled = false;
  bool _loading = true;
  bool _saving = false;

  final _titleC = TextEditingController();
  final _subjectC = TextEditingController();
  final _bodyC = TextEditingController();

  String _imageUrl = '';
  Uint8List? _imageBytes;
  String? _imageName;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _titleC.dispose();
    _subjectC.dispose();
    _bodyC.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final snap = await _docRef.get();
      final d = snap.data();
      if (d != null) {
        _type = d['type'] == 'image' ? 'image' : 'text';
        _enabled = d['enabled'] == true;
        _titleC.text = (d['title'] ?? '').toString();
        _subjectC.text = (d['subject'] ?? '').toString();
        _bodyC.text = (d['body'] ?? '').toString();
        _imageUrl = (d['imageUrl'] ?? '').toString();
      }
    } catch (_) {
      _snack('Gagal memuat pengaturan notifikasi');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
        source: ImageSource.gallery, imageQuality: 85, maxWidth: 1000);
    if (picked != null) {
      final bytes = await picked.readAsBytes();
      setState(() {
        _imageBytes = bytes;
        _imageName = picked.name;
      });
    }
  }

  Future<String> _uploadIfNeeded() async {
    if (_imageBytes != null) {
      final fileName =
          '${DateTime.now().millisecondsSinceEpoch}_${_imageName ?? 'popup.jpg'}';
      final ref = FirebaseStorage.instance
          .ref()
          .child('popup_notifications')
          .child(fileName);
      final task = ref.putData(
          _imageBytes!, SettableMetadata(contentType: 'image/jpeg'));
      final snap = await task.whenComplete(() => {});
      return await snap.ref.getDownloadURL();
    }
    return _imageUrl;
  }

  Future<void> _save(bool nextEnabled) async {
    if (nextEnabled) {
      if (_type == 'text' &&
          _titleC.text.trim().isEmpty &&
          _bodyC.text.trim().isEmpty) {
        _snack('Isi judul atau pesan dulu');
        return;
      }
      if (_type == 'image' && _imageBytes == null && _imageUrl.isEmpty) {
        _snack('Pilih gambar dulu');
        return;
      }
    }
    setState(() => _saving = true);
    try {
      var imageUrl = _imageUrl;
      if (_type == 'image') imageUrl = await _uploadIfNeeded();
      await _docRef.set({
        'enabled': nextEnabled,
        'type': _type,
        'title': _titleC.text.trim(),
        'subject': _subjectC.text.trim(),
        'body': _bodyC.text.trim(),
        'imageUrl': imageUrl,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      if (!mounted) return;
      setState(() {
        _enabled = nextEnabled;
        _imageUrl = imageUrl;
        _imageBytes = null;
      });
      _snack(nextEnabled ? 'Notifikasi diaktifkan' : 'Perubahan disimpan');
    } catch (e) {
      _snack('Gagal menyimpan: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _snack(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(m)));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Notifikasi Popup')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Pesan/iklan yang muncul di halaman reseller saat pertama membuka aplikasi.',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ),
                    Chip(
                      label: Text(_enabled ? 'Aktif' : 'Nonaktif'),
                      backgroundColor: _enabled
                          ? Colors.green.withValues(alpha: 0.15)
                          : Colors.grey.withValues(alpha: 0.15),
                      labelStyle: TextStyle(
                        color: _enabled ? Colors.green[800] : Colors.grey[700],
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Pemilih jenis
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(
                        value: 'text',
                        label: Text('Teks'),
                        icon: Icon(Icons.text_fields)),
                    ButtonSegment(
                        value: 'image',
                        label: Text('Gambar'),
                        icon: Icon(Icons.image_outlined)),
                  ],
                  selected: {_type},
                  onSelectionChanged: (s) => setState(() => _type = s.first),
                ),
                const SizedBox(height: 20),

                if (_type == 'text') ..._buildTextFields() else ..._buildImageFields(theme),

                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _saving ? null : () => _save(true),
                    icon: _saving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.power_settings_new),
                    label: const Text('Aktifkan Notifikasi'),
                    style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14)),
                  ),
                ),
                if (_enabled) ...[
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _saving ? null : () => _save(false),
                      icon: const Icon(Icons.notifications_off_outlined),
                      label: const Text('Nonaktifkan'),
                    ),
                  ),
                ],
              ],
            ),
    );
  }

  List<Widget> _buildTextFields() {
    return [
      TextField(
        controller: _titleC,
        decoration: const InputDecoration(
          labelText: 'Judul Notifikasi',
          hintText: 'Contoh: Selamat Datang! 🎉',
          border: OutlineInputBorder(),
        ),
      ),
      const SizedBox(height: 12),
      TextField(
        controller: _subjectC,
        decoration: const InputDecoration(
          labelText: 'Subjek Pesan',
          hintText: 'Contoh: Promo Spesial Hari Ini',
          border: OutlineInputBorder(),
        ),
      ),
      const SizedBox(height: 12),
      TextField(
        controller: _bodyC,
        maxLines: 4,
        decoration: const InputDecoration(
          labelText: 'Isi Pesan',
          hintText: 'Tulis pesan ramah Anda di sini...',
          border: OutlineInputBorder(),
          alignLabelWithHint: true,
        ),
      ),
    ];
  }

  List<Widget> _buildImageFields(ThemeData theme) {
    Widget preview;
    if (_imageBytes != null) {
      preview = Image.memory(_imageBytes!, fit: BoxFit.contain);
    } else if (_imageUrl.isNotEmpty) {
      preview = Image.network(_imageUrl, fit: BoxFit.contain);
    } else {
      preview = const Center(child: Icon(Icons.add_photo_alternate_outlined, size: 40, color: Colors.grey));
    }

    return [
      const Text('Gambar Notifikasi (disarankan 650×1000px)',
          style: TextStyle(fontWeight: FontWeight.w500)),
      const SizedBox(height: 8),
      Center(
        child: Container(
          width: 160,
          decoration: BoxDecoration(
            color: Colors.grey.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.withValues(alpha: 0.3)),
          ),
          clipBehavior: Clip.antiAlias,
          child: AspectRatio(aspectRatio: 650 / 1000, child: preview),
        ),
      ),
      const SizedBox(height: 12),
      Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: _saving ? null : _pickImage,
              icon: const Icon(Icons.photo_library_outlined),
              label: const Text('Pilih Gambar'),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: OutlinedButton.icon(
              onPressed: (_saving || (_imageBytes == null && _imageUrl.isEmpty))
                  ? null
                  : () => _save(_enabled),
              icon: const Icon(Icons.cloud_upload_outlined),
              label: const Text('Unggah'),
            ),
          ),
        ],
      ),
    ];
  }
}
