import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/receivable_data.dart';

class PdfReceivableExporter {
  static Future<void> exportToPdf(
      List<ReceivableData> data, DateTime startDate, DateTime endDate) async {
    final pdf = pw.Document();
    final currencyFormatter =
        NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);

    final double totalPiutang =
        data.fold(0, (sum, item) => sum + item.totalReceivable);

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        header: (pw.Context context) => _buildHeader(startDate, endDate),
        footer: (pw.Context context) => _buildFooter(context),
        build: (pw.Context context) => [
          _buildReceivableTable(data, currencyFormatter),
          pw.Divider(),
          _buildTotal(totalPiutang, currencyFormatter),
        ],
      ),
    );

    await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdf.save());
  }

  static pw.Widget _buildHeader(DateTime startDate, DateTime endDate) {
    return pw.Container(
      alignment: pw.Alignment.centerLeft,
      margin: const pw.EdgeInsets.only(bottom: 20.0),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'Laporan Piutang Usaha',
            style: pw.TextStyle(
                fontWeight: pw.FontWeight.bold, fontSize: 24),
          ),
          pw.SizedBox(height: 5),
          pw.Text(
            'Periode: ${DateFormat('dd MMM yyyy', 'id_ID').format(startDate)} - ${DateFormat('dd MMM yyyy', 'id_ID').format(endDate)}',
            style: const pw.TextStyle(fontSize: 14, color: PdfColors.grey700),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildReceivableTable(
      List<ReceivableData> data, NumberFormat currencyFormatter) {
    final headers = [
      '#',
      'Tanggal',
      'ID Pesanan',
      'Pelanggan',
      'Jumlah Piutang'
    ];

    final tableData = data.map((item) {
      final index = data.indexOf(item) + 1;
      return [
        index.toString(),
        DateFormat('dd-MM-yy', 'id_ID').format(item.orderDate),
        item.orderId,
        item.customerName,
        currencyFormatter.format(item.totalReceivable),
      ];
    }).toList();

    return pw.TableHelper.fromTextArray(
      headers: headers,
      data: tableData,
      border: pw.TableBorder.all(color: PdfColors.grey, width: 0.5),
      headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
      headerDecoration: const pw.BoxDecoration(color: PdfColors.blueGrey),
      cellStyle: const pw.TextStyle(fontSize: 10),
      cellAlignments: {
        0: pw.Alignment.center,
        1: pw.Alignment.center,
        4: pw.Alignment.centerRight,
      },
      columnWidths: {
        0: const pw.FlexColumnWidth(0.5),
        1: const pw.FlexColumnWidth(1),
        2: const pw.FlexColumnWidth(2),
        3: const pw.FlexColumnWidth(2),
        4: const pw.FlexColumnWidth(1.5),
      },
    );
  }

  static pw.Widget _buildTotal(
      double totalPiutang, NumberFormat currencyFormatter) {
    return pw.Container(
      alignment: pw.Alignment.centerRight,
      margin: const pw.EdgeInsets.only(top: 20.0),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.end,
        children: [
          pw.Text(
            'Total Piutang:',
            style: pw.TextStyle(
                fontSize: 14, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(width: 10),
          pw.Text(
            currencyFormatter.format(totalPiutang),
            style: pw.TextStyle(
                fontSize: 16,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.red),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildFooter(pw.Context context) {
    return pw.Container(
      alignment: pw.Alignment.centerRight,
      margin: const pw.EdgeInsets.only(top: 10.0),
      child: pw.Text(
        'Halaman ${context.pageNumber} dari ${context.pagesCount}',
        style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey),
      ),
    );
  }
}
