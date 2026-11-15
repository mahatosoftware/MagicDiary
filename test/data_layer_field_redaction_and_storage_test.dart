import 'package:flutter_test/flutter_test.dart';
import 'package:magic_diary/core/diary_engine/models/diary_record.dart';
import 'package:magic_diary/core/security/diary_access_control_service.dart';
import 'package:magic_diary/features/shared_diaries/models/shared_diary_models.dart';

void main() {
  group('Option A: Data-Layer Field Redaction & Storage Security Test Suite', () {
    const ownerUid = 'user_owner_001';
    const collaboratorUid = 'user_collab_002';

    test('Data-Layer Redaction: Sensitive fields are stripped from base record when restricted', () {
      final originalRecord = DiaryRecord(
        id: 'rec_fin_001',
        ownerId: ownerUid,
        sourceDiaryId: 'finances',
        title: 'Vendor Payout - Acme Supplies',
        subtitle: 'Invoice #8892',
        recordDate: DateTime(2026, 11, 15),
        amount: 45000.0,
        currency: 'INR',
        status: 'active',
        fields: {
          'category': 'Procurement',
          'accountNumber': 'HDFC000123456789',
          'vendorNotes': 'Confidential contract terms 15% discount',
          'paymentMode': 'NEFT',
        },
        restrictedFields: ['amount', 'accountNumber', 'vendorNotes'],
        createdBy: ownerUid,
        updatedBy: ownerUid,
        createdAt: DateTime(2026, 11, 15),
        updatedAt: DateTime(2026, 11, 15),
      );

      // Simulate Option A data separation:
      final sensitiveData = <String, dynamic>{};
      final publicFields = Map<String, dynamic>.from(originalRecord.fields);

      for (final key in originalRecord.restrictedFields) {
        if (publicFields.containsKey(key)) {
          sensitiveData[key] = publicFields.remove(key);
        }
      }

      final isAmountRestricted = originalRecord.restrictedFields.contains('amount');
      if (isAmountRestricted && originalRecord.amount != null) {
        sensitiveData['amount'] = originalRecord.amount;
      }

      final baseDoc = originalRecord.copyWith(
        fields: publicFields,
        clearAmount: isAmountRestricted,
      );

      // Verify base document has zero confidential data
      expect(baseDoc.amount, isNull, reason: 'Restricted amount must not exist in base document');
      expect(baseDoc.fields.containsKey('accountNumber'), isFalse, reason: 'Account number must be absent');
      expect(baseDoc.fields.containsKey('vendorNotes'), isFalse, reason: 'Vendor notes must be absent');
      expect(baseDoc.fields['category'], equals('Procurement'));
      expect(baseDoc.fields['paymentMode'], equals('NEFT'));

      // Verify private_data details holds the isolated sensitive payload
      expect(sensitiveData['amount'], equals(45000.0));
      expect(sensitiveData['accountNumber'], equals('HDFC000123456789'));
      expect(sensitiveData['vendorNotes'], equals('Confidential contract terms 15% discount'));

      // Verify transparent merging for authorized callers
      final mergedFields = Map<String, dynamic>.from(baseDoc.fields)..addAll(sensitiveData);
      final restoredRecord = baseDoc.copyWith(
        fields: mergedFields,
        amount: (sensitiveData['amount'] as num?)?.toDouble() ?? baseDoc.amount,
      );

      expect(restoredRecord.amount, equals(45000.0));
      expect(restoredRecord.fields['accountNumber'], equals('HDFC000123456789'));
      expect(restoredRecord.fields['vendorNotes'], equals('Confidential contract terms 15% discount'));
      expect(restoredRecord.fields['category'], equals('Procurement'));
    });

    test('Access Control Service enforces field redaction and attachment restrictions', () {
      final record = DiaryRecord(
        id: 'rec_fin_002',
        ownerId: ownerUid,
        sourceDiaryId: 'finances',
        title: 'Confidential Salary Record',
        recordDate: DateTime(2026, 11, 15),
        amount: 120000.0,
        fields: {
          'employeeName': 'Jane Doe',
          'salary': 120000.0,
          'panNumber': 'ABCDE1234F',
          'department': 'Engineering',
        },
        attachmentIds: ['doc_payslip_001', 'doc_tax_002'],
        createdBy: ownerUid,
        updatedBy: ownerUid,
        createdAt: DateTime(2026, 11, 15),
        updatedAt: DateTime(2026, 11, 15),
      );

      final restrictedShare = SharedDiaryAccess(
        id: 'share_collab_1',
        diaryId: 'finances',
        diaryName: 'Finances',
        ownerUid: ownerUid,
        ownerName: 'Owner',
        sharedWithUid: collaboratorUid,
        sharedWithEmail: 'collab@test.com',
        sharedWithName: 'Collab',
        permission: SharedDiaryPermission.viewer,
        allowAttachments: false, // Attachment download blocked
        restrictedFields: ['amount', 'salary', 'panNumber'],
        createdAt: DateTime(2026, 11, 10),
        updatedAt: DateTime(2026, 11, 10),
      );

      final filtered = DiaryAccessControlService.filterRecordFieldsForUser(
        record: record,
        shareAccess: restrictedShare,
      );

      // Verify amount, salary, and panNumber are completely redacted
      expect(filtered.amount, isNull);
      expect(filtered.fields.containsKey('salary'), isFalse);
      expect(filtered.fields.containsKey('panNumber'), isFalse);
      expect(filtered.fields['employeeName'], equals('Jane Doe'));
      expect(filtered.fields['department'], equals('Engineering'));

      // Verify attachments are blocked
      expect(filtered.attachmentIds, isEmpty);
    });

    test('Access Control Service permits attachments and non-restricted fields for unrestricted shares', () {
      final record = DiaryRecord(
        id: 'rec_household_003',
        ownerId: ownerUid,
        sourceDiaryId: 'household',
        title: 'Electricity Bill',
        recordDate: DateTime(2026, 11, 15),
        amount: 2450.0,
        fields: {
          'meterNumber': 'MET998811',
          'dueDate': '2026-11-30',
        },
        attachmentIds: ['bill_receipt_pdf'],
        createdBy: ownerUid,
        updatedBy: ownerUid,
        createdAt: DateTime(2026, 11, 15),
        updatedAt: DateTime(2026, 11, 15),
      );

      final fullShare = SharedDiaryAccess(
        id: 'share_collab_full',
        diaryId: 'household',
        diaryName: 'Household',
        ownerUid: ownerUid,
        ownerName: 'Owner',
        sharedWithUid: collaboratorUid,
        sharedWithEmail: 'collab@test.com',
        sharedWithName: 'Collab',
        permission: SharedDiaryPermission.editor,
        allowAttachments: true,
        restrictedFields: const [],
        createdAt: DateTime(2026, 11, 10),
        updatedAt: DateTime(2026, 11, 10),
      );

      final filtered = DiaryAccessControlService.filterRecordFieldsForUser(
        record: record,
        shareAccess: fullShare,
      );

      expect(filtered.amount, equals(2450.0));
      expect(filtered.fields['meterNumber'], equals('MET998811'));
      expect(filtered.attachmentIds, equals(['bill_receipt_pdf']));
    });
  });
}
