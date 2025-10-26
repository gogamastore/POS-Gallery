import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';

import '../models/order.dart';

/// NOTE: This file provides ESC/POS byte generation and a minimal BLE stub.
/// The previous attempts to call the `bluetooth_low_energy` package caused
/// compile errors on some platforms because the package API differs and the
/// import prefix cannot be used as an expression. To keep the project
/// buildable, BLE operations are currently no-ops or best-effort when the
/// `device` object itself exposes write methods. Replace these stubs with
/// concrete calls to your BLE library if needed.
class PrintingService {
  final currencyFormatter =
      NumberFormat.currency(locale: 'id_ID', symbol: '', decimalDigits: 0);

  final _scanResultsController = StreamController<List<dynamic>>.broadcast();
  Stream<List<dynamic>> get scanResults => _scanResultsController.stream;

  Stream<int?> get connectionStatus => const Stream.empty();

  void startScan({Duration timeout = const Duration(seconds: 4)}) {
    // Stub: emit empty list after timeout
    Future.delayed(timeout, () {
      if (!_scanResultsController.isClosed) _scanResultsController.add([]);
    });
  }

  void stopScan() {
    // stub
  }

  Future<void> connectToDevice(dynamic device) async {
    // stub: do nothing; real connection must be implemented using
    // the project's chosen BLE package and appropriate platform code.
    await Future.value();
  }

  Future<void> disconnect() async {
    // stub
    await Future.value();
  }

  Future<Uint8List> buildReceiptBytes(Order order, {int paperSize = 80}) async {
    final profile = await CapabilityProfile.load();
    final Generator generator = Generator(
      paperSize == 58 ? PaperSize.mm58 : PaperSize.mm80,
      profile,
    );

    generator.setStyles(PosStyles(align: PosAlign.center));
    generator.text('GALLERY MAKASSAR',
        styles: PosStyles(bold: true, height: PosTextSize.size2));
    generator.text('Jl. Sultan Alauddin No. 27');
    generator.text('Telp: 0812-xxxx-xxxx');
    generator.hr();

    generator.text('No: ${order.id?.substring(0, 8) ?? 'N/A'}',
        styles: PosStyles(align: PosAlign.left));
    generator.text(
        'Tanggal: ${DateFormat('dd/MM/yy HH:mm').format(order.createdAt!.toDate())}');
    generator.text('Kasir: ${order.kasir}');
    if (order.customer != null && order.customer!.isNotEmpty) {
      generator.text('Customer: ${order.customer!}');
    }
    generator.hr();

    for (var item in order.products) {
      final itemName = item['name'] as String;
      final qty = item['quantity'] as int;
      final price = (item['price'] as num).toDouble();
      final total = qty * price;

      generator.text(itemName);

      generator.row([
        PosColumn(
            text: '$qty x ${currencyFormatter.format(price)}',
            width: 6,
            styles: PosStyles(align: PosAlign.left)),
        PosColumn(
            text: currencyFormatter.format(total),
            width: 6,
            styles: PosStyles(align: PosAlign.right)),
      ]);
    }

    generator.hr();

    generator.row([
      PosColumn(text: 'Subtotal', width: 6),
      PosColumn(
          text: currencyFormatter.format(order.subtotal),
          width: 6,
          styles: PosStyles(align: PosAlign.right)),
    ]);

    generator.row([
      PosColumn(text: 'Total', width: 6, styles: PosStyles(bold: true)),
      PosColumn(
          text: currencyFormatter.format(order.total),
          width: 6,
          styles: PosStyles(align: PosAlign.right, bold: true)),
    ]);

    generator.hr();
    generator.text('Terima Kasih!', styles: PosStyles(align: PosAlign.center));
    generator.text('Barang yang sudah dibeli tidak dapat dikembalikan.',
        styles: PosStyles(align: PosAlign.center));

    generator.feed(2);
    generator.cut();

    // try to obtain bytes from generator in a safe way
    try {
      // many versions expose `generator.bytes`
      final List<int> bytes = (generator as dynamic).bytes as List<int>;
      return Uint8List.fromList(bytes);
    } catch (_) {
      try {
        // fallback: some versions provide `generator.getBytes()`
        final List<int> bytes = await (generator as dynamic).getBytes();
        return Uint8List.fromList(bytes);
      } catch (_) {
        // last resort: call `commands` and encode
        try {
          final List<int> bytes = (generator as dynamic).commands as List<int>;
          return Uint8List.fromList(bytes);
        } catch (e) {
          if (kDebugMode) print('Unable to extract bytes from generator: $e');
          return Uint8List.fromList([]);
        }
      }
    }
  }

  /// Discovery currently not implemented without a concrete BLE library.
  Future<bool> discoverAndSaveWriteCharacteristic(dynamic device) async {
    // stub: not implemented
    return false;
  }

  Future<bool> writeUsingSavedUuid(dynamic device, Uint8List bytes) async {
    // stub: not implemented
    return false;
  }

  Future<void> printReceipt(Order order,
      {int paperSize = 80,
      required Future<void> Function(Uint8List) writeBytes}) async {
    final bytes = await buildReceiptBytes(order, paperSize: paperSize);
    await writeBytes(bytes);
  }
}
