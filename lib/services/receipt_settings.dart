import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Pengaturan identitas toko & catatan yang tampil pada struk.
///
/// Model multi-toko (cabang): setiap toko/cabang punya dokumen sendiri di
/// koleksi Firestore `struk`, dengan ID dokumen = **label toko** (mis.
/// "Gallery Makassar Pusat", "Cabang Antang"). Dengan begitu satu proyek bisa
/// dipakai banyak cabang, masing-masing punya kop & catatan struk sendiri.
///
/// Setiap perangkat menyimpan **label aktif** (secara lokal) — yaitu label yang
/// dipakai saat mencetak di perangkat itu. SharedPreferences juga menyimpan
/// cache pengaturan label aktif agar cepat & tetap jalan offline.
///
/// Dipakai bersama oleh:
///  • tampilan struk di layar (print_page_screen.dart), dan
///  • byte ESC/POS yang benar-benar dicetak (thermal_printer_real.dart).
class ReceiptSettings {
  const ReceiptSettings({
    required this.storeName,
    required this.storeAddress,
    required this.storePhone,
    required this.footerNote,
  });

  /// Nama toko (judul struk).
  final String storeName;

  /// Alamat toko.
  final String storeAddress;

  /// Nomor telepon (ditampilkan dengan awalan "Telp: ").
  final String storePhone;

  /// Catatan/keterangan di bagian bawah struk.
  final String footerNote;

  // Nilai bawaan = teks lama yang sebelumnya di-hardcode, agar perilaku tak
  // berubah bila pengguna belum pernah menyimpan pengaturan.
  static const String defaultStoreName = 'GALLERY MAKASSAR';
  static const String defaultStoreAddress = 'Jl. Borong Raya No. 100';
  static const String defaultStorePhone = '0895635299075';
  static const String defaultFooterNote =
      'Barang yang sudah dibeli tidak dapat dikembalikan.';

  static const ReceiptSettings defaults = ReceiptSettings(
    storeName: defaultStoreName,
    storeAddress: defaultStoreAddress,
    storePhone: defaultStorePhone,
    footerNote: defaultFooterNote,
  );

  // ── Lokasi penyimpanan ─────────────────────────────────────────────────────
  // Firestore: koleksi `struk`, ID dokumen = label toko.
  static const String _kCollection = 'struk';

  // Cache lokal (SharedPreferences).
  static const String _kActiveLabel = 'receipt_active_label';
  static const String _kStoreName = 'receipt_store_name';
  static const String _kStoreAddress = 'receipt_store_address';
  static const String _kStorePhone = 'receipt_store_phone';
  static const String _kFooterNote = 'receipt_footer_note';

  // Batas tunggu jaringan agar jalur cetak tak menggantung saat jaringan lambat.
  static const Duration _networkTimeout = Duration(seconds: 5);

  static CollectionReference<Map<String, dynamic>> get _col =>
      FirebaseFirestore.instance.collection(_kCollection);

  static DocumentReference<Map<String, dynamic>> _docFor(String label) =>
      _col.doc(label);

  ReceiptSettings copyWith({
    String? storeName,
    String? storeAddress,
    String? storePhone,
    String? footerNote,
  }) =>
      ReceiptSettings(
        storeName: storeName ?? this.storeName,
        storeAddress: storeAddress ?? this.storeAddress,
        storePhone: storePhone ?? this.storePhone,
        footerNote: footerNote ?? this.footerNote,
      );

  Map<String, dynamic> toMap() => {
        'storeName': storeName,
        'storeAddress': storeAddress,
        'storePhone': storePhone,
        'footerNote': footerNote,
      };

  /// Bentuk objek dari data Firestore. Kolom yang tidak ada memakai nilai bawaan;
  /// string kosong yang sengaja disimpan pengguna tetap dipertahankan.
  factory ReceiptSettings.fromMap(Map<String, dynamic> map) => ReceiptSettings(
        storeName: (map['storeName'] as String?) ?? defaultStoreName,
        storeAddress: (map['storeAddress'] as String?) ?? defaultStoreAddress,
        storePhone: (map['storePhone'] as String?) ?? defaultStorePhone,
        footerNote: (map['footerNote'] as String?) ?? defaultFooterNote,
      );

  // ── Label toko (cabang) ────────────────────────────────────────────────────

  /// Daftar semua label toko (ID dokumen) di koleksi `struk`, terurut.
  static Future<List<String>> listLabels() async {
    try {
      final snap = await _col.get().timeout(_networkTimeout);
      final labels = snap.docs.map((d) => d.id).toList()..sort();
      return labels;
    } catch (_) {
      return const <String>[];
    }
  }

  /// Label toko yang sedang dipakai perangkat ini (null bila belum dipilih).
  static Future<String?> getActiveLabel() async {
    final prefs = await SharedPreferences.getInstance();
    final l = prefs.getString(_kActiveLabel);
    return (l != null && l.isNotEmpty) ? l : null;
  }

  /// Tetapkan label toko yang dipakai perangkat ini.
  static Future<void> setActiveLabel(String label) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kActiveLabel, label);
  }

  /// Apakah string bisa dipakai sebagai ID dokumen Firestore.
  static bool isValidLabel(String label) {
    final l = label.trim();
    return l.isNotEmpty &&
        !l.contains('/') &&
        l != '.' &&
        l != '..' &&
        !(l.startsWith('__') && l.endsWith('__'));
  }

  // ── Muat & simpan ──────────────────────────────────────────────────────────

  /// Muat pengaturan **label aktif** untuk jalur cetak/tampilan: Firestore lebih
  /// dulu (sumber kebenaran), lalu jatuh ke cache lokal bila offline/gagal,
  /// terakhir ke nilai bawaan.
  static Future<ReceiptSettings> load() async {
    final label = await getActiveLabel();
    if (label != null) {
      try {
        final snap = await _docFor(label).get().timeout(_networkTimeout);
        final data = snap.data();
        if (snap.exists && data != null) {
          final remote = ReceiptSettings.fromMap(data);
          // Perbarui cache lokal agar pemuatan berikutnya cepat & tahan offline.
          await remote._writeLocalCache();
          return remote;
        }
      } catch (_) {
        // Offline / lambat / gagal → pakai cache lokal di bawah.
      }
    }
    return _readLocalCache();
  }

  /// Simpan pengaturan ke dokumen `struk/{label}` (sinkron antar-perangkat) dan
  /// jadikan [label] sebagai label aktif perangkat ini, sekaligus perbarui cache
  /// lokal. Bila offline, tulisan Firestore diantrekan otomatis & tersinkron
  /// nanti.
  Future<void> saveForLabel(String label) async {
    await setActiveLabel(label);
    await _writeLocalCache();
    try {
      await _docFor(label).set(
        {
          ...toMap(),
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      ).timeout(_networkTimeout);
    } on TimeoutException {
      // Offline/lambat: tulisan sudah tersimpan lokal & diantrekan Firestore.
      // Bukan kegagalan fatal — akan tersinkron saat kembali online.
    }
    // Galat lain (mis. permission-denied saat online) sengaja diteruskan agar
    // UI dapat memberi tahu pengguna.
  }

  // ── Cache lokal ────────────────────────────────────────────────────────────
  static Future<ReceiptSettings> _readLocalCache() async {
    final prefs = await SharedPreferences.getInstance();
    return ReceiptSettings(
      storeName: prefs.getString(_kStoreName) ?? defaultStoreName,
      storeAddress: prefs.getString(_kStoreAddress) ?? defaultStoreAddress,
      storePhone: prefs.getString(_kStorePhone) ?? defaultStorePhone,
      footerNote: prefs.getString(_kFooterNote) ?? defaultFooterNote,
    );
  }

  Future<void> _writeLocalCache() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kStoreName, storeName);
    await prefs.setString(_kStoreAddress, storeAddress);
    await prefs.setString(_kStorePhone, storePhone);
    await prefs.setString(_kFooterNote, footerNote);
  }
}
