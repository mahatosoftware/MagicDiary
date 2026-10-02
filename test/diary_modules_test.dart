import 'package:flutter_test/flutter_test.dart';
import 'package:magic_diary/features/vehicle/repositories/vehicle_repository.dart';
import 'package:magic_diary/features/finance/repositories/finance_repository.dart';
import 'package:magic_diary/features/household/repositories/household_repository.dart';
import 'package:magic_diary/features/property/repositories/property_repository.dart';
import 'package:magic_diary/features/personal/repositories/personal_repository.dart';

void main() {
  group('All Diary Modules Repository Tests', () {
    test('PersonalRepository returns journals, goals, and special events', () async {
      final repo = PersonalRepository();
      final journals = await repo.getJournals('demo_user', isDemo: true);
      final goals = await repo.getGoals('demo_user', isDemo: true);
      final events = await repo.getEvents('demo_user', isDemo: true);

      expect(journals.isNotEmpty, isTrue);
      expect(goals.first.category, equals('Personal Growth'));
      expect(events.first.eventType, equals('Birthday'));
    });

    test('VehicleRepository returns mock vehicles and services', () async {
      final repo = VehicleRepository();
      final vehicles = await repo.getVehicles('demo_user', isDemo: true);
      final services = await repo.getServices('demo_user', isDemo: true);

      expect(vehicles.length, equals(2));
      expect(vehicles.first.brand, equals('Hyundai'));
      expect(services.isNotEmpty, isTrue);
    });

    test('FinanceRepository returns transactions and investments', () async {
      final repo = FinanceRepository();
      final txs = await repo.getTransactions('demo_user', isDemo: true);
      final invs = await repo.getInvestments('demo_user', isDemo: true);

      expect(txs.isNotEmpty, isTrue);
      expect(invs.first.type, equals('FD'));
    });

    test('HouseholdRepository returns utility expenses', () async {
      final repo = HouseholdRepository();
      final expenses = await repo.getExpenses('demo_user', isDemo: true);

      expect(expenses.isNotEmpty, isTrue);
      expect(expenses.any((e) => e.category == 'Electricity'), isTrue);
    });

    test('PropertyRepository returns properties and maintenance history', () async {
      final repo = PropertyRepository();
      final props = await repo.getProperties('demo_user', isDemo: true);
      final maints = await repo.getMaintenances('demo_user', isDemo: true);

      expect(props.first.propertyType, equals('Apartment'));
      expect(maints.isNotEmpty, isTrue);
    });
  });
}
