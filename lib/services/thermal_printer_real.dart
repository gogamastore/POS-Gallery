import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
// Transport Bluetooth Classic (SPP/RFCOMM) untuk Android. Dipakai HANYA di
// cabang Android; di Windows objek ini tidak pernah dipanggil.
import 'package:blue_thermal_printer/blue_thermal_printer.dart' as blue_thermal;
// Facade paket ini juga meng-ekspor esc_pos_utils_plus (Generator, PaperSize,
// PosStyles, CapabilityProfile) dan Uint8List lewat foundation.
import 'package:flutter_thermal_printer/flutter_thermal_printer.dart';
// Printer & ConnectionType tidak ikut di-export oleh library utama paket,
// jadi diimpor langsung dari modul model-nya.
import 'package:flutter_thermal_printer/utils/printer.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/order.dart';
import 'printing_service.dart';
import 'receipt_settings.dart';

const _kDefaultPrinterKey = 'default_printer_json';

// Transport dibagi per platform:
//  • Android + Bluetooth → blue_thermal_printer (Bluetooth Classic / SPP).
//    flutter_thermal_printer hanya memakai BLE, sementara mayoritas printer
//    struk termal adalah perangkat Bluetooth Classic — sehingga koneksi BLE
//    "berhasil" tetapi data ESC/POS tidak pernah sampai ke printer.
//  • Windows (USB / BLE)  → flutter_thermal_printer (Win32 spooler / universal_ble).
class _PrintingServiceImpl implements PrintingService {
  final FlutterThermalPrinter _plugin = FlutterThermalPrinter.instance;

  // Instance blue_thermal_printer. Hanya berupa objek Dart + MethodChannel;
  // tidak ada panggilan native sampai method-nya dipakai di cabang Android.
  final blue_thermal.BlueThermalPrinter _bt =
      blue_thermal.BlueThermalPrinter.instance;

  final currencyFormatter =
      NumberFormat.currency(locale: 'id_ID', symbol: '', decimalDigits: 0);

  final _devicesController =
      StreamController<List<PrinterDevice>>.broadcast();
  StreamSubscription? _pluginSub;

  // Snapshot terakhir. Daftar bonded Android hanya di-emit SEKALI, sedangkan
  // stream broadcast tidak menyangga event — tanpa cache ini, pendengar yang
  // subscribe sedikit terlambat (mis. StreamBuilder di picker) akan kehilangan
  // emisi itu dan loading selamanya. Cache di-replay ke setiap pendengar baru.
  List<PrinterDevice> _lastDevices = const <PrinterDevice>[];

  _PrintingServiceImpl() {
    // Terjemahkan daftar Printer milik paket menjadi model netral kita.
    _pluginSub = _plugin.devicesStream.listen((printers) {
      if (_devicesController.isClosed) return;
      // Di Android transport Bluetooth memakai blue_thermal_printer (Classic).
      // Abaikan emisi flutter_thermal_printer di sini agar snapshot [] miliknya
      // tidak menimpa daftar bonded yang sudah ditemukan.
      if (Platform.isAndroid) return;
      _emit(printers.map(_toDevice).toList());
    });
  }

  // Simpan snapshot lalu siarkan. Dipakai semua sumber discovery.
  void _emit(List<PrinterDevice> devices) {
    _lastDevices = devices;
    if (!_devicesController.isClosed) _devicesController.add(devices);
  }

  @override
  bool get supportsUsb => Platform.isWindows;

  @override
  Stream<List<PrinterDevice>> get devicesStream async* {
    // Pendengar baru langsung menerima snapshot terakhir, lalu update live.
    yield _lastDevices;
    yield* _devicesController.stream;
  }

  @override
  Future<void> startDiscovery(
      {bool bluetooth = true, bool usb = false}) async {
    // Android + Bluetooth: pakai Bluetooth Classic. blue_thermal_printer tidak
    // memindai secara live, melainkan mengambil daftar perangkat yang sudah
    // DIPASANGKAN (paired) di Pengaturan Bluetooth. Printer wajib di-pair dulu.
    if (bluetooth && Platform.isAndroid) {
      await _discoverBondedBluetooth();
      return;
    }

    final types = <ConnectionType>[];
    // BLE hanya relevan untuk Windows di sini (Android sudah ditangani di atas).
    if (bluetooth && Platform.isWindows) types.add(ConnectionType.BLE);
    // USB hanya di Windows (PC tanpa Bluetooth). Diabaikan di Android.
    if (usb && Platform.isWindows) types.add(ConnectionType.USB);
    if (types.isEmpty) return;
    try {
      await _plugin.getPrinters(connectionTypes: types);
    } catch (e) {
      if (kDebugMode) print('startDiscovery failed: $e');
      rethrow;
    }
  }

  // Ambil printer Bluetooth Classic yang sudah dipasangkan dan dorong sekali ke
  // stream perangkat agar UI picker menampilkannya.
  Future<void> _discoverBondedBluetooth() async {
    try {
      // Timeout agar tidak menggantung tanpa batas bila native tak merespons —
      // lebih baik memunculkan error di UI daripada loading selamanya.
      final bonded = await _bt
          .getBondedDevices()
          .timeout(const Duration(seconds: 8));
      if (_devicesController.isClosed) return;
      _emit(bonded
          .map((d) => PrinterDevice(
                name: (d.name?.isNotEmpty ?? false) ? d.name! : 'Printer',
                address: d.address ?? '',
                connection: PrinterConnection.bluetooth,
              ))
          .toList());
    } catch (e) {
      if (kDebugMode) print('getBondedDevices failed: $e');
      rethrow;
    }
  }

  @override
  Future<void> stopDiscovery() async {
    // Android memakai daftar bonded (bukan scan berkelanjutan) — tak ada yang
    // perlu dihentikan.
    if (Platform.isAndroid) return;
    try {
      await _plugin.stopScan();
    } catch (e) {
      if (kDebugMode) print('stopDiscovery failed: $e');
    }
  }

  // ── Pemetaan model ────────────────────────────────────────────────────────
  PrinterDevice _toDevice(Printer p) => PrinterDevice(
        name: (p.name?.isNotEmpty ?? false) ? p.name! : 'Printer',
        address: p.address ?? '',
        connection: p.connectionType == ConnectionType.USB
            ? PrinterConnection.usb
            : PrinterConnection.bluetooth,
        isConnected: p.isConnected ?? false,
        vendorId: p.vendorId,
        productId: p.productId,
      );

  Printer _toPrinter(PrinterDevice d) => Printer(
        name: d.name,
        address: d.address,
        connectionType: d.connection == PrinterConnection.usb
            ? ConnectionType.USB
            : ConnectionType.BLE,
        vendorId: d.vendorId,
        productId: d.productId,
      );

  // ── Cetak ─────────────────────────────────────────────────────────────────
  @override
  Future<void> printOrder(PrinterDevice device, Order order,
      {int paperSize = 80}) async {
    final bytes = await buildReceiptBytes(order, paperSize: paperSize);

    // Android + Bluetooth → Bluetooth Classic (SPP) lewat blue_thermal_printer.
    if (Platform.isAndroid &&
        device.connection == PrinterConnection.bluetooth) {
      await _printClassicBluetooth(device, bytes);
      return;
    }

    // Windows (USB / BLE) → flutter_thermal_printer.
    final printer = _toPrinter(device);

    // Untuk BLE perlu koneksi dulu; untuk USB Windows connect() bernilai true
    // tanpa aksi. Bila gagal terhubung, lempar error yang jelas ke UI.
    final connected = await _plugin.connect(printer);
    if (!connected) {
      throw Exception(
          'Gagal terhubung ke printer "${device.name}". Pastikan printer menyala dan berada dalam jangkauan.');
    }

    try {
      await _plugin.printData(printer, bytes, longData: true);
      // Beri jeda agar data sempat terkirim sebelum koneksi diputus.
      await Future.delayed(const Duration(milliseconds: 600));
    } finally {
      await _plugin.disconnect(printer);
    }
  }

  // Cetak lewat Bluetooth Classic (SPP): connect → tunggu soket siap → tulis
  // byte ESC/POS → jeda agar terkirim penuh → disconnect.
  Future<void> _printClassicBluetooth(
      PrinterDevice device, Uint8List bytes) async {
    final target = blue_thermal.BluetoothDevice(device.name, device.address);

    // Pastikan tidak ada koneksi lama yang menggantung sebelum menyambung baru.
    if (await _bt.isConnected ?? false) {
      await _bt.disconnect();
      await Future.delayed(const Duration(milliseconds: 200));
    }

    try {
      await _bt.connect(target);
    } catch (_) {
      throw Exception(
          'Gagal terhubung ke printer "${device.name}". Pastikan printer menyala, sudah dipasangkan (paired) di Pengaturan Bluetooth, dan berada dalam jangkauan.');
    }

    // Beri jeda agar soket SPP benar-benar siap sebelum menulis.
    await Future.delayed(const Duration(milliseconds: 400));
    if (!(await _bt.isConnected ?? false)) {
      throw Exception(
          'Koneksi ke printer "${device.name}" terputus sebelum mencetak.');
    }

    try {
      await _bt.writeBytes(bytes);
      // Jeda agar seluruh data ESC/POS terkirim sebelum koneksi diputus.
      await Future.delayed(const Duration(milliseconds: 800));
    } finally {
      await _bt.disconnect();
    }
  }

  @override
  Future<void> printToSavedDefault(Order order, {int paperSize = 80}) async {
    final device = await loadDefaultPrinter();
    if (device == null) {
      throw Exception('Belum ada printer default yang tersimpan.');
    }
    await printOrder(device, order, paperSize: paperSize);
  }

  // ── Printer default ────────────────────────────────────────────────────────
  @override
  Future<void> saveDefaultPrinter(PrinterDevice device) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kDefaultPrinterKey, jsonEncode(device.toJson()));
  }

  @override
  Future<PrinterDevice?> loadDefaultPrinter() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kDefaultPrinterKey);
    if (raw == null) return null;
    try {
      return PrinterDevice.fromJson(
          jsonDecode(raw) as Map<String, dynamic>);
    } catch (e) {
      if (kDebugMode) print('loadDefaultPrinter parse failed: $e');
      return null;
    }
  }

  // ── Penyusun struk (ESC/POS) — dipertahankan dari implementasi sebelumnya ──
  @override
  Future<Uint8List> buildReceiptBytes(Order order, {int paperSize = 80}) async {
    final receipt = await ReceiptSettings.load();
    final profile = await CapabilityProfile.load();
    final generator =
        Generator(paperSize == 58 ? PaperSize.mm58 : PaperSize.mm80, profile);
    final List<int> bytes = [];

    bytes.addAll(generator.setStyles(const PosStyles(align: PosAlign.center)));
    bytes.addAll(generator.text(receipt.storeName,
        styles: const PosStyles(
            align: PosAlign.center, bold: true, height: PosTextSize.size2)));
    if (receipt.storeAddress.isNotEmpty) {
      bytes.addAll(generator.text(receipt.storeAddress,
          styles: const PosStyles(align: PosAlign.center)));
    }
    if (receipt.storePhone.isNotEmpty) {
      bytes.addAll(generator.text('Telp: ${receipt.storePhone}',
          styles: const PosStyles(align: PosAlign.center)));
    }
    bytes.addAll(generator.hr());

    bytes.addAll(generator.text('No: ${order.id?.substring(0, 8) ?? 'N/A'}',
        styles: const PosStyles(align: PosAlign.left)));
    final DateTime created = (order.createdAt ?? order.date).toDate();
    bytes.addAll(generator
        .text('Tanggal: ${DateFormat('dd/MM/yy HH:mm').format(created)}'));
    if (order.kasir.isNotEmpty && order.kasir != 'N/A') {
      bytes.addAll(generator.text('Kasir: ${order.kasir}'));
    }
    if (order.customer != null && order.customer!.isNotEmpty) {
      bytes.addAll(generator.text('Customer: ${order.customer!}'));
    }
    bytes.addAll(generator.hr());

    for (var item in order.products) {
      final itemName = item['name']?.toString() ?? '';
      final qty = (item['quantity'] as num?)?.toInt() ?? 0;
      final price = (item['price'] as num?)?.toDouble() ?? 0;
      final total = qty * price;
      final originalPrice = (item['originalPrice'] as num?)?.toDouble();
      final hasDiscount = originalPrice != null && originalPrice > price;

      bytes.addAll(generator.text(itemName));

      bytes.addAll(generator.row([
        PosColumn(
            text: '$qty x ${currencyFormatter.format(price)}',
            width: 6,
            styles: const PosStyles(align: PosAlign.left)),
        PosColumn(
            text: currencyFormatter.format(total),
            width: 6,
            styles: const PosStyles(align: PosAlign.right)),
      ]));

      if (hasDiscount) {
        bytes.addAll(generator.text(
            '(Harga Sblm Diskon: ${currencyFormatter.format(originalPrice)})',
            styles: const PosStyles(align: PosAlign.left, reverse: true)));
      }
    }

    bytes.addAll(generator.hr());

    bytes.addAll(generator.row([
      PosColumn(text: 'Subtotal', width: 6),
      PosColumn(
          text: currencyFormatter.format(order.subtotal),
          width: 6,
          styles: const PosStyles(align: PosAlign.right)),
    ]));

    bytes.addAll(generator.row([
      PosColumn(text: 'Total Diskon', width: 6),
      PosColumn(
          text: currencyFormatter.format(order.totalDiscount),
          width: 6,
          styles: const PosStyles(align: PosAlign.right)),
    ]));

    // Hanya pesanan marketplace yang punya baris-baris ini.
    void feeRow(String label, num? value) {
      if ((value ?? 0) <= 0) return;
      bytes.addAll(generator.row([
        PosColumn(text: label, width: 6),
        PosColumn(
            text: currencyFormatter.format(value),
            width: 6,
            styles: const PosStyles(align: PosAlign.right)),
      ]));
    }

    feeRow('Ongkir', order.shippingFee);
    feeRow('Biaya Admin', order.adminFee);
    feeRow('Biaya Layanan', order.serviceFee);

    bytes.addAll(generator.row([
      PosColumn(text: 'Total', width: 6, styles: const PosStyles(bold: true)),
      PosColumn(
          text: currencyFormatter.format(order.total),
          width: 6,
          styles: const PosStyles(align: PosAlign.right, bold: true)),
    ]));

    bytes.addAll(generator.hr());
    bytes.addAll(generator.text('Terima Kasih!',
        styles: const PosStyles(align: PosAlign.center)));
    if (receipt.footerNote.isNotEmpty) {
      bytes.addAll(generator.text(receipt.footerNote,
          styles: const PosStyles(align: PosAlign.center)));
    }

    bytes.addAll(generator.feed(2));
    bytes.addAll(generator.cut());

    return Uint8List.fromList(bytes);
  }

  // ignore: unused_element
  void dispose() {
    _pluginSub?.cancel();
    _devicesController.close();
  }
}

PrintingService getPrintingService() => _PrintingServiceImpl();
