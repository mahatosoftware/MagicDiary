import 'package:flutter_test/flutter_test.dart';
import 'package:magic_diary/core/utils/date_calculators.dart';
import 'package:magic_diary/core/utils/formatters.dart';

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
}
