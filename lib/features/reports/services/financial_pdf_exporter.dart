import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../../core/utils/formatters.dart';
import '../models/report_models.dart';

class FinancialReportPdfExporter {
  /// Generate and export a complete Financial Statement PDF
  static Future<void> exportPdf(FinancialPeriodSummary summary, {String currencySymbol = '₹'}) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) => [
          // Header
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('Magic Diary', style: const pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold, color: PdfColors.indigo900)),
                  pw.Text('Financial Statement & Analytics Report', style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey700)),
                ],
              ),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text('Generated: ${DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.now())}', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600)),
                  pw.Text('Period: ${summary.dateRange.label}', style: const pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: PdfColors.indigo800)),
                  pw.Text('${DateFormat('dd MMM yyyy').format(summary.dateRange.start)} – ${DateFormat('dd MMM yyyy').format(summary.dateRange.end)}', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600)),
                ],
              ),
            ],
          ),

          pw.Divider(thickness: 1.5, color: PdfColors.indigo300),
          pw.SizedBox(height: 12),

          // Key Highlights Summary
          pw.Text('Financial Overview', style: const pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColors.indigo900)),
          pw.SizedBox(height: 8),

          pw.TableHelper.fromTextArray(
            headers: ['Total Income', 'Total Expenses', 'Net Savings', 'Savings Rate'],
            data: [
              [
                AppFormatters.currency(summary.totalIncome),
                AppFormatters.currency(summary.totalExpenses),
                AppFormatters.currency(summary.netSavings),
                '${summary.savingsRate.toStringAsFixed(1)}%',
              ]
            ],
            headerStyle: const pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white, fontSize: 10),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.indigo800),
            cellAlignment: pw.Alignment.center,
            cellStyle: const pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
          ),

          pw.SizedBox(height: 18),

          // Category Expense Breakdown
          if (summary.categoryBreakdowns.isNotEmpty) ...[
            pw.Text('Expense Distribution by Category', style: const pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColors.indigo900)),
            pw.SizedBox(height: 6),
            pw.TableHelper.fromTextArray(
              headers: ['Category', 'Amount', 'Share (%)', 'Transactions'],
              data: summary.categoryBreakdowns.map((b) => [
                b.category,
                AppFormatters.currency(b.amount),
                '${b.percentage.toStringAsFixed(1)}%',
                b.count.toString(),
              ]).toList(),
              headerStyle: const pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white, fontSize: 9),
              headerDecoration: const pw.BoxDecoration(color: PdfColors.blueGrey800),
              cellAlignment: pw.Alignment.centerLeft,
              cellStyle: const pw.TextStyle(fontSize: 9),
            ),
            pw.SizedBox(height: 18),
          ],

          // Upcoming Obligations
          if (summary.upcomingObligations.isNotEmpty) ...[
            pw.Text('Upcoming Financial Obligations', style: const pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColors.indigo900)),
            pw.SizedBox(height: 6),
            pw.TableHelper.fromTextArray(
              headers: ['Due Date', 'Obligation / Title', 'Category', 'Amount', 'Status'],
              data: summary.upcomingObligations.take(8).map((o) => [
                DateFormat('dd MMM yyyy').format(o.dueDate),
                o.title,
                o.category,
                AppFormatters.currency(o.amount),
                o.status.toUpperCase(),
              ]).toList(),
              headerStyle: const pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white, fontSize: 9),
              headerDecoration: const pw.BoxDecoration(color: PdfColors.orange900),
              cellAlignment: pw.Alignment.centerLeft,
              cellStyle: const pw.TextStyle(fontSize: 8.5),
            ),
            pw.SizedBox(height: 18),
          ],

          // Detailed Transactions Table
          pw.Text('Itemized Transactions (${summary.transactions.length})', style: const pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColors.indigo900)),
          pw.SizedBox(height: 6),
          pw.TableHelper.fromTextArray(
            headers: ['Date', 'Description', 'Flow', 'Category', 'Amount', 'Method'],
            data: summary.transactions.map((t) => [
              DateFormat('dd/MM/yy').format(t.date),
              t.title,
              t.flow.name.toUpperCase(),
              t.category,
              '${t.flow == TransactionFlow.income ? '+' : '-'}${AppFormatters.currency(t.amount)}',
              t.paymentMethod,
            ]).toList(),
            headerStyle: const pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white, fontSize: 8.5),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.indigo900),
            cellAlignment: pw.Alignment.centerLeft,
            cellStyle: const pw.TextStyle(fontSize: 8),
          ),

          pw.SizedBox(height: 20),
          pw.Center(
            child: pw.Text(
              'End of Statement • Confidential and Generated by Magic Diary',
              style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey500),
            ),
          ),
        ],
      ),
    );

    final bytes = await pdf.save();
    final sanitizedLabel = summary.dateRange.label.replaceAll(' ', '_').replaceAll('/', '-');
    await Printing.sharePdf(
      bytes: bytes,
      filename: 'MagicDiary_Financial_Report_$sanitizedLabel.pdf',
    );
  }

  /// Generate CSV String for export
  static String generateCsv(FinancialPeriodSummary summary) {
    final buffer = StringBuffer();
    buffer.writeln('Date,Description,Type,Category,Subcategory,Amount,PaymentMethod,SourceModule,Status');

    for (final t in summary.transactions) {
      final dateStr = DateFormat('yyyy-MM-dd').format(t.date);
      final desc = t.title.replaceAll('"', '""');
      final flow = t.flow.name.toUpperCase();
      final cat = t.category.replaceAll('"', '""');
      final subcat = t.subcategory.replaceAll('"', '""');
      final amt = t.amount.toStringAsFixed(2);
      final method = t.paymentMethod.replaceAll('"', '""');
      final src = t.sourceModule;
      final st = t.status;

      buffer.writeln('"$dateStr","$desc","$flow","$cat","$subcat",$amt,"$method","$src","$st"');
    }

    return buffer.toString();
  }
}
