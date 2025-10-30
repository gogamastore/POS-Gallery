import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:thermal_printer/thermal_printer.dart' as tp;

import '../models/order.dart';
import 'printing_service.dart';
import 'device_utils.dart';

class _PrintingServiceImpl implements PrintingService {
  final currencyFormatter =
      NumberFormat.currency(locale: 'id_ID', symbol: '', decimalDigits: 0);

  final _scanResultsController = StreamController<List<dynamic>>.broadcast();
  @override
  Stream<List<dynamic>> get scanResults => _scanResultsController.stream;

  final tp.PrinterManager _printerManager = tp.PrinterManager.instance;
  StreamSubscription<dynamic>? _discoverySub;
  final List<dynamic> _foundDevices = [];

  _PrintingServiceImpl();

  @override
  Stream<int?> get connectionStatus =>
      _printerManager.stateBluetooth.map((s) => s.index);

  @override
  Future<String> getBleAvailability() async {
    return 'not_supported_by_thermal_printer_lib';
  }

  @override
  Future<void> enableBle() async {
    if (kDebugMode) {
      print('enableBle is not supported in this implementation.');
    }
  }

  @override
  void startScan({bool isBle = false}) {
    _discoverySub?.cancel();
    _foundDevices.clear();
    if (!_scanResultsController.isClosed) {
      _scanResultsController.add([]);
    }

    try {
      _discoverySub = _printerManager
          .discovery(type: tp.PrinterType.bluetooth, isBle: isBle)
          .listen((device) {
        final devKey = getDeviceAddress(device);
        if (!_foundDevices.any((d) => getDeviceAddress(d) == devKey)) {
          _foundDevices.add(device);
          if (!_scanResultsController.isClosed) {
            _scanResultsController.add(List<dynamic>.from(_foundDevices));
          }
        }
      });
    } catch (e) {
      if (kDebugMode) {
        print('startScan failed: $e');
      }
    }
  }

  @override
  void stopScan() {
    _discoverySub?.cancel();
  }

  @override
  Future<void> connectToDevice(dynamic device, {bool isBle = false}) async {
    final prefs = await SharedPreferences.getInstance();
    final typeStr = prefs.getString('printer_connection_type') ?? 'bluetooth';
    final type = typeStr == 'usb' ? tp.PrinterType.usb : tp.PrinterType.bluetooth;

    try {
      await _printerManager.connect(
        type: type,
        model: device,
      );
    } catch (e) {
      if (kDebugMode) {
        print('connectToDevice failed: $e');
      }
      rethrow;
    }
  }

  @override
  Future<void> disconnect() async {
    final prefs = await SharedPreferences.getInstance();
    final typeStr = prefs.getString('printer_connection_type') ?? 'bluetooth';
    final type = typeStr == 'usb' ? tp.PrinterType.usb : tp.PrinterType.bluetooth;
    try {
      await _printerManager.disconnect(type: type);
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
        // ESC/POS typically doesn't support strike-through; display previous price as note
        bytes.addAll(generator.text(
            '(Harga Sebelum Diskon: ${currencyFormatter.format(originalPrice)})',
            styles: const PosStyles(align: PosAlign.left)));
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
      PosColumn(text: 'Todal Discount', width: 6),
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
    final prefs = await SharedPreferences.getInstance();
    final typeStr = prefs.getString('printer_connection_type') ?? 'bluetooth';
    final type = typeStr == 'usb' ? tp.PrinterType.usb : tp.PrinterType.bluetooth;

    try {
      await _printerManager.send(type: type, bytes: bytes);
    } catch (e) {
      if (kDebugMode) {
        print('sendBytesToPrinter failed: $e');
      }
      rethrow;
    }
  }

  @override
  Future<List<dynamic>> scanUsbDevices(
      {Duration timeout = const Duration(seconds: 5)}) async {
    final List<dynamic> devices = <dynamic>[];
    try {
      final sub = _printerManager.discovery(type: tp.PrinterType.usb).listen((d) {
        try {
          final key = getDeviceAddress(d);
          if (!devices.any((x) => getDeviceAddress(x) == key)) {
            devices.add(d);
          }
        } catch (_) {
          devices.add(d);
        }
      }, onError: (e) {
        if (kDebugMode) print('discovery error: $e');
      });

      await Future.delayed(timeout);
      await sub.cancel();

      final List<dynamic> wrapped = <dynamic>[];
      for (final d in devices) {
        final online = await isUsbDeviceOnline(d);
        wrapped.add({'device': d, 'online': online});
      }
      return wrapped;
    } catch (e) {
      if (kDebugMode) print('scanUsbDevices failed: $e');
      return devices.map((d) => {'device': d, 'online': false}).toList();
    }
  }

  @override
  Future<bool> isUsbDeviceOnline(dynamic device) async {
    // Best-effort check: attempt to connect and disconnect quickly.
    try {
      await _printerManager.connect(type: tp.PrinterType.usb, model: device);
      await _printerManager.disconnect(type: tp.PrinterType.usb);
      return true;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<bool> pairUsbDevice(dynamic device) async {
    String? read(dynamic obj, List<String> keys) {
      if (obj == null) return null;
      try {
        if (obj is Map) {
          for (final k in keys) {
            if (obj.containsKey(k) && obj[k] != null) return obj[k].toString();
          }
        } else {
          final dyn = obj as dynamic;
          for (final k in keys) {
            try {
              final val = dyn as dynamic;
              switch (k) {
                case 'name':
                  if (val.name != null) return val.name.toString();
                  break;
                case 'productId':
                  if (val.productId != null) return val.productId.toString();
                  break;
                case 'vendorId':
                  if (val.vendorId != null) return val.vendorId.toString();
                  break;
                case 'address':
                  if (val.address != null) return val.address.toString();
                  break;
              }
            } catch (_) {}
          }
        }
      } catch (_) {}
      return null;
    }

    try {
      if (kDebugMode) print('pairUsbDevice input: type=${device.runtimeType}, value=$device');

      final name = read(device, ['name', 'productName', 'deviceName']) ?? '';
      final pid = read(device, ['productId', 'productid', 'pid']);
      final vid = read(device, ['vendorId', 'vendorid', 'vid']);

      if (kDebugMode) print('pairUsbDevice resolved: name=$name pid=$pid vid=$vid');

      // First try connecting using the original discovered device object.
      try {
        final connectedOriginal = await _printerManager.connect(type: tp.PrinterType.usb, model: device);
        if (connectedOriginal) {
          await _printerManager.disconnect(type: tp.PrinterType.usb);
          return true;
        }
      } catch (e) {
        if (kDebugMode) print('connect with original device failed: $e');
      }

      // If original connect did not work and we have pid/vid, try UsbPrinterInput model
      if (pid != null || vid != null) {
        final usbModel = tp.UsbPrinterInput(name: name, productId: pid, vendorId: vid);
        try {
          final connected = await _printerManager.connect(type: tp.PrinterType.usb, model: usbModel);
          if (connected) {
            await _printerManager.disconnect(type: tp.PrinterType.usb);
            return true;
          }
        } catch (e) {
          if (kDebugMode) print('connect with UsbPrinterInput failed: $e');
        }
      }

      // As a last resort, try UsbPrinterInput with name/address (even if pid/vid missing)
      final fallbackUsb = tp.UsbPrinterInput(
        name: name,
        productId: pid,
        vendorId: vid,
      );
      try {
        final connectedFallback = await _printerManager.connect(type: tp.PrinterType.usb, model: fallbackUsb);
        if (connectedFallback) {
          await _printerManager.disconnect(type: tp.PrinterType.usb);
          return true;
        }
      } catch (e) {
        if (kDebugMode) print('connect with fallback UsbPrinterInput failed: $e');
      }

      return false;
    } catch (e) {
      if (kDebugMode) {
        print('pairUsbDevice failed: $e');
      }
      return false;
    }
  }

  @override
  Future<void> printReceipt(Order order, {int paperSize = 80}) async {
    final bytes = await buildReceiptBytes(order, paperSize: paperSize);
    await sendBytesToPrinter(bytes.toList());
  }

  // These methods are no longer needed
  Future<bool> discoverAndSaveWriteCharacteristic(dynamic device) async => false;

  Future<bool> writeUsingSavedUuid(dynamic device, Uint8List bytes) async => false;

  @override
  Future<void> connectToSavedDefault() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final address = prefs.getString('default_printer_address');
      final name = prefs.getString('default_printer_name');
      if (address == null && name == null) return;

      // Attempt to find device from discovered list
      try {
        final devices = await _printerManager.discovery(type: tp.PrinterType.usb).toList();
        dynamic match;
        for (final d in devices) {
          final dName = getDeviceName(d);
          final dAddr = getDeviceAddress(d);
          if ((address != null && dAddr == address) || (name != null && dName == name)) {
            match = d;
            break;
          }
        }
        if (match != null) {
          await connectToDevice(match, isBle: false);
          return;
        }
      } catch (e) {
        if (kDebugMode) print('Error finding saved default in discovery: $e');
      }

      // If not found via discovery, try connecting via UsbPrinterInput built from saved values
      try {
        final usbModel = tp.UsbPrinterInput(name: name ?? '', productId: null, vendorId: null);
        await _printerManager.connect(type: tp.PrinterType.usb, model: usbModel);
      } catch (e) {
        if (kDebugMode) print('connectToSavedDefault failed: $e');
      }
    } catch (e) {
      if (kDebugMode) print('connectToSavedDefault: $e');
    }
  }
}

PrintingService getPrintingService() => _PrintingServiceImpl();
