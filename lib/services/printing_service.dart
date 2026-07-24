import 'dart:typed_data';

import 'package:myapp/models/order.dart';

import 'printer_device.dart';

// Ekspor factory-nya saja; implementasi dipilih saat kompilasi:
//  • web / platform tanpa dart:io → stub (no-op).
//  • Android / Windows / desktop  → implementasi asli flutter_thermal_printer.
export 'thermal_printer_stub.dart'
    if (dart.library.io) 'thermal_printer_real.dart' show getPrintingService;

export 'printer_device.dart';

/// Kontrak layanan cetak struk termal.
///
/// Model discovery bersifat STREAM: panggil [startDiscovery] lalu dengarkan
/// [devicesStream]. Daftar akan bertambah saat perangkat baru ditemukan.
abstract class PrintingService {
  /// True hanya di platform yang mendukung USB (saat ini Windows). Dipakai UI
  /// untuk menyembunyikan opsi USB di Android.
  bool get supportsUsb;

  /// Daftar printer yang ditemukan, diperbarui secara langsung selama scan.
  Stream<List<PrinterDevice>> get devicesStream;

  /// Mulai memindai. [bluetooth] menyalakan BLE (Android & Windows); [usb]
  /// hanya berlaku di Windows dan diabaikan di platform lain.
  Future<void> startDiscovery({bool bluetooth = true, bool usb = false});

  /// Hentikan pemindaian dan bebaskan sumber daya.
  Future<void> stopDiscovery();

  /// Susun byte ESC/POS untuk sebuah pesanan.
  Future<Uint8List> buildReceiptBytes(Order order, {int paperSize = 80});

  /// Cetak pesanan ke [device]: connect → kirim → disconnect.
  Future<void> printOrder(PrinterDevice device, Order order,
      {int paperSize = 80});

  /// Cetak pesanan ke printer default yang tersimpan.
  Future<void> printToSavedDefault(Order order, {int paperSize = 80});

  /// Simpan printer default.
  Future<void> saveDefaultPrinter(PrinterDevice device);

  /// Muat printer default yang tersimpan (null bila belum ada).
  Future<PrinterDevice?> loadDefaultPrinter();
}
