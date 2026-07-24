import 'package:shared_preferences/shared_preferences.dart';

/// Pengaturan identitas toko & catatan yang tampil pada struk.
///
/// Nilai ini dipakai bersama oleh:
///  • tampilan struk di layar (print_page_screen.dart), dan
///  • byte ESC/POS yang benar-benar dicetak (thermal_printer_real.dart).
///
/// Sumbernya SharedPreferences agar konsisten dengan pengaturan printer.
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

  static const String _kStoreName = 'receipt_store_name';
  static const String _kStoreAddress = 'receipt_store_address';
  static const String _kStorePhone = 'receipt_store_phone';
  static const String _kFooterNote = 'receipt_footer_note';

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

  /// Muat pengaturan tersimpan; kolom yang belum diisi memakai nilai bawaan.
  static Future<ReceiptSettings> load() async {
    final prefs = await SharedPreferences.getInstance();
    return ReceiptSettings(
      storeName: prefs.getString(_kStoreName) ?? defaultStoreName,
      storeAddress: prefs.getString(_kStoreAddress) ?? defaultStoreAddress,
      storePhone: prefs.getString(_kStorePhone) ?? defaultStorePhone,
      footerNote: prefs.getString(_kFooterNote) ?? defaultFooterNote,
    );
  }

  Future<void> save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kStoreName, storeName);
    await prefs.setString(_kStoreAddress, storeAddress);
    await prefs.setString(_kStorePhone, storePhone);
    await prefs.setString(_kFooterNote, footerNote);
  }
}
