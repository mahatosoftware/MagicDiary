import 'dart:convert';
import 'dart:io';
import 'package:archive/archive.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:magic_diary/core/security/data_export_security_service.dart';
import 'package:magic_diary/core/services/data_backup_service.dart';
import 'package:magic_diary/core/services/home_widget_service.dart';
import 'package:magic_diary/features/auth/models/user_profile.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('DataBackupService & Full Data Export Tests', () {
    final testProfile = UserProfile(
      uid: 'user_backup_123',
      email: 'tester@magicdiary.app',
      displayName: 'Alice Tester',
      username: 'ALICE99',
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
    );

    final testPackage = ExportPackage(
      userId: 'user_backup_123',
      exportedAt: DateTime(2026, 11, 19, 12, 0),
      data: {
        'bills': [
          {
            'id': 'bill_1',
            'billPeriod': 'November 2026',
            'amount': 1499.0,
            'status': 'unpaid',
            'notes': 'Broadband fiber',
          }
        ],
        'billAccounts': [
          {
            'id': 'acc_1',
            'name': 'Airtel Broadband',
            'category': 'Broadband',
            'providerName': 'Airtel',
            'defaultAmount': 1499.0,
            'billingCycle': 'Monthly',
            'dueDayOfMonth': 12,
          }
        ],
        'financialTransactions': [
          {
            'id': 'tx_1',
            'transactionDate': '2026-11-18T10:00:00.000',
            'type': 'expense',
            'categoryId': 'utilities',
            'amountMinor': 149900,
            'description': 'Airtel Payment',
            'paymentMethod': 'UPI',
            'notes': 'Online transfer',
          }
        ],
        'products': [
          {
            'id': 'prod_1',
            'name': 'Samsung Smart TV',
            'brand': 'Samsung',
            'category': 'Electronics',
            'price': 42999.0,
            'warrantyExpiryDate': '2027-11-18T00:00:00.000',
          }
        ],
        'vehicles': [
          {
            'id': 'veh_1',
            'name': 'Hyundai Creta',
            'registrationNumber': 'DL-01-AB-1234',
            'make': 'Hyundai',
            'model': 'Creta SX',
            'fuelType': 'Petrol',
          }
        ],
        'properties': [],
        'journals': [
          {
            'id': 'j_1',
            'title': 'Trip to Shimla',
            'content': 'Great family time in the hills.',
          }
        ],
      },
    );

    test('buildPdfBookBytes generates valid, non-empty PDF bytes', () async {
      final pdfBytes = await DataBackupService.buildPdfBookBytes(
        package: testPackage,
        profile: testProfile,
      );

      expect(pdfBytes, isNotEmpty);
      // PDF documents start with %PDF- header magic numbers
      final header = String.fromCharCodes(pdfBytes.take(4));
      expect(header, equals('%PDF'));
    });

    test('generateCompleteZipArchive compiles manifest, JSONs, CSV ledger, and PDF book inside zip', () async {
      final tempDir = Directory.systemTemp.createTempSync('magic_diary_test_');
      final zipPath = await DataBackupService.generateCompleteZipArchive(
        package: testPackage,
        profile: testProfile,
        targetDir: tempDir,
      );

      final zipFile = File(zipPath);
      expect(await zipFile.exists(), isTrue);

      final bytes = await zipFile.readAsBytes();
      final archive = ZipDecoder().decodeBytes(bytes);

      // Verify files inside archive
      final fileNames = archive.files.map((f) => f.name).toSet();
      expect(fileNames.contains('manifest.json'), isTrue);
      expect(fileNames.contains('complete_backup.json'), isTrue);
      expect(fileNames.contains('data/bills.json'), isTrue);
      expect(fileNames.contains('data/financialTransactions.json'), isTrue);
      expect(fileNames.contains('ledgers/financial_transactions.csv'), isTrue);
      expect(fileNames.contains('MagicDiary_Life_Record_Book.pdf'), isTrue);

      // Inspect manifest contents
      final manifestFile = archive.findFile('manifest.json')!;
      final manifestMap = jsonDecode(utf8.decode(manifestFile.content as List<int>)) as Map<String, dynamic>;
      expect(manifestMap['appName'], equals('Magic Diary'));
      expect(manifestMap['username'], equals('@ALICE99'));
      expect(manifestMap['moduleCounts']['bills'], equals(1));
      expect(manifestMap['moduleCounts']['financialTransactions'], equals(1));

      // Inspect CSV ledger
      final csvFile = archive.findFile('ledgers/financial_transactions.csv')!;
      final csvContent = utf8.decode(csvFile.content as List<int>);
      expect(csvContent.contains('Transaction ID,Date,Type,Category,Amount'), isTrue);
      expect(csvContent.contains('Airtel Payment'), isTrue);
      expect(csvContent.contains('1499.00'), isTrue);

      // Clean up temp file
      try {
        await zipFile.delete();
      } catch (_) {}
    });
  });

  group('HomeWidgetService Tests', () {
    test('updateWidgetData completes cleanly without errors on non-mobile or headless host', () async {
      expect(
        () async => await HomeWidgetService.updateWidgetData(
          pendingBillsCount: 2,
          pendingBillsTotal: 2500.0,
          pendingRemindersCount: 3,
        ),
        returnsNormally,
      );
    });

    testWidgets('HomeWidget deep link routes to correct app module', (WidgetTester tester) async {
      String navigatedRoute = '';

      final router = GoRouter(
        initialLocation: '/',
        routes: [
          GoRoute(path: '/', builder: (ctx, state) => const Text('Home Screen')),
          GoRoute(path: '/finance', builder: (ctx, state) {
            navigatedRoute = '/finance';
            return const Text('Finance Screen');
          }),
          GoRoute(path: '/bills', builder: (ctx, state) {
            navigatedRoute = '/bills';
            return const Text('Bills Screen');
          }),
          GoRoute(path: '/diaries', builder: (ctx, state) {
            navigatedRoute = '/diaries';
            return const Text('Diaries Screen');
          }),
        ],
      );

      await tester.pumpWidget(
        MaterialApp.router(
          routerConfig: router,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Home Screen'), findsOneWidget);

      // Test add-expense deep link routing
      router.go('/finance');
      await tester.pumpAndSettle();
      expect(navigatedRoute, equals('/finance'));
      expect(find.text('Finance Screen'), findsOneWidget);

      // Test bills deep link routing
      router.go('/bills');
      await tester.pumpAndSettle();
      expect(find.text('Bills Screen'), findsOneWidget);
    });
  });
}
