import 'package:flutter_test/flutter_test.dart';
import 'package:magic_diary/core/utils/date_calculators.dart';
import 'package:magic_diary/core/utils/formatters.dart';
import 'package:magic_diary/core/diary_engine/models/diary_record.dart';
import 'package:magic_diary/core/providers/app_providers.dart';

void main() {
  group('DateCalculators Unit Tests', () {
    test('getWarrantyStatus returns active for future date', () {
      final futureDate = DateTime.now().add(const Duration(days: 60));
      expect(DateCalculators.getWarrantyStatus(futureDate), equals('active'));
    });

    test('getWarrantyStatus returns expiring_soon for date within 30 days', () {
      final soonDate = DateTime.now().add(const Duration(days: 15));
      expect(DateCalculators.getWarrantyStatus(soonDate), equals('expiring_soon'));
    });

    test('getWarrantyStatus returns expired for past date', () {
      final pastDate = DateTime.now().subtract(const Duration(days: 10));
      expect(DateCalculators.getWarrantyStatus(pastDate), equals('expired'));
    });

    test('calculateDeferredDate defer options work correctly', () {
      final base = DateTime(2026, 10, 1);
      
      final d1 = DateCalculators.calculateDeferredDate(base, DeferOption.plus1Day);
      expect(d1, equals(DateTime(2026, 10, 2)));

      final dWeek = DateCalculators.calculateDeferredDate(base, DeferOption.plus1Week);
      expect(dWeek, equals(DateTime(2026, 10, 8)));

      final dMonth = DateCalculators.calculateDeferredDate(base, DeferOption.plus1Month);
      expect(dMonth, equals(DateTime(2026, 11, 1)));
    });

    test('generateSchoolFeeSchedule generates quarterly installments correctly', () {
      final schedule = DateCalculators.generateSchoolFeeSchedule(
        feeStructureId: 'fs_1',
        childId: 'child_1',
        totalAmount: 120000,
        frequency: 'Quarterly',
        numberOfInstallments: 4,
        firstDueDate: DateTime(2026, 4, 10),
      );

      expect(schedule.length, equals(4));
      expect(schedule[0]['amount'], equals(30000.0));
      expect(schedule[0]['dueDate'], equals(DateTime(2026, 4, 10)));
      expect(schedule[1]['dueDate'], equals(DateTime(2026, 7, 10)));
    });
  });

  group('Formatters Unit Tests', () {
    test('currency formatting works', () {
      expect(AppFormatters.currency(12000), contains('12,000'));
    });

    test('daysRemaining text formatting works', () {
      expect(AppFormatters.daysRemaining(15), equals('15 days left'));
      expect(AppFormatters.daysRemaining(0), equals('Expires today'));
      expect(AppFormatters.daysRemaining(-5), contains('Expired'));
    });
  });

  group('Duplicate Detection Unit Tests', () {
    test('findPotentialDuplicate logic flags matching title on same date', () {
      final records = [
        {
          'id': 'rec_1',
          'title': 'Hyundai i20 Insurance',
          'recordDate': DateTime(2026, 11, 15),
        },
        {
          'id': 'rec_2',
          'title': 'Electricity Bill - BESCOM',
          'recordDate': DateTime(2026, 11, 20),
        },
      ];

      // Exact match case-insensitive
      bool isDuplicate(String title, DateTime date, [String? excludeId]) {
        final clean = title.trim().toLowerCase();
        for (final r in records) {
          if (excludeId != null && r['id'] == excludeId) continue;
          if ((r['title'] as String).trim().toLowerCase() == clean) {
            final recDate = r['recordDate'] as DateTime;
            if (recDate.year == date.year &&
                recDate.month == date.month &&
                recDate.day == date.day) {
              return true;
            }
          }
        }
        return false;
      }

      expect(isDuplicate('hyundai i20 insurance', DateTime(2026, 11, 15)), isTrue);
      expect(isDuplicate('Hyundai i20 Insurance', DateTime(2026, 11, 16)), isFalse); // different date
      expect(isDuplicate('Water Bill', DateTime(2026, 11, 15)), isFalse); // different title
      expect(isDuplicate('Hyundai i20 Insurance', DateTime(2026, 11, 15), 'rec_1'), isFalse); // excluded self
    });
  });

  group('DiaryRecord Reminder & Repeat Schedule Unit Tests', () {
    test('DiaryRecord correctly serializes and deserializes remindBeforeDays and repeatSchedule', () {
      final now = DateTime(2026, 11, 18, 10, 0);
      final record = DiaryRecord(
        id: 'rec_rem_1',
        ownerId: 'user_1',
        sourceDiaryId: 'vehicle_insurance',
        title: 'Car Insurance Renewal',
        recordDate: DateTime(2026, 12, 1),
        remindBeforeDays: [30, 15, 7, 1, 0],
        repeatSchedule: 'yearly',
        reminderId: 'reminder_record_rec_rem_1',
        createdBy: 'user_1',
        updatedBy: 'user_1',
        createdAt: now,
        updatedAt: now,
      );

      expect(record.hasReminder, isTrue);
      expect(record.remindBeforeDays, equals([30, 15, 7, 1, 0]));
      expect(record.repeatSchedule, equals('yearly'));

      final map = record.toMap();
      expect(map['remindBeforeDays'], equals([30, 15, 7, 1, 0]));
      expect(map['repeatSchedule'], equals('yearly'));
      expect(map['hasReminder'], isTrue);

      final restored = DiaryRecord.fromMap(map, 'rec_rem_1');
      expect(restored.id, equals('rec_rem_1'));
      expect(restored.hasReminder, isTrue);
      expect(restored.remindBeforeDays, equals([30, 15, 7, 1, 0]));
      expect(restored.repeatSchedule, equals('yearly'));
      expect(restored.reminderId, equals('reminder_record_rec_rem_1'));
    });

    test('DiaryRecord hasReminder is false when remindBeforeDays is empty and no reminderId', () {
      final now = DateTime.now();
      final record = DiaryRecord(
        id: 'rec_no_rem',
        ownerId: 'user_1',
        sourceDiaryId: 'notes',
        title: 'General Note',
        recordDate: now,
        createdBy: 'user_1',
        updatedBy: 'user_1',
        createdAt: now,
        updatedAt: now,
      );

      expect(record.hasReminder, isFalse);
      expect(record.remindBeforeDays, isEmpty);
      expect(record.repeatSchedule, equals('one_time'));
    });
  });

  group('AppInfo Application Version Unit Tests', () {
    test('AppInfo formats actual app version and build number correctly', () {
      const appInfo = AppInfo(
        appName: 'Magic Diary',
        packageName: 'in.mahato.magicdiary',
        version: '1.0.7',
        buildNumber: '7',
      );

      expect(appInfo.versionString, equals('v1.0.7+7'));
      expect(appInfo.displaySubtitle, contains('in.mahato.magicdiary (v1.0.7+7 Production)'));
      expect(appInfo.displaySubtitle, contains('Your Life. Your Records. Your Reminders.'));
    });
  });
}
