import 'dart:async';
import 'dart:developer' as developer;
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:ionicons/ionicons.dart';
import 'package:myapp/models/order.dart';
import 'package:myapp/screens/main_tab_controller.dart';
import 'package:myapp/services/printing_service.dart';
import 'package:myapp/utils/pdf_invoice_exporter.dart';
import 'package:printing/printing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:universal_html/html.dart' as html;
import 'package:thermal_printer/thermal_printer.dart' as tp;

class PrintPageScreen extends ConsumerStatefulWidget {
  final Order order;

  const PrintPageScreen({super.key, required this.order});

  @override
  ConsumerState<PrintPageScreen> createState() => _PrintPageScreenState();
}

class _PrintPageScreenState extends ConsumerState<PrintPageScreen> {
  final PrintingService _printingService = getPrintingService();

  Future<void> _downloadReceipt(BuildContext context) async {
    try {
      final exporter = PdfInvoiceExporter();
      final Uint8List pdfBytes = await exporter.exportInvoice(widget.order);

      if (kIsWeb) {
        final blob = html.Blob([pdfBytes], 'application/pdf');
        final url = html.Url.createObjectUrlFromBlob(blob);
        final anchor = html.document.createElement('a') as html.AnchorElement
          ..href = url
          ..style.display = 'none'
          ..download = 'struk-pembelian-${widget.order.id}.pdf';
        html.document.body?.children.add(anchor);
        anchor.click();
        html.document.body?.children.remove(anchor);
        html.Url.revokeObjectUrl(url);
      } else {
        await Printing.sharePdf(
            bytes: pdfBytes,
            filename: 'struk-pembelian-${widget.order.id}.pdf');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal mengunduh struk: $e')),
        );
      }
    }
  }

  Future<void> _handlePrint() async {
    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Dialog(
        child: Padding(
          padding: EdgeInsets.all(20.0),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 20),
              Text('Mempersiapkan struk...'),
            ],
          ),
        ),
      ),
    );

    try {
      final prefs = await SharedPreferences.getInstance();
      final address = prefs.getString('default_printer_address');
      final name = prefs.getString('default_printer_name');
      final connType =
          prefs.getString('printer_connection_type') ?? 'bluetooth';
      final isBle = connType == 'bluetooth_le';

      dynamic device;
      if (address != null && name != null) {
        if (connType == 'usb') {
          device =
              tp.UsbPrinterInput(name: name, productId: null, vendorId: null);
        } else {
          device = tp.BluetoothPrinterInput(
              name: name, address: address, isBle: isBle);
        }
      }

      if (mounted) Navigator.of(context, rootNavigator: true).pop();

      if (device == null) {
        final selectedDevice = await showDialog<dynamic>(
          context: context,
          builder: (dialogContext) => _BluetoothDeviceDialog(),
        );

        if (selectedDevice == null) return;
        device = selectedDevice;
      }

      await _printWithDevice(device);
    } catch (e, s) {
      developer.log('Error preparing for print: $e', stackTrace: s);
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal mempersiapkan print: $e')),
        );
      }
    }
  }

  Future<void> _printWithDevice(dynamic device) async {
    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Dialog(
        child: Padding(
          padding: EdgeInsets.all(20.0),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 20),
              Text('Mencetak...'),
            ],
          ),
        ),
      ),
    );

    try {
      await _printingService.connectToDevice(device);
      await _printingService.printReceipt(widget.order);
      await _printingService.disconnect();

      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Struk berhasil dikirim ke printer.')),
        );
      }
    } catch (e, s) {
      developer.log('Error printing: $e', stackTrace: s);
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saat mencetak: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currencyFormatter =
        NumberFormat.currency(locale: 'id_ID', symbol: '', decimalDigits: 0);
    const textStyle = TextStyle(fontFamily: 'monospace', color: Colors.black);
    const boldTextStyle = TextStyle(
        fontFamily: 'monospace',
        fontWeight: FontWeight.bold,
        color: Colors.black);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Struk Pembelian'),
        automaticallyImplyLeading: false,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              // --- Receipt Container ---
              Container(
                padding: const EdgeInsets.all(16.0),
                width: 380, // Similar to 80mm paper width
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 5),
                    ),
                  ],
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                     // --- Header ---
                      Center(
                          child: Text('GALLERY MAKASSAR',
                              style: boldTextStyle.copyWith(fontSize: 18))),
                      const Center(
                          child: Text('Jl. Borong Raya No. 100',
                              style: textStyle)),
                      const Center(
                          child:
                              Text('Telp: 0895635299075', style: textStyle)),
                      const Divider(color: Colors.black),

                      // --- Order Info ---
                      Text('No: ${widget.order.id?.substring(0, 8) ?? 'N/A'}',
                          style: textStyle),
                      Text(
                          'Tanggal: ${DateFormat('dd/MM/yy HH:mm').format((widget.order.createdAt ?? widget.order.date).toDate())}',
                          style: textStyle),
                      Text('Kasir: ${widget.order.kasir}', style: textStyle),
                      if (widget.order.customer != null &&
                          widget.order.customer!.isNotEmpty)
                        Text('Customer: ${widget.order.customer!}',
                            style: textStyle),
                      const Divider(color: Colors.black),

                      // --- Product Items ---
                      for (var item in widget.order.products) ...[
                        Text(item['name'] as String, style: textStyle),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                                '  ${item['quantity']} x ${currencyFormatter.format(item['price'])}',
                                style: textStyle),
                            Text(
                                currencyFormatter
                                    .format(item['quantity'] * item['price']),
                                style: textStyle),
                          ],
                        ),
                        // show original price (before discount) if available
                        (() {
                          final orig = item['originalPrice'];
                          double? originalPrice;
                          try {
                            if (orig != null) originalPrice = (orig as num).toDouble();
                          } catch (_) {
                            originalPrice = null;
                          }

                          final price = (item['price'] as num).toDouble();
                          final hasDiscount = originalPrice != null && originalPrice > price;
                          if (hasDiscount) {
                            return Padding(
                              padding: const EdgeInsets.only(top: 2.0),
                              child: Text(
                                '(Harga Sebelum Diskon: ${currencyFormatter.format(originalPrice)})',
                                style: const TextStyle(fontSize: 10, decoration: TextDecoration.lineThrough),
                              ),
                            );
                          }
                          return const SizedBox.shrink();
                        })(),
                        const SizedBox(height: 4),
                      ],
                      const Divider(color: Colors.black),

                      // --- Totals ---
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Subtotal', style: textStyle),
                          Text(currencyFormatter.format(widget.order.subtotal),
                              style: textStyle),
                        ],
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Total Discount', style: textStyle),
                          Text(
                              currencyFormatter
                                  .format(widget.order.totalDiscount),
                              style: textStyle),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Total', style: boldTextStyle),
                          Text(currencyFormatter.format(widget.order.total),
                              style: boldTextStyle),
                        ],
                      ),
                      const Divider(color: Colors.black),

                      // --- Footer ---
                      const Center(
                          child: Text('Terima Kasih!', style: textStyle)),
                      const SizedBox(height: 4),
                      const Center(
                          child: Text(
                              'Barang yang sudah dibeli tidak dapat dikembalikan.',
                              style: textStyle,
                              textAlign: TextAlign.center)),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              // --- Action Buttons ---
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Ionicons.download_outline),
                      label: const Text('Unduh PDF'),
                      onPressed: () => _downloadReceipt(context),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        textStyle: const TextStyle(fontSize: 16),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: const Icon(Ionicons.print_outline),
                      label: const Text('Cetak'),
                      onPressed: _handlePrint,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        textStyle: const TextStyle(fontSize: 16),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                child: const Text('Selesai'),
                onPressed: () {
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (context) => const MainTabController(initialIndex: 1)),
                    (Route<dynamic> route) => false,
                  );
                },
                style: ElevatedButton.styleFrom(
                    minimumSize: const Size(200, 48),
                    textStyle: const TextStyle(fontSize: 18)),
              ),
               const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}

class _BluetoothDeviceDialog extends StatefulWidget {
  @override
  State<_BluetoothDeviceDialog> createState() => _BluetoothDeviceDialogState();
}

class _BluetoothDeviceDialogState extends State<_BluetoothDeviceDialog> {
  final PrintingService _printingService = getPrintingService();
  StreamSubscription<List<dynamic>>? _scanSubscription;
  List<dynamic> _devices = [];
  bool _isScanning = false;

  @override
  void initState() {
    super.initState();
    _startScan();
  }

  @override
  void dispose() {
    _scanSubscription?.cancel();
    _printingService.stopScan();
    super.dispose();
  }

  void _startScan() {
    if (!mounted) return;
    setState(() {
      _isScanning = true;
      _devices = [];
    });
    _printingService.startScan();
    _scanSubscription = _printingService.scanResults.listen((devices) {
      if (!mounted) return;
      setState(() {
        _devices = devices;
        _isScanning = false;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text('Pilih Printer Bluetooth'),
          if (_isScanning)
            const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2))
          else
            IconButton(
                icon: const Icon(Ionicons.refresh),
                onPressed: _startScan,
                tooltip: 'Scan Ulang')
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: _devices.isEmpty
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(
                    _isScanning
                        ? 'Mencari printer...'
                        : 'Tidak ada printer ter-pairing. Pastikan Bluetooth menyala.',
                    textAlign: TextAlign.center,
                  ),
                ),
              )
            : ListView.builder(
                shrinkWrap: true,
                itemCount: _devices.length,
                itemBuilder: (context, index) {
                  final device = _devices[index];
                  final name = device.name ?? 'Unknown Device';
                  final address = device.address ?? 'No Address';
                  return ListTile(
                    leading: const Icon(Ionicons.print_outline),
                    title: Text(name),
                    subtitle: Text(address),
                    onTap: () => Navigator.of(context).pop(device),
                  );
                },
              ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Batal'),
        ),
      ],
    );
  }
}
