import 'package:flutter_test/flutter_test.dart';
import 'package:magic_diary/core/financial/models/recurring_schedule.dart';
import 'package:magic_diary/core/notifications/services/notification_recurrence_engine.dart';
import 'package:magic_diary/features/vehicle/models/vehicle_models.dart';

void main() {
  group('Vehicle Tenure & Recurrence Tests', () {
    test('Default vehicle model initialization defaults to 12 months for insurance and PUC', () {
      final now = DateTime(2026, 1, 1);
      final vehicle = Vehicle(
        id: 'veh_test_1',
        name: 'Daily Commute',
        type: 'Car',
        brand: 'Hyundai',
        model: 'Creta',
        registrationNumber: 'KA-01-AB-1234',
        purchaseDate: now,
        currentOdometer: 15000,
        insuranceExpiry: DateTime(2027, 1, 1),
        pucExpiry: DateTime(2027, 1, 1),
      );

      expect(vehicle.insuranceTenureMonths, 12);
      expect(vehicle.pucTenureMonths, 12);
      expect(vehicle.insuranceTenureLabel, '1 Year');
      expect(vehicle.pucTenureLabel, '1 Year');
      expect(vehicle.insuranceRepeatSchedule, 'annual');
      expect(vehicle.pucRepeatSchedule, 'annual');
    });

    test('Configurable insurance tenures map correctly to labels and recurrence schedules', () {
      final now = DateTime(2026, 3, 15);

      final v6m = Vehicle(
        id: 'v1',
        name: 'Bike',
        type: 'Bike',
        brand: 'Royal Enfield',
        model: 'Hunter 350',
        registrationNumber: 'KA-02-XY-9999',
        purchaseDate: now,
        currentOdometer: 500,
        insuranceExpiry: DateTime(2026, 9, 15),
        pucExpiry: DateTime(2026, 9, 15),
        insuranceTenureMonths: 6,
        pucTenureMonths: 6,
      );
      expect(v6m.insuranceTenureLabel, '6 Months');
      expect(v6m.insuranceRepeatSchedule, 'semi_annual');
      expect(v6m.pucTenureLabel, '6 Months');
      expect(v6m.pucRepeatSchedule, 'semi_annual');

      final v3y = v6m.copyWith(insuranceTenureMonths: 36);
      expect(v3y.insuranceTenureLabel, '3 Years');
      expect(v3y.insuranceRepeatSchedule, 'triennial');

      final v5y = v6m.copyWith(insuranceTenureMonths: 60);
      expect(v5y.insuranceTenureLabel, '5 Years');
      expect(v5y.insuranceRepeatSchedule, 'quinquennial');
    });

    test('Vehicle.calculateExpiryDate accurately projects dates across leap years and month ends', () {
      final start1 = DateTime(2026, 1, 15);
      // 6 months
      expect(Vehicle.calculateExpiryDate(start1, 6), DateTime(2026, 7, 15));
      // 12 months (1 year)
      expect(Vehicle.calculateExpiryDate(start1, 12), DateTime(2027, 1, 15));
      // 36 months (3 years)
      expect(Vehicle.calculateExpiryDate(start1, 36), DateTime(2029, 1, 15));
      // 60 months (5 years)
      expect(Vehicle.calculateExpiryDate(start1, 60), DateTime(2031, 1, 15));

      // Month clamping: Jan 31 + 1 month -> Feb 28 (non-leap year 2026)
      final jan31 = DateTime(2026, 1, 31);
      final febExpiry = Vehicle.calculateExpiryDate(jan31, 1);
      expect(febExpiry.month, 2);
      expect(febExpiry.day, 28);

      // Leap year: Jan 31 2028 + 1 month -> Feb 29 2028
      final jan31Leap = DateTime(2028, 1, 31);
      final febExpiryLeap = Vehicle.calculateExpiryDate(jan31Leap, 1);
      expect(febExpiryLeap.month, 2);
      expect(febExpiryLeap.day, 29);
    });

    test('Vehicle JSON serialization and deserialization round-trips all tenure properties', () {
      final vehicle = Vehicle(
        id: 'veh_full_serial',
        name: 'Long Haul Truck',
        type: 'Truck',
        brand: 'Tata',
        model: 'Prima',
        registrationNumber: 'DL-01-AA-9999',
        purchaseDate: DateTime(2024, 6, 1),
        currentOdometer: 45000,
        insuranceExpiry: DateTime(2027, 6, 1),
        pucExpiry: DateTime(2025, 6, 1),
        insuranceTenureMonths: 36,
        pucTenureMonths: 12,
        insuranceStartDate: DateTime(2024, 6, 1),
        pucStartDate: DateTime(2024, 6, 1),
      );

      final map = vehicle.toJson();
      expect(map['insuranceTenureMonths'], 36);
      expect(map['pucTenureMonths'], 12);
      expect(map['insuranceStartDate'], isNotNull);
      expect(map['pucStartDate'], isNotNull);

      final reconstructed = Vehicle.fromJson(map);
      expect(reconstructed.insuranceTenureMonths, 36);
      expect(reconstructed.pucTenureMonths, 12);
      expect(reconstructed.insuranceTenureLabel, '3 Years');
      expect(reconstructed.insuranceRepeatSchedule, 'triennial');
      expect(reconstructed.insuranceStartDate, DateTime(2024, 6, 1));
      expect(reconstructed.pucStartDate, DateTime(2024, 6, 1));
    });
  });

  group('ScheduleFrequency & Recurrence Engine Extended Tenure Tests', () {
    test('ScheduleFrequency parses triennial and quinquennial formats', () {
      expect(ScheduleFrequency.fromString('triennial'), ScheduleFrequency.triennial);
      expect(ScheduleFrequency.fromString('every_3_years'), ScheduleFrequency.triennial);
      expect(ScheduleFrequency.fromString('3_years'), ScheduleFrequency.triennial);
      expect(ScheduleFrequency.fromString('36_months'), ScheduleFrequency.triennial);

      expect(ScheduleFrequency.fromString('quinquennial'), ScheduleFrequency.quinquennial);
      expect(ScheduleFrequency.fromString('every_5_years'), ScheduleFrequency.quinquennial);
      expect(ScheduleFrequency.fromString('5_years'), ScheduleFrequency.quinquennial);
      expect(ScheduleFrequency.fromString('60_months'), ScheduleFrequency.quinquennial);

      expect(ScheduleFrequency.fromString('half_yearly'), ScheduleFrequency.semiAnnual);
      expect(ScheduleFrequency.fromString('6_months'), ScheduleFrequency.semiAnnual);
      expect(ScheduleFrequency.fromString('1_year'), ScheduleFrequency.annual);
    });

    test('NotificationRecurrenceEngine calculates next occurrence for multi-year vehicle schedules', () {
      final baseDate = DateTime(2026, 4, 10, 10, 0);

      // Semi-annual (6 months)
      final next6m = NotificationRecurrenceEngine.calculateNextOccurrence(
        fromDate: baseDate,
        frequency: ScheduleFrequency.semiAnnual,
      );
      expect(next6m, DateTime(2026, 10, 10, 10, 0));

      // Annual (12 months / 1 year)
      final next1y = NotificationRecurrenceEngine.calculateNextOccurrence(
        fromDate: baseDate,
        frequency: ScheduleFrequency.annual,
      );
      expect(next1y, DateTime(2027, 4, 10, 10, 0));

      // Triennial (36 months / 3 years)
      final next3y = NotificationRecurrenceEngine.calculateNextOccurrence(
        fromDate: baseDate,
        frequency: ScheduleFrequency.triennial,
      );
      expect(next3y, DateTime(2029, 4, 10, 10, 0));

      // Quinquennial (60 months / 5 years)
      final next5y = NotificationRecurrenceEngine.calculateNextOccurrence(
        fromDate: baseDate,
        frequency: ScheduleFrequency.quinquennial,
      );
      expect(next5y, DateTime(2031, 4, 10, 10, 0));
    });

    test('Configurable vehicle service intervals (6 mo, 10 mo, 1 year) calculate correct schedules', () {
      final now = DateTime(2026, 2, 1);

      // 6 months service interval
      final v6 = Vehicle(
        id: 'v_serv_6',
        name: 'Sedan',
        type: 'Car',
        brand: 'Honda',
        model: 'City',
        registrationNumber: 'MH-02-CD-5678',
        purchaseDate: now,
        currentOdometer: 10000,
        insuranceExpiry: DateTime(2027, 2, 1),
        pucExpiry: DateTime(2027, 2, 1),
        serviceIntervalMonths: 6,
      );
      expect(v6.serviceIntervalMonths, 6);
      expect(v6.serviceIntervalLabel, '6 Months');
      expect(v6.serviceRepeatSchedule, 'semi_annual');

      // 10 months service interval
      final v10 = v6.copyWith(serviceIntervalMonths: 10);
      expect(v10.serviceIntervalMonths, 10);
      expect(v10.serviceIntervalLabel, '10 Months');
      expect(v10.serviceRepeatSchedule, 'every_10_months');

      // 1 year (12 months) service interval
      final v12 = v6.copyWith(serviceIntervalMonths: 12);
      expect(v12.serviceIntervalMonths, 12);
      expect(v12.serviceIntervalLabel, '1 Year');
      expect(v12.serviceRepeatSchedule, 'annual');

      // Next service date calculation for 10 months
      final next10Date = Vehicle.calculateExpiryDate(now, 10);
      expect(next10Date, DateTime(2026, 12, 1));

      // Recurrence Engine with calculateNextOccurrenceFromSchedule for 10 months
      expect(ScheduleFrequency.parseIntervalMonths('every_10_months'), 10);
      expect(ScheduleFrequency.parseIntervalMonths('10_months'), 10);
      expect(ScheduleFrequency.parseIntervalMonths('10m'), 10);

      final nextServiceOccurrence = NotificationRecurrenceEngine.calculateNextOccurrenceFromSchedule(
        fromDate: now,
        repeatSchedule: 'every_10_months',
      );
      expect(nextServiceOccurrence, DateTime(2026, 12, 1));
    });
  });
}
