import 'dart:typed_data';

import 'package:myapp/models/order.dart';

import 'printing_service.dart';

// Stub untuk web / platform tanpa dukungan printer. Semua operasi no-op.
class _PrintingServiceStub implements PrintingService {
  @override
  bool get supportsUsb => false;

  @override
  Stream<List<PrinterDevice>> get devicesStream =>
      const Stream<List<PrinterDevice>>.empty();

  @override
  Future<void> startDiscovery({bool bluetooth = true, bool usb = false}) async {}

  @override
  Future<void> stopDiscovery() async {}

  @override
  Future<Uint8List> buildReceiptBytes(Order order, {int paperSize = 80}) async =>
      Uint8List(0);

  @override
  Future<void> printOrder(PrinterDevice device, Order order,
      {int paperSize = 80}) async {}

  @override
  Future<void> printToSavedDefault(Order order, {int paperSize = 80}) async {}

  @override
  Future<void> saveDefaultPrinter(PrinterDevice device) async {}

  @override
  Future<PrinterDevice?> loadDefaultPrinter() async => null;
}

PrintingService getPrintingService() => _PrintingServiceStub();
