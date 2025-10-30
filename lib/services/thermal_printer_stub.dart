import 'dart:async';
import 'dart:typed_data';
import 'package:myapp/models/order.dart';
import 'printing_service.dart';

// Stub implementation for web
class _PrintingServiceImpl implements PrintingService {
  @override
  Stream<List<dynamic>> get scanResults => const Stream.empty();

  @override
  Stream<int?> get connectionStatus => const Stream.empty();

  @override
  Future<String> getBleAvailability() async => 'not_available_on_web';

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
    // This could be implemented for web preview if needed
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
  Future<bool> pairUsbDevice(dynamic device) async => false;


  Future<bool> discoverAndSaveWriteCharacteristic(dynamic device) async =>
      false;


  Future<bool> writeUsingSavedUuid(dynamic device, Uint8List bytes) async =>
      false;

  // New methods added to the PrintingService interface
  @override
  Future<bool> isUsbDeviceOnline(dynamic device) async => false;

  @override
  Future<void> connectToSavedDefault() async {}
}

PrintingService getPrintingService() => _PrintingServiceImpl();
