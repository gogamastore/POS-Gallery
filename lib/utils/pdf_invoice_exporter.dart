import 'dart:typed_data';
import 'package:flutter/services.dart' show rootBundle;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:myapp/models/order.dart';

class PdfInvoiceExporter {
  Future<Uint8List> exportInvoice(Order order) async {
    final pdf = pw.Document();

    final fontData =
        await rootBundle.load("assets/fonts/IBMPlexMono-Regular.ttf");
    final ttf = pw.Font.ttf(fontData);
    final boldFontData =
        await rootBundle.load("assets/fonts/IBMPlexMono-Bold.ttf");
    final boldTtf = pw.Font.ttf(boldFontData);

    final textStyle = pw.TextStyle(font: ttf, fontSize: 9);
    final boldTextStyle = pw.TextStyle(font: boldTtf, fontSize: 9);

    final currencyFormatter =
        NumberFormat.currency(locale: 'id_ID', symbol: '', decimalDigits: 0);

    pdf.addPage(pw.Page(
      pageFormat: const PdfPageFormat(
          80 * PdfPageFormat.mm, 297 * PdfPageFormat.mm,
          marginAll: 5 * PdfPageFormat.mm),
      build: (context) {
        return pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            // --- Header ---
            pw.Center(
                child: pw.Text('GALLERY MAKASSAR',
                    style: pw.TextStyle(font: boldTtf, fontSize: 14))),
            pw.Center(
                child: pw.Text('Jl. Borong Raya Nomor 100', style: textStyle)),
            pw.Center(child: pw.Text('Telp: 089636052501', style: textStyle)),
            pw.Divider(),

            // --- Order Info ---
            pw.Text('No: ${order.id?.substring(0, 8) ?? 'N/A'}',
                style: textStyle),
            pw.Text(
                'Tanggal: ${DateFormat('dd/MM/yy HH:mm').format((order.createdAt ?? order.date).toDate())}',
                style: textStyle),
            pw.Text('Kasir: ${order.kasir}', style: textStyle),
            if (order.customer != null && order.customer!.isNotEmpty)
              pw.Text('Customer: ${order.customer!}', style: textStyle),
            pw.Divider(),

            // --- Product Items ---
            for (var item in order.products) ...[
              pw.Text(item['name'] as String, style: textStyle),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                      '  ${item['quantity']} x ${currencyFormatter.format(item['price'])}',
                      style: textStyle),
                  pw.Text(
                      currencyFormatter
                          .format(item['quantity'] * item['price']),
                      style: textStyle),
                ],
              ),
              pw.SizedBox(height: 2),
            ],
            pw.Divider(),

            // --- Totals ---
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('Subtotal', style: textStyle),
                pw.Text(currencyFormatter.format(order.subtotal),
                    style: textStyle),
              ],
            ),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('Total Discount', style: textStyle),
                pw.Text(currencyFormatter.format(order.totalDiscount),
                    style: textStyle),
              ],
            ),
            pw.SizedBox(height: 2),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('Total', style: boldTextStyle),
                pw.Text(currencyFormatter.format(order.total),
                    style: boldTextStyle),
              ],
            ),
            pw.Divider(),

            // --- Footer ---
            pw.Center(child: pw.Text('Terima Kasih!', style: textStyle)),
            pw.SizedBox(height: 2),
            pw.Center(
                child: pw.Text(
                    'Barang yang sudah dibeli tidak dapat dikembalikan.',
                    style: textStyle,
                    textAlign: pw.TextAlign.center)),
          ],
        );
      },
    ));

    return pdf.save();
  }
}

// Helper top-level function for compatibility with callers.
Future<Uint8List> exportInvoicePdf(Order order) async {
  return await PdfInvoiceExporter().exportInvoice(order);
}
