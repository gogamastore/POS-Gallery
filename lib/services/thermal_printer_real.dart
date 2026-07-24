import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
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

const _kDefaultPrinterKey = 'default_printer_json';

// Implementasi asli memakai flutter_thermal_printer (universal_ble untuk BLE
// di Android & Windows, Win32 spooler untuk USB di Windows).
class _PrintingServiceImpl implements PrintingService {
  final FlutterThermalPrinter _plugin = FlutterThermalPrinter.instance;
  final currencyFormatter =
      NumberFormat.currency(locale: 'id_ID', symbol: '', decimalDigits: 0);

  final _devicesController =
      StreamController<List<PrinterDevice>>.broadcast();
  StreamSubscription? _pluginSub;

  _PrintingServiceImpl() {
    // Terjemahkan daftar Printer milik paket menjadi model netral kita.
    _pluginSub = _plugin.devicesStream.listen((printers) {
      if (_devicesController.isClosed) return;
      _devicesController.add(printers.map(_toDevice).toList());
    });
  }

  @override
  bool get supportsUsb => Platform.isWindows;

  @override
  Stream<List<PrinterDevice>> get devicesStream => _devicesController.stream;

  @override
  Future<void> startDiscovery(
      {bool bluetooth = true, bool usb = false}) async {
    final types = <ConnectionType>[];
    if (bluetooth) types.add(ConnectionType.BLE);
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

  @override
  Future<void> stopDiscovery() async {
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
    final printer = _toPrinter(device);
    final bytes = await buildReceiptBytes(order, paperSize: paperSize);

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
    final profile = await CapabilityProfile.load();
    final generator =
        Generator(paperSize == 58 ? PaperSize.mm58 : PaperSize.mm80, profile);
    final List<int> bytes = [];

    bytes.addAll(generator.setStyles(const PosStyles(align: PosAlign.center)));
    bytes.addAll(generator.text('GALLERY MAKASSAR',
        styles: const PosStyles(
            align: PosAlign.center, bold: true, height: PosTextSize.size2)));
    bytes.addAll(generator.text('Jl. Borong Raya No. 100',
        styles: const PosStyles(align: PosAlign.center)));
    bytes.addAll(generator.text('Telp: 0895635299075',
        styles: const PosStyles(align: PosAlign.center)));
    bytes.addAll(generator.hr());

    bytes.addAll(generator.text('No: ${order.id?.substring(0, 8) ?? 'N/A'}',
        styles: const PosStyles(align: PosAlign.left)));
    final DateTime created = (order.createdAt ?? order.date).toDate();
    bytes.addAll(generator
        .text('Tanggal: ${DateFormat('dd/MM/yy HH:mm').format(created)}'));
    bytes.addAll(generator.text('Kasir: ${order.kasir}'));
    if (order.customer != null && order.customer!.isNotEmpty) {
      bytes.addAll(generator.text('Customer: ${order.customer!}'));
    }
    bytes.addAll(generator.hr());

    for (var item in order.products) {
      final itemName = item['name'] as String;
      final qty = item['quantity'] as int;
      final price = (item['price'] as num).toDouble();
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
    bytes.addAll(generator.text(
        'Barang yang sudah dibeli tidak dapat dikembalikan.',
        styles: const PosStyles(align: PosAlign.center)));

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
