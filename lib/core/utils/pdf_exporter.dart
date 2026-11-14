import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'formatters.dart';
import '../../features/warranty/models/product.dart';
import '../../features/school_fees/models/school_fees_models.dart';
import '../../features/bills/models/bills_models.dart';
import '../../features/domestic_help/models/domestic_help_models.dart';

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

  static Future<void> generateSalaryStatementSlip(SalaryStatement statement, {DomesticWorker? worker}) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) => pw.Padding(
          padding: const pw.EdgeInsets.all(24),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('Magic Diary',
                          style: const pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold, color: PdfColors.blueGrey800)),
                      pw.Text('Household Staff Salary Statement / Payslip',
                          style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey700)),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text('Period: ${statement.month.toString().padLeft(2, '0')}/${statement.year}',
                          style: const pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
                      pw.Text('Date Generated: ${AppFormatters.date(DateTime.now())}',
                          style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600)),
                    ],
                  ),
                ],
              ),
              pw.Divider(thickness: 1.5, color: PdfColors.blueGrey200),
              pw.SizedBox(height: 16),

              pw.Container(
                padding: const pw.EdgeInsets.all(12),
                decoration: const pw.BoxDecoration(
                  color: PdfColors.grey100,
                  borderRadius: pw.BorderRadius.all(pw.Radius.circular(6)),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('Staff Name: ${statement.workerName}',
                            style: const pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
                        if (worker != null) ...[
                          pw.SizedBox(height: 4),
                          pw.Text('Role: ${worker.role}', style: const pw.TextStyle(fontSize: 11)),
                          pw.Text('Phone: ${worker.phone}', style: const pw.TextStyle(fontSize: 11)),
                        ],
                      ],
                    ),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Text('Status: ${statement.status.toUpperCase()}',
                            style: pw.TextStyle(
                              fontSize: 12,
                              fontWeight: pw.FontWeight.bold,
                              color: statement.isSettled ? PdfColors.green700 : PdfColors.amber800,
                            )),
                        if (statement.paymentMethod != null) ...[
                          pw.SizedBox(height: 4),
                          pw.Text('Payment Mode: ${statement.paymentMethod}', style: const pw.TextStyle(fontSize: 11)),
                        ],
                      ],
                    ),
                  ],
                ),
              ),

              pw.SizedBox(height: 24),
              pw.Text('Salary & Adjustment Breakdown',
                  style: const pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 8),

              pw.TableHelper.fromTextArray(
                headers: ['Component', 'Type', 'Amount (INR)'],
                data: [
                  ['Base Salary', 'Earnings', AppFormatters.currency(statement.baseSalary)],
                  ['Bonuses / Incentives', 'Earnings', '+ ${AppFormatters.currency(statement.bonuses)}'],
                  ['Extra Work / Overtime', 'Earnings', '+ ${AppFormatters.currency(statement.extraWorkPay)}'],
                  ['Unpaid Absence Deductions', 'Deduction', '- ${AppFormatters.currency(statement.deductions)}'],
                  ['Advance Recovery', 'Deduction', '- ${AppFormatters.currency(statement.advanceRecovery)}'],
                ],
                headerStyle: const pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
                headerDecoration: const pw.BoxDecoration(color: PdfColors.blueGrey700),
                cellAlignment: pw.Alignment.centerLeft,
                cellAlignments: {2: pw.Alignment.centerRight},
              ),

              pw.SizedBox(height: 16),
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(vertical: 10, horizontal: 14),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.blueGrey400),
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('Net Payable',
                        style: const pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
                    pw.Text(AppFormatters.currency(statement.netPayable),
                        style: const pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColors.blueGrey900)),
                  ],
                ),
              ),

              pw.SizedBox(height: 8),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Amount Paid: ${AppFormatters.currency(statement.paidAmount)}',
                      style: const pw.TextStyle(fontSize: 11, color: PdfColors.green800)),
                  pw.Text('Outstanding Balance: ${AppFormatters.currency(statement.outstandingBalance)}',
                      style: pw.TextStyle(
                        fontSize: 11,
                        fontWeight: pw.FontWeight.bold,
                        color: statement.outstandingBalance > 0 ? PdfColors.red800 : PdfColors.green800,
                      )),
                ],
              ),

              pw.Spacer(),
              pw.Divider(color: PdfColors.grey400),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Employer / Household Sign: _____________________', style: const pw.TextStyle(fontSize: 9)),
                  pw.Text('Staff Signature / Acknowledgment: _____________________', style: const pw.TextStyle(fontSize: 9)),
                ],
              ),
              pw.SizedBox(height: 8),
              pw.Center(
                child: pw.Text('Generated securely with Magic Diary Household Management',
                    style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey500)),
              ),
            ],
          ),
        ),
      ),
    );

    final safeName = statement.workerName.replaceAll(RegExp(r'\s+'), '_');
    await Printing.sharePdf(
      bytes: await pdf.save(),
      filename: 'SalarySlip_${safeName}_${statement.month}_${statement.year}.pdf',
    );
  }

  static Future<void> generateSalaryStatementsReport(
    List<SalaryStatement> statements,
    int month,
    int year,
  ) async {
    final pdf = pw.Document();

    final totalNet = statements.fold<double>(0.0, (sum, s) => sum + s.netPayable);
    final totalPaid = statements.fold<double>(0.0, (sum, s) => sum + s.paidAmount);
    final totalDue = statements.fold<double>(0.0, (sum, s) => sum + s.outstandingBalance);

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) => [
          pw.Header(
            level: 0,
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('Magic Diary – Household Staff Payroll ($month/$year)',
                    style: const pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
                pw.Text(AppFormatters.date(DateTime.now()), style: const pw.TextStyle(fontSize: 10)),
              ],
            ),
          ),
          pw.SizedBox(height: 12),
          pw.TableHelper.fromTextArray(
            headers: ['Worker Name', 'Base Salary', 'Bonuses', 'Deductions', 'Adv Rec', 'Net Payable', 'Paid', 'Status'],
            data: statements.map((s) => [
              s.workerName,
              AppFormatters.currency(s.baseSalary),
              AppFormatters.currency(s.bonuses),
              AppFormatters.currency(s.deductions),
              AppFormatters.currency(s.advanceRecovery),
              AppFormatters.currency(s.netPayable),
              AppFormatters.currency(s.paidAmount),
              s.status.toUpperCase(),
            ]).toList(),
            headerStyle: const pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.blueGrey800),
          ),
          pw.SizedBox(height: 16),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.end,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text('Total Payroll: ${AppFormatters.currency(totalNet)}',
                      style: const pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                  pw.Text('Total Disbursed: ${AppFormatters.currency(totalPaid)}',
                      style: const pw.TextStyle(color: PdfColors.green800)),
                  pw.Text('Total Outstanding: ${AppFormatters.currency(totalDue)}',
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: totalDue > 0 ? PdfColors.red800 : PdfColors.green800)),
                ],
              ),
            ],
          ),
        ],
      ),
    );

    await Printing.sharePdf(
      bytes: await pdf.save(),
      filename: 'Household_Staff_Salaries_${month}_$year.pdf',
    );
  }
}
