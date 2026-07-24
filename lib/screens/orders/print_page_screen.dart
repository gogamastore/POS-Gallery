import 'dart:developer' as developer;
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:ionicons/ionicons.dart';
import 'package:myapp/models/order.dart';
import 'package:myapp/screens/main_tab_controller.dart';
import 'package:myapp/screens/settings/printer_picker.dart';
import 'package:myapp/services/printing_service.dart';
import 'package:myapp/services/receipt_settings.dart';
import 'package:myapp/utils/pdf_invoice_exporter.dart';
import 'package:printing/printing.dart';
import 'package:universal_html/html.dart' as html;

class PrintPageScreen extends ConsumerStatefulWidget {
  final Order order;

  const PrintPageScreen({super.key, required this.order});

  @override
  ConsumerState<PrintPageScreen> createState() => _PrintPageScreenState();
}

class _PrintPageScreenState extends ConsumerState<PrintPageScreen> {
  final PrintingService _printingService = getPrintingService();

  // Identitas toko & catatan footer diambil dari Pengaturan Struk. Dipakai
  // nilai bawaan lebih dulu, lalu diperbarui setelah dimuat dari penyimpanan.
  ReceiptSettings _receipt = ReceiptSettings.defaults;

  @override
  void initState() {
    super.initState();
    ReceiptSettings.load().then((value) {
      if (mounted) setState(() => _receipt = value);
    });
  }

  Future<void> _downloadReceipt(BuildContext context) async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
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
      if (!mounted) return;
      scaffoldMessenger.showSnackBar(
        SnackBar(content: Text('Gagal mengunduh struk: $e')),
      );
    }
  }

  Future<void> _handlePrint() async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    try {
      // Cetak ke printer default bila sudah ada; jika belum, minta pengguna
      // memilih printer lebih dulu lalu cetak ke perangkat itu.
      final saved = await _printingService.loadDefaultPrinter();
      if (saved != null) {
        await _printToDefault();
      } else {
        if (!mounted) return;
        final selected = await showPrinterPicker(context, usb: false);
        if (selected != null) await _printToDevice(selected);
      }
    } catch (e, s) {
      developer.log('Error preparing for print: $e', stackTrace: s);
      if (!mounted) return;
      scaffoldMessenger.showSnackBar(
        SnackBar(content: Text('Gagal mempersiapkan print: $e')),
      );
    }
  }

  void _showPrintingDialog(String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(width: 20),
              Text(message),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _printToDefault() async {
    final navigator = Navigator.of(context, rootNavigator: true);
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    _showPrintingDialog('Mencetak ke printer tersimpan...');
    try {
      await _printingService.printToSavedDefault(widget.order);
      if (!mounted) return;
      navigator.pop();
      scaffoldMessenger.showSnackBar(
        const SnackBar(content: Text('Struk berhasil dikirim ke printer.')),
      );
    } catch (e, s) {
      developer.log('Error printing with saved device: $e', stackTrace: s);
      if (!mounted) return;
      navigator.pop();
      scaffoldMessenger.showSnackBar(
        SnackBar(content: Text('Gagal mencetak ke printer tersimpan: $e')),
      );
    }
  }

  Future<void> _printToDevice(PrinterDevice device) async {
    final navigator = Navigator.of(context, rootNavigator: true);
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    _showPrintingDialog('Mencetak...');
    try {
      await _printingService.printOrder(device, widget.order);
      if (!mounted) return;
      navigator.pop();
      scaffoldMessenger.showSnackBar(
        const SnackBar(content: Text('Struk berhasil dikirim ke printer.')),
      );
    } catch (e, s) {
      developer.log('Error printing: $e', stackTrace: s);
      if (!mounted) return;
      navigator.pop();
      scaffoldMessenger.showSnackBar(
        SnackBar(content: Text('Error saat mencetak: $e')),
      );
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
                      color: Colors.black12, // Updated for linter
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
                        child: Text(_receipt.storeName,
                            style: boldTextStyle.copyWith(fontSize: 18),
                            textAlign: TextAlign.center)),
                    if (_receipt.storeAddress.isNotEmpty)
                      Center(
                          child: Text(_receipt.storeAddress,
                              style: textStyle, textAlign: TextAlign.center)),
                    if (_receipt.storePhone.isNotEmpty)
                      Center(
                          child: Text('Telp: ${_receipt.storePhone}',
                              style: textStyle, textAlign: TextAlign.center)),
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
                          if (orig != null) {
                            originalPrice = (orig as num).toDouble();
                          }
                        } catch (_) {
                          originalPrice = null;
                        }

                        final price = (item['price'] as num).toDouble();
                        final hasDiscount =
                            originalPrice != null && originalPrice > price;
                        if (hasDiscount) {
                          return Padding(
                            padding: const EdgeInsets.only(top: 2.0),
                            child: Text(
                              '(Harga Sebelum Diskon: ${currencyFormatter.format(originalPrice)})',
                              style: const TextStyle(
                                  fontSize: 10,
                                  decoration: TextDecoration.lineThrough),
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
                    if (_receipt.footerNote.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Center(
                          child: Text(_receipt.footerNote,
                              style: textStyle, textAlign: TextAlign.center)),
                    ],
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
                onPressed: () {
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(
                        // Tab 0 = Penjualan (POS). Sebelumnya index 1 karena
                        // ada tab Dashboard di depan; kini Dashboard dihapus.
                        builder: (context) =>
                            const MainTabController(initialIndex: 0)),
                    (Route<dynamic> route) => false,
                  );
                },
                style: ElevatedButton.styleFrom(
                    minimumSize: const Size(200, 48),
                    textStyle: const TextStyle(fontSize: 18)),
                child: const Text('Selesai'), // Moved to be the last argument
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
