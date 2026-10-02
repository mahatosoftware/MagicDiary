import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'formatters.dart';
import '../../features/warranty/models/product.dart';
import '../../features/school_fees/models/school_fees_models.dart';
import '../../features/bills/models/bills_models.dart';

class PdfExporter {
  static Future<void> generateWarrantyReport(List<Product> products) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) => [
          pw.Header(
            level: 0,
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('Magic Diary – Warranty & Purchase Inventory Report',
                    style: const pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
                pw.Text(AppFormatters.date(DateTime.now()), style: const pw.TextStyle(fontSize: 10)),
              ],
            ),
          ),
          pw.SizedBox(height: 12),
          pw.TableHelper.fromTextArray(
            headers: ['Product Name', 'Brand', 'Category', 'Purchase Date', 'Price', 'Has Warranty'],
            data: products.map((p) => [
              p.name,
              p.brand,
              p.category,
              AppFormatters.date(p.purchaseDate),
              AppFormatters.currency(p.price),
              p.hasWarranty ? 'YES' : 'NO',
            ]).toList(),
          ),
        ],
      ),
    );

    await Printing.sharePdf(bytes: await pdf.save(), filename: 'Warranty_Report.pdf');
  }

  static Future<void> generateSchoolFeeReport(List<Child> children, List<FeeInstallment> installments) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) => [
          pw.Header(
            level: 0,
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('Magic Diary – School Fees Statement',
                    style: const pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
                pw.Text(AppFormatters.date(DateTime.now()), style: const pw.TextStyle(fontSize: 10)),
              ],
            ),
          ),
          pw.SizedBox(height: 12),
          pw.TableHelper.fromTextArray(
            headers: ['Installment Title', 'Due Date', 'Amount', 'Paid Amount', 'Status'],
            data: installments.map((i) => [
              i.title,
              AppFormatters.date(i.dueDate),
              AppFormatters.currency(i.amount),
              AppFormatters.currency(i.paidAmount),
              i.status.toUpperCase(),
            ]).toList(),
          ),
        ],
      ),
    );

    await Printing.sharePdf(bytes: await pdf.save(), filename: 'School_Fees_Statement.pdf');
  }

  static Future<void> generateBillsReport(List<BillAccount> accounts, List<Bill> bills) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) => [
          pw.Header(
            level: 0,
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('Magic Diary – Recurring Expenses & Bills Report',
                    style: const pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
                pw.Text(AppFormatters.date(DateTime.now()), style: const pw.TextStyle(fontSize: 10)),
              ],
            ),
          ),
          pw.SizedBox(height: 12),
          pw.TableHelper.fromTextArray(
            headers: ['Bill Period', 'Due Date', 'Amount', 'Status'],
            data: bills.map((b) => [
              b.billPeriod,
              AppFormatters.date(b.dueDate),
              AppFormatters.currency(b.amount),
              b.status.toUpperCase(),
            ]).toList(),
          ),
        ],
      ),
    );

    await Printing.sharePdf(bytes: await pdf.save(), filename: 'Bills_Report.pdf');
  }
}
