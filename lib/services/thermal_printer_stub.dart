import 'dart:async';
import 'dart:typed_data';
import 'package:myapp/models/order.dart';
import 'printing_service.dart';

// Stub implementation for web or unsupported platforms.
class _PrintingServiceStub implements PrintingService {
  @override
  Stream<int?> get connectionStatus => Stream.value(null);

  @override
  Stream<List<dynamic>> get scanResults => Stream.value([]);

  @override
  Future<List<dynamic>> getBondedDevices() async => []; // Return empty list

  @override
  Future<String> getBleAvailability() async => 'not_available';

  @override
  Future<void> enableBle() async {}

  @override
  void startScan({bool isBle = false}) {}

  @override
  void stopScan() {}

  @override
  Future<void> connectToDevice(dynamic device, {bool isBle = false}) async {}

  @override
  Future<void> disconnect() async {}

  @override
  Future<Uint8List> buildReceiptBytes(Order order, {int paperSize = 80}) async {
    // Return an empty byte array as a placeholder.
    return Uint8List(0);
  }

  @override
  Future<void> sendBytesToPrinter(List<int> bytes) async {}

  @override
  Future<void> printReceipt(Order order, {int paperSize = 80}) async {}

  @override
  Future<List<dynamic>> scanUsbDevices(
      {Duration timeout = const Duration(seconds: 2)}) async =>
      [];

  @override
  Future<bool> isUsbDeviceOnline(dynamic device) async => false;

  @override
  Future<bool> pairUsbDevice(dynamic device) async => false;

  @override
  Future<void> connectToSavedDefault() async {}
}

PrintingService getPrintingService() => _PrintingServiceStub();
