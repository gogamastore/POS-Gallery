import 'dart:typed_data';

import 'package:myapp/models/order.dart';

// Only export the factory function, not the implementation classes.
export 'thermal_printer_stub.dart'
    if (dart.library.io) 'thermal_printer_real.dart' show getPrintingService;

/// Abstract interface for the printing service.
/// This allows the UI to depend on a contract rather than a concrete implementation,
/// and allows for conditional (stub/real) implementations for web vs. mobile.
abstract class PrintingService {
  Stream<int?> get connectionStatus;
  Stream<List<dynamic>> get scanResults;

  Future<String> getBleAvailability();
  Future<void> enableBle();

  void startScan({bool isBle = false});
  void stopScan();

  Future<void> connectToDevice(dynamic device, {bool isBle = false});
  Future<void> disconnect();

  Future<Uint8List> buildReceiptBytes(Order order, {int paperSize = 80});
  Future<void> sendBytesToPrinter(List<int> bytes);
  Future<void> printReceipt(Order order, {int paperSize = 80});

  Future<List<dynamic>> scanUsbDevices(
      {Duration timeout = const Duration(seconds: 5)});
  Future<bool> pairUsbDevice(dynamic device);
  Future<bool> isUsbDeviceOnline(dynamic device);
  Future<void> connectToSavedDefault();
}
