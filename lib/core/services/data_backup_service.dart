// ignore_for_file: prefer_const_constructors

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';

import '../../features/auth/models/user_profile.dart';
import '../security/data_export_security_service.dart';
import '../utils/formatters.dart';

class DataBackupService {
  /// Generates a structured .zip archive containing all module JSONs, CSV ledgers, and PDF summary.
  static Future<String> generateCompleteZipArchive({
    required ExportPackage package,
    UserProfile? profile,
    Directory? targetDir,
  }) async {
    final archive = Archive();
    final now = DateTime.now();
    final dateStr = DateFormat('yyyy-MM-dd_HHmm').format(now);

    // 1. Module counts for manifest
    final moduleCounts = <String, int>{};
    for (final entry in package.data.entries) {
      if (entry.value is List) {
        moduleCounts[entry.key] = (entry.value as List).length;
      }
    }

    // 2. Backup Manifest
    final manifest = {
      'appName': 'Magic Diary',
      'appVersion': '1.0.10+10',
      'exportedAt': now.toIso8601String(),
      'userId': package.userId,
      'username': profile?.username.isNotEmpty == true ? '@${profile!.username}' : null,
      'displayName': profile?.displayName,
      'formatVersion': package.formatVersion,
      'moduleCounts': moduleCounts,
    };
    final manifestBytes = utf8.encode(const JsonEncoder.withIndent('  ').convert(manifest));
    archive.addFile(ArchiveFile('manifest.json', manifestBytes.length, manifestBytes));

    // 3. Complete Consolidated Backup JSON
    final completeJsonBytes = utf8.encode(package.toJsonString());
    archive.addFile(ArchiveFile('complete_backup.json', completeJsonBytes.length, completeJsonBytes));

    // 4. Individual Module Data Files
    for (final entry in package.data.entries) {
      final moduleName = entry.key;
      final moduleData = entry.value;
      final fileBytes = utf8.encode(const JsonEncoder.withIndent('  ').convert(moduleData));
      archive.addFile(ArchiveFile('data/$moduleName.json', fileBytes.length, fileBytes));
    }

    // 5. CSV Financial Ledger
    final txs = package.data['financialTransactions'];
    if (txs is List && txs.isNotEmpty) {
      final csvBuffer = StringBuffer();
      csvBuffer.writeln('Transaction ID,Date,Type,Category,Amount,Description,Payment Method,Notes');
      for (final raw in txs) {
        if (raw is Map<String, dynamic>) {
          final id = raw['id'] ?? '';
          final date = raw['transactionDate']?.toString() ?? '';
          final type = raw['type'] ?? '';
          final cat = raw['categoryId'] ?? '';
          final amount = raw['amountMinor'] != null ? ((raw['amountMinor'] as num) / 100.0).toStringAsFixed(2) : '0.00';
          final desc = (raw['description'] ?? '').toString().replaceAll(',', ';');
          final method = raw['paymentMethod'] ?? '';
          final notes = (raw['notes'] ?? '').toString().replaceAll(',', ';');
          csvBuffer.writeln('$id,$date,$type,$cat,$amount,$desc,$method,$notes');
        }
      }
      final csvBytes = utf8.encode(csvBuffer.toString());
      archive.addFile(ArchiveFile('ledgers/financial_transactions.csv', csvBytes.length, csvBytes));
    }

    // 6. Generate Formatted PDF Book and embed inside ZIP
    try {
      final pdfBytes = await buildPdfBookBytes(package: package, profile: profile);
      archive.addFile(ArchiveFile('MagicDiary_Life_Record_Book.pdf', pdfBytes.length, pdfBytes));
    } catch (_) {
      // PDF generation fallback
    }

    // 7. Compress into ZIP File on Disk
    final zipEncoder = ZipEncoder();
    final zipData = zipEncoder.encode(archive);

    final tempDir = targetDir ?? await getTemporaryDirectory();
    final zipPath = '${tempDir.path}/MagicDiary_Backup_$dateStr.zip';
    final zipFile = File(zipPath);
    await zipFile.writeAsBytes(zipData);

    return zipPath;
  }

  /// Exports and shares the ZIP backup using OS Share sheet
  static Future<void> shareZipBackup({
    required ExportPackage package,
    UserProfile? profile,
  }) async {
    final zipPath = await generateCompleteZipArchive(package: package, profile: profile);
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(zipPath, mimeType: 'application/zip')],
        text: 'Magic Diary Complete Backup Archive (${DateFormat('dd MMM yyyy').format(DateTime.now())})',
      ),
    );
  }

  /// Shares a standalone JSON export file
  static Future<void> shareJsonExport({required ExportPackage package}) async {
    final tempDir = await getTemporaryDirectory();
    final dateStr = DateFormat('yyyyMMdd_HHmm').format(DateTime.now());
    final filePath = '${tempDir.path}/MagicDiary_Export_$dateStr.json';
    final file = File(filePath);
    await file.writeAsString(package.toJsonString());

    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(filePath, mimeType: 'application/json')],
        text: 'Magic Diary JSON Data Export',
      ),
    );
  }

  /// Builds a comprehensive printable PDF Book summarizing all records
  static Future<Uint8List> buildPdfBookBytes({
    required ExportPackage package,
    UserProfile? profile,
  }) async {
    final pdf = pw.Document();
    final now = DateTime.now();

    final bills = (package.data['bills'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final accounts = (package.data['billAccounts'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final transactions = (package.data['financialTransactions'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final products = (package.data['products'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final vehicles = (package.data['vehicles'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final properties = (package.data['properties'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final journals = (package.data['journals'] as List?)?.cast<Map<String, dynamic>>() ?? [];

    // --- Page 1: Cover & Executive Summary ---
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Container(
            padding: pw.EdgeInsets.all(32),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'Magic Diary',
                  style: pw.TextStyle(fontSize: 28, fontWeight: pw.FontWeight.bold, color: PdfColors.indigo900),
                ),
                pw.SizedBox(height: 6),
                pw.Text(
                  'Personal Information & Life Record Book',
                  style: pw.TextStyle(fontSize: 16, color: PdfColors.grey700),
                ),
                pw.Divider(thickness: 2, color: PdfColors.indigo500),
                pw.SizedBox(height: 24),

                pw.Container(
                  padding: pw.EdgeInsets.all(16),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.grey100,
                    borderRadius: pw.BorderRadius.all(pw.Radius.circular(8)),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('Account Owner: ${profile?.displayName ?? "Authenticated User"}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 13)),
                      if (profile?.username.isNotEmpty == true)
                        pw.Text('Username: @${profile!.username}', style: pw.TextStyle(fontSize: 12, color: PdfColors.indigo700)),
                      if (profile?.email.isNotEmpty == true)
                        pw.Text('Email: ${profile!.email}', style: pw.TextStyle(fontSize: 12)),
                      pw.Text('Generated: ${AppFormatters.date(now)} at ${DateFormat('HH:mm').format(now)}', style: pw.TextStyle(fontSize: 12, color: PdfColors.grey700)),
                    ],
                  ),
                ),
                pw.SizedBox(height: 24),

                pw.Text('Life Record Inventory Summary', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 12),
                pw.TableHelper.fromTextArray(
                  headers: ['Module', 'Record Count', 'Status'],
                  data: [
                    ['Bills & Payments', '${bills.length}', 'Active'],
                    ['Recurring Accounts', '${accounts.length}', 'Active'],
                    ['Financial Transactions', '${transactions.length}', 'Active'],
                    ['Warranties & Products', '${products.length}', 'Active'],
                    ['Vehicles & Service History', '${vehicles.length}', 'Active'],
                    ['Properties & Real Estate', '${properties.length}', 'Active'],
                    ['Personal Journal Entries', '${journals.length}', 'Encrypted'],
                  ],
                  headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
                  headerDecoration: pw.BoxDecoration(color: PdfColors.indigo800),
                  cellHeight: 24,
                ),
              ],
            ),
          );
        },
      ),
    );

    // --- Page 2: Bills, Utilities & Subscriptions ---
    if (accounts.isNotEmpty || bills.isNotEmpty) {
      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          header: (context) => pw.Header(
            level: 0,
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('Magic Diary - Bills & Recurring Expenses', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
                pw.Text(AppFormatters.date(now), style: pw.TextStyle(fontSize: 10, color: PdfColors.grey600)),
              ],
            ),
          ),
          build: (pw.Context context) => [
            pw.Text('Recurring Bill Accounts & Subscriptions', style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold, color: PdfColors.indigo900)),
            pw.SizedBox(height: 8),
            pw.TableHelper.fromTextArray(
              headers: ['Account Name', 'Category', 'Provider', 'Cycle', 'Due Day', 'Avg Amount'],
              data: accounts.map((a) => [
                a['name']?.toString() ?? '',
                a['category']?.toString() ?? '',
                a['providerName']?.toString() ?? '',
                a['billingCycle']?.toString() ?? 'Monthly',
                'Day ${a['dueDayOfMonth'] ?? 10}',
                'Rs. ${(a['defaultAmount'] ?? 0).toString()}',
              ]).toList(),
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
              headerDecoration: pw.BoxDecoration(color: PdfColors.indigo700),
            ),
            pw.SizedBox(height: 16),
            pw.Text('Recent Bills Schedule & Status', style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold, color: PdfColors.indigo900)),
            pw.SizedBox(height: 8),
            pw.TableHelper.fromTextArray(
              headers: ['Period', 'Amount', 'Status', 'Notes'],
              data: bills.take(15).map((b) => [
                b['billPeriod']?.toString() ?? '',
                'Rs. ${(b['amount'] ?? 0).toString()}',
                (b['status']?.toString() ?? 'unpaid').toUpperCase(),
                b['notes']?.toString() ?? '',
              ]).toList(),
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
              headerDecoration: pw.BoxDecoration(color: PdfColors.blueGrey800),
            ),
          ],
        ),
      );
    }

    // --- Page 3: Financial Ledger ---
    if (transactions.isNotEmpty) {
      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          header: (context) => pw.Header(
            level: 0,
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('Magic Diary - Financial Ledger Statement', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
                pw.Text(AppFormatters.date(now), style: pw.TextStyle(fontSize: 10, color: PdfColors.grey600)),
              ],
            ),
          ),
          build: (pw.Context context) => [
            pw.TableHelper.fromTextArray(
              headers: ['Date', 'Type', 'Category', 'Amount', 'Description', 'Method'],
              data: transactions.take(30).map((t) {
                final amt = t['amountMinor'] != null ? 'Rs. ${((t['amountMinor'] as num) / 100.0).toStringAsFixed(0)}' : 'Rs. 0';
                return [
                  t['transactionDate']?.toString().split('T').first ?? '',
                  (t['type']?.toString() ?? '').toUpperCase(),
                  t['categoryId']?.toString() ?? '',
                  amt,
                  t['description']?.toString() ?? '',
                  t['paymentMethod']?.toString() ?? '',
                ];
              }).toList(),
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
              headerDecoration: pw.BoxDecoration(color: PdfColors.teal800),
            ),
          ],
        ),
      );
    }

    // --- Page 4: Vehicles, Properties & Warranties ---
    if (vehicles.isNotEmpty || properties.isNotEmpty || products.isNotEmpty) {
      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          header: (context) => pw.Header(
            level: 0,
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('Magic Diary - Assets, Vehicles & Appliances', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
                pw.Text(AppFormatters.date(now), style: pw.TextStyle(fontSize: 10, color: PdfColors.grey600)),
              ],
            ),
          ),
          build: (pw.Context context) => [
            if (vehicles.isNotEmpty) ...[
              pw.Text('Vehicles & Registered Transport', style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold, color: PdfColors.indigo900)),
              pw.SizedBox(height: 6),
              pw.TableHelper.fromTextArray(
                headers: ['Vehicle', 'Reg. Number', 'Make / Model', 'Fuel Type'],
                data: vehicles.map((v) => [
                  v['name']?.toString() ?? '',
                  v['registrationNumber']?.toString() ?? '',
                  '${v['make'] ?? ''} ${v['model'] ?? ''}',
                  v['fuelType']?.toString() ?? '',
                ]).toList(),
                headerDecoration: pw.BoxDecoration(color: PdfColors.indigo700),
                headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
              ),
              pw.SizedBox(height: 16),
            ],
            if (products.isNotEmpty) ...[
              pw.Text('Appliances & Warranty Tracking', style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold, color: PdfColors.indigo900)),
              pw.SizedBox(height: 6),
              pw.TableHelper.fromTextArray(
                headers: ['Product', 'Brand', 'Category', 'Price', 'Warranty Exp.'],
                data: products.take(15).map((p) => [
                  p['name']?.toString() ?? '',
                  p['brand']?.toString() ?? '',
                  p['category']?.toString() ?? '',
                  'Rs. ${(p['price'] ?? 0).toString()}',
                  p['warrantyExpiryDate']?.toString().split('T').first ?? 'None',
                ]).toList(),
                headerDecoration: pw.BoxDecoration(color: PdfColors.indigo700),
                headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
              ),
            ],
          ],
        ),
      );
    }

    return await pdf.save();
  }

  /// Exports and shares the formatted PDF Book
  static Future<void> sharePdfBook({
    required ExportPackage package,
    UserProfile? profile,
  }) async {
    final bytes = await buildPdfBookBytes(package: package, profile: profile);
    await Printing.sharePdf(
      bytes: bytes,
      filename: 'MagicDiary_Life_Record_Book_${DateFormat('yyyyMMdd').format(DateTime.now())}.pdf',
    );
  }
}
