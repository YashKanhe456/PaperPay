import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/utils/formatters.dart';
import '../models/bill_model.dart';

class PdfService {
  const PdfService();

  Future<Uint8List> generateBillPdf(BillModel bill) async {
    final pdf = pw.Document();
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        build: (context) => [
          pw.Text(
            'Sharma News Agency',
            style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 4),
          pw.Text('Nashik, Maharashtra'),
          pw.Text('PaperPay Bill'),
          pw.SizedBox(height: 16),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('Bill: ${bill.id.substring(0, bill.id.length > 8 ? 8 : bill.id.length)}'),
              pw.Text(DateFormat('dd MMM yyyy').format(bill.generatedAt ?? DateTime.now())),
            ],
          ),
          pw.SizedBox(height: 16),
          pw.Text('Customer: ${bill.customerName ?? 'Customer'}'),
          if ((bill.phone ?? '').isNotEmpty) pw.Text('Phone: ${bill.phone}'),
          pw.SizedBox(height: 16),
          pw.TableHelper.fromTextArray(
            headers: const ['Newspaper', 'Days', 'Rate/Day', 'Amount'],
            data: bill.billItems
                .map((item) => [
                      item.newspaperName,
                      '${item.days}',
                      Formatters.formatCurrency(item.ratePerDay),
                      Formatters.formatCurrency(item.total),
                    ])
                .toList(),
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
            cellAlignment: pw.Alignment.centerLeft,
          ),
          pw.SizedBox(height: 16),
          _row('Base', Formatters.formatCurrency(bill.amount)),
          _row('Discount', '-${Formatters.formatCurrency(bill.discount)}'),
          _row('Late Fee', '+${Formatters.formatCurrency(bill.lateFee)}'),
          pw.Divider(),
          _row(
            'Total',
            Formatters.formatCurrency(bill.finalAmount),
            bold: true,
          ),
          pw.SizedBox(height: 20),
          pw.Text('Payment modes: UPI / Cash / Card'),
          pw.SizedBox(height: 8),
          pw.Text('Shukriya! Thank you'),
        ],
      ),
    );
    return pdf.save();
  }

  Future<void> downloadBillPdf(BillModel bill) async {
    final bytes = await generateBillPdf(bill);
    await Printing.layoutPdf(onLayout: (_) async => bytes, name: 'bill-${bill.month}-${bill.year}.pdf');
  }

  Future<void> shareBillWhatsApp(BillModel bill) async {
    final message = Uri.encodeComponent(
      'Aapka ${Formatters.formatCurrency(bill.finalAmount)} ka bill ready hai.${bill.pdfUrl != null ? ' ${bill.pdfUrl}' : ''}',
    );
    final phone = _normalizePhone(bill.phone);
    final url = phone == null
        ? Uri.parse('https://wa.me/?text=$message')
        : Uri.parse('https://wa.me/$phone?text=$message');
    await launchUrl(url, mode: LaunchMode.externalApplication);
  }

  static pw.Widget _row(String label, String value, {bool bold = false}) {
    final style = pw.TextStyle(
      fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
      fontSize: bold ? 14 : 12,
    );
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 4),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label, style: style),
          pw.Text(value, style: style),
        ],
      ),
    );
  }

  String? _normalizePhone(String? phone) {
    final digits = (phone ?? '').replaceAll(RegExp(r'\D'), '');
    if (digits.length == 10) {
      return '91$digits';
    }
    if (digits.length == 12 && digits.startsWith('91')) {
      return digits;
    }
    return null;
  }
}
