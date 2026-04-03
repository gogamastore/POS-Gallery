import 'dart:async';
import 'package:blue_thermal_printer/blue_thermal_printer.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/order.dart';
import 'printing_service.dart';

// Real implementation using blue_thermal_printer
class _PrintingServiceImpl implements PrintingService {
  final BlueThermalPrinter _bluetooth = BlueThermalPrinter.instance;
  final currencyFormatter =
      NumberFormat.currency(locale: 'id_ID', symbol: '', decimalDigits: 0);

  final _scanResultsController = StreamController<List<BluetoothDevice>>.broadcast();
  final _connectionStatusController = StreamController<int?>.broadcast();

  StreamSubscription? _stateSubscription;

  _PrintingServiceImpl() {
    _stateSubscription = _bluetooth.onStateChanged().listen((state) {
      _connectionStatusController.add(state);
    });
  }

  @override
  Stream<List<dynamic>> get scanResults => _scanResultsController.stream;

  @override
  Stream<int?> get connectionStatus => _connectionStatusController.stream;

  @override
  Future<List<dynamic>> getBondedDevices() async {
    try {
      return await _bluetooth.getBondedDevices();
    } catch (e) {
      if (kDebugMode) {
        print('getBondedDevices failed: $e');
      }
      rethrow;
    }
  }

  @override
  Future<String> getBleAvailability() async {
    // blue_thermal_printer handles standard Bluetooth, not BLE scanning specifically.
    return 'not_applicable';
  }

  @override
  Future<void> enableBle() async {
     // Not needed for this library
  }

  @override
  void startScan({bool isBle = false}) {
    // blue_thermal_printer gets bonded devices, not a continuous scan.
    _bluetooth.getBondedDevices().then((devices) {
      if (!_scanResultsController.isClosed) {
        _scanResultsController.add(devices);
      }
    }).catchError((e) {
       if (kDebugMode) {
        print('getBondedDevices failed: $e');
      }
      if (!_scanResultsController.isClosed) {
        _scanResultsController.addError(e);
      }
    });
  }

  @override
  void stopScan() {
    // Not applicable as getBondedDevices is a one-time call.
  }

  @override
  Future<void> connectToDevice(dynamic device, {bool isBle = false}) async {
    if (device is BluetoothDevice) {
      try {
        await _bluetooth.connect(device);
      } catch (e) {
        if (kDebugMode) {
          print('connectToDevice failed: $e');
        }
        rethrow;
      }
    }
  }

  @override
  Future<void> disconnect() async {
    try {
      await _bluetooth.disconnect();
    } catch (e) {
       if (kDebugMode) {
        print('disconnect failed: $e');
      }
    }
  }

  @override
  Future<Uint8List> buildReceiptBytes(Order order, {int paperSize = 80}) async {
    final profile = await CapabilityProfile.load();
    final generator =
        Generator(paperSize == 58 ? PaperSize.mm58 : PaperSize.mm80, profile);
    final List<int> bytes = [];

    bytes.addAll(generator.setStyles(const PosStyles(align: PosAlign.center)));
    bytes.addAll(generator.text('GALLERY MAKASSAR',
        styles: const PosStyles(align: PosAlign.center, bold: true, height: PosTextSize.size2)));
    bytes.addAll(generator.text('Jl. Borong Raya No. 100', styles: const PosStyles(align: PosAlign.center)));
    bytes.addAll(generator.text('Telp: 0895635299075', styles: const PosStyles(align: PosAlign.center)));
    bytes.addAll(generator.hr());

    bytes.addAll(generator.text('No: ${order.id?.substring(0, 8) ?? 'N/A'}',
        styles: const PosStyles(align: PosAlign.left)));
    final DateTime created = (order.createdAt ?? order.date).toDate();
    bytes.addAll(generator.text('Tanggal: ${DateFormat('dd/MM/yy HH:mm').format(created)}'));
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
    bytes.addAll(generator.text('Terima Kasih!', styles: const PosStyles(align: PosAlign.center)));
    bytes.addAll(generator.text('Barang yang sudah dibeli tidak dapat dikembalikan.',
        styles: const PosStyles(align: PosAlign.center)));

    bytes.addAll(generator.feed(2));
    bytes.addAll(generator.cut());

    return Uint8List.fromList(bytes);
  }

  @override
  Future<void> sendBytesToPrinter(List<int> bytes) async {
    try {
      await _bluetooth.writeBytes(Uint8List.fromList(bytes));
    } catch (e) {
      if (kDebugMode) {
        print('sendBytesToPrinter failed: $e');
      }
      rethrow;
    }
  }

  @override
  Future<void> printReceipt(Order order, {int paperSize = 80}) async {
    final bytes = await buildReceiptBytes(order, paperSize: paperSize);
    await sendBytesToPrinter(bytes);
  }

  @override
  Future<void> connectToSavedDefault() async {
    final prefs = await SharedPreferences.getInstance();
    final address = prefs.getString('default_printer_address');
    if (address == null) return;

    try {
      final devices = await _bluetooth.getBondedDevices();
      final match = devices.firstWhere((d) => d.address == address, orElse: () => throw Exception('Device not found'));
      await connectToDevice(match);
    } catch (e) {
      if (kDebugMode) {
        print('connectToSavedDefault failed: $e');
      }
    }
  }

  // --- USB Methods are NOT SUPPORTED by blue_thermal_printer ---
  // --- They are kept for interface compatibility but do nothing. ---

  @override
  Future<List<dynamic>> scanUsbDevices(
      {Duration timeout = const Duration(seconds: 2)}) async {
    if (kDebugMode) {
      print('scanUsbDevices is not supported in this implementation.');
    }
    return [];
  }

  @override
  Future<bool> isUsbDeviceOnline(dynamic device) async {
    if (kDebugMode) {
      print('isUsbDeviceOnline is not supported in this implementation.');
    }
    return false;
  }

  @override
  Future<bool> pairUsbDevice(dynamic device) async {
    if (kDebugMode) {
      print('pairUsbDevice is not supported in this implementation.');
    }
    return false;
  }

  void dispose() {
    _scanResultsController.close();
    _connectionStatusController.close();
    _stateSubscription?.cancel();
  }
}

PrintingService getPrintingService() => _PrintingServiceImpl();
