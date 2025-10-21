import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../models/order.dart';

class PdfInvoiceExporter {
  Future<Uint8List> generateInvoice(Order order) async {
    final pdf = pw.Document();

    final font = await PdfGoogleFonts.openSansRegular();
    final boldFont = await PdfGoogleFonts.openSansBold();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        header: (pw.Context context) {
          // Header will be repeated on each page
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              _buildHeader(order, boldFont, font),
              pw.SizedBox(height: 20),
              _buildCustomerInfo(order, boldFont, font),
              pw.SizedBox(height: 25),
            ],
          );
        },
        build: (pw.Context context) {
          // Content will flow across pages
          return [
            _buildProductTable(order, boldFont, font),
            pw.SizedBox(height: 20),
            pw.Align(
              alignment: pw.Alignment.centerRight,
              child: _buildTotal(order, boldFont, font),
            ),
          ];
        },
        footer: (pw.Context context) {
          // Footer with page number
          return pw.Container(
            alignment: pw.Alignment.centerRight,
            margin: const pw.EdgeInsets.only(top: 1.0 * PdfPageFormat.cm),
            child: pw.Text(
              'Halaman ${context.pageNumber} dari ${context.pagesCount}',
              style: pw.Theme.of(context)
                  .defaultTextStyle
                  .copyWith(color: PdfColors.grey, fontSize: 10),
            ),
          );
        },
      ),
    );

    return pdf.save();
  }

  pw.Widget _buildHeader(Order order, pw.Font boldFont, pw.Font font) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text('FAKTUR PENJUALAN',
            style: pw.TextStyle(font: boldFont, fontSize: 24)),
        pw.SizedBox(height: 12),
        _buildDetailRow('No. Pesanan:', order.id, font),
        _buildDetailRow('Tanggal:',
            DateFormat('dd MMMM yyyy, HH:mm', 'id_ID').format(order.date.toDate()),
            font),
        _buildDetailRow(
            'Status Pesanan:', _getFormattedOrderStatus(order.status), font),
        _buildDetailRow('Status Pembayaran:',
            _getFormattedPaymentStatus(order.paymentStatus), font),
      ],
    );
  }

  pw.Widget _buildCustomerInfo(Order order, pw.Font boldFont, pw.Font font) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text('Kepada:', style: pw.TextStyle(font: boldFont, fontSize: 16)),
        pw.SizedBox(height: 8),
        pw.Text(order.customer, style: pw.TextStyle(font: font)),
        pw.Text(order.customerAddress, style: pw.TextStyle(font: font)),
        pw.Text('Telp/WA: ${order.customerPhone}',
            style: pw.TextStyle(font: font)),
      ],
    );
  }

  pw.Widget _buildProductTable(Order order, pw.Font boldFont, pw.Font font) {
    final formatter =
        NumberFormat.currency(locale: 'id_ID', symbol: '', decimalDigits: 0);

    final headers = ['Produk', 'Jumlah', 'Harga', 'Subtotal'];

    final data = order.products.map((product) {
      return [
        product.name,
        product.quantity.toString(),
        'Rp ${formatter.format(product.price)}',
        'Rp ${formatter.format(product.price * product.quantity)}',
      ];
    }).toList();

    return pw.TableHelper.fromTextArray(
      headers: headers,
      data: data,
      headerStyle: pw.TextStyle(font: boldFont, color: PdfColors.white, fontSize: 10),
      cellStyle: pw.TextStyle(font: font, fontSize: 8),
      border: pw.TableBorder.all(color: PdfColors.grey600),
      headerDecoration: const pw.BoxDecoration(color: PdfColors.blueGrey700),
      cellAlignment: pw.Alignment.centerLeft,
      cellAlignments: {
        0: pw.Alignment.centerLeft,
        1: pw.Alignment.center,
        2: pw.Alignment.centerRight,
        3: pw.Alignment.centerRight,
      },
       cellPadding: const pw.EdgeInsets.all(6),
    );
  }

  pw.Widget _buildTotal(Order order, pw.Font boldFont, pw.Font font) {
    final formatter =
        NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
    final subtotal =
        order.products.fold(0.0, (sum, p) => sum + (p.price * p.quantity));
    final total = double.tryParse(order.total) ?? 0.0;

    return pw.SizedBox(
        width: 250,
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            _buildTotalRow(
                'Subtotal Produk:', formatter.format(subtotal), font, boldFont),
            pw.SizedBox(height: 4),
            _buildTotalRow('Biaya Pengiriman:',
                formatter.format(order.shippingFee ?? 0), font, boldFont),
            pw.Divider(height: 10),
            _buildTotalRow('TOTAL:', formatter.format(total), boldFont, boldFont,
                isTotal: true),
          ],
        ));
  }

  pw.Widget _buildTotalRow(
      String title, String value, pw.Font font, pw.Font boldFont,
      {bool isTotal = false}) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(title,
            style: pw.TextStyle(
                font: isTotal ? boldFont : font,
                fontSize: isTotal ? 14 : 12)),
        pw.Text(value,
            style: pw.TextStyle(
                font: isTotal ? boldFont : font,
                fontSize: isTotal ? 14 : 12)),
      ],
    );
  }

  pw.Widget _buildDetailRow(String title, String value, pw.Font font) {
    return pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 2),
        child: pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.SizedBox(
              width: 120,
              child: pw.Text(title, style: pw.TextStyle(font: font)),
            ),
            pw.Text(': ', style: pw.TextStyle(font: font)),
            pw.Expanded(
              child: pw.Text(value, style: pw.TextStyle(font: font)),
            ),
          ],
        ));
  }

  String _getFormattedOrderStatus(String status) {
    switch (status) {
      case 'processing':
        return 'Telah Diproses';
      case 'shipped':
        return 'Dikirim';
      case 'delivered':
        return 'Selesai';
      case 'pending':
        return 'Menunggu Diproses';
      case 'cancelled':
        return 'Dibatalkan';
      default:
        return status;
    }
  }

  String _getFormattedPaymentStatus(String status) {
    switch (status) {
      case 'unpaid':
        return 'Belum Bayar';
      case 'paid':
        return 'Lunas';
      default:
        return status;
    }
  }
}
