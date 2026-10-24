import 'package:flutter_test/flutter_test.dart';
import 'package:magic_diary/features/vehicle/models/vehicle_models.dart';
import 'package:magic_diary/features/finance/models/finance_models.dart';
import 'package:magic_diary/features/household/models/household_models.dart';
import 'package:magic_diary/features/property/models/property_models.dart';
import 'package:magic_diary/features/personal/models/personal_models.dart';
import 'package:magic_diary/features/school_fees/models/school_fees_models.dart';
import 'package:magic_diary/features/auth/models/user_profile.dart';
import 'package:magic_diary/features/warranty/models/product.dart';
import 'package:magic_diary/core/utils/date_calculators.dart';

void main() {
  group('Production Models Serialization Tests', () {
    test('UserProfile model serializes and deserializes correctly', () {
      final now = DateTime.now();
      final user = UserProfile(
        uid: 'user_123',
        email: 'test@magicdiary.app',
        displayName: 'Test User',
        username: 'test_user',
        currencySymbol: '₹',
        themeMode: 'dark',
        enableNotifications: true,
        createdAt: now,
        updatedAt: now,
      );

      final map = user.toMap();
      expect(map['email'], equals('test@magicdiary.app'));
      expect(map['username'], equals('test_user'));
      expect(map['displayName'], equals('Test User'));

      final fromMap = UserProfile.fromMap(map, 'user_123');
      expect(fromMap.uid, equals('user_123'));
      expect(fromMap.email, equals('test@magicdiary.app'));
      expect(fromMap.username, equals('test_user'));
    });

    test('Vehicle model toJson and fromJson work', () {
      final vehicle = Vehicle(
        id: 'veh_1',
        name: 'Creta SX',
        type: 'Car',
        brand: 'Hyundai',
        model: 'Creta',
        registrationNumber: 'KA-01-MJ-8821',
        purchaseDate: DateTime(2023, 5, 12),
        currentOdometer: 18450,
        insuranceExpiry: DateTime(2027, 5, 12),
        pucExpiry: DateTime(2027, 5, 12),
      );

      final json = vehicle.toJson();
      final fromJson = Vehicle.fromJson(json);

      expect(fromJson.name, equals('Creta SX'));
      expect(fromJson.brand, equals('Hyundai'));
      expect(fromJson.currentOdometer, equals(18450));
    });

    test('FinancialTransaction model toJson and fromJson work', () {
      final tx = FinancialTransaction(
        id: 'tx_1',
        type: 'Income',
        category: 'Salary',
        amount: 150000.0,
        date: DateTime(2026, 10, 1),
        description: 'Monthly Salary',
        paymentMethod: 'Bank Transfer',
      );

      final json = tx.toJson();
      final fromJson = FinancialTransaction.fromJson(json);

      expect(fromJson.amount, equals(150000.0));
      expect(fromJson.category, equals('Salary'));
    });

    test('HouseholdExpense model toJson and fromJson work', () {
      final expense = HouseholdExpense(
        id: 'hh_1',
        category: 'Electricity',
        providerName: 'BESCOM',
        amount: 2500.0,
        dueDate: DateTime(2026, 11, 1),
        status: 'unpaid',
        period: 'Monthly - Oct 2026',
        frequency: 'Quarterly',
      );

      final json = expense.toJson();
      final fromJson = HouseholdExpense.fromJson(json);

      expect(fromJson.category, equals('Electricity'));
      expect(fromJson.amount, equals(2500.0));
      expect(fromJson.frequency, equals('Quarterly'));
    });

    test('HouseholdExpense supports all standard payment frequencies and defaults to Monthly', () {
      expect(
        HouseholdExpense.frequencies,
        containsAll(['Monthly', 'Quarterly', 'Semi-Annual', 'Annual', 'Weekly', 'Bi-Weekly', 'Daily', 'One-Time']),
      );

      // Default frequency
      final defaultExp = HouseholdExpense(
        id: 'hh_def',
        category: 'House Rent',
        providerName: 'Landlord',
        amount: 32000.0,
        dueDate: DateTime(2026, 11, 5),
        status: 'paid',
        period: 'Monthly - Nov 2026',
      );
      expect(defaultExp.frequency, equals('Monthly'));

      // Legacy JSON without frequency
      final legacyJson = {
        'id': 'hh_leg',
        'category': 'Water',
        'providerName': 'BWSSB',
        'amount': 850.0,
        'dueDate': DateTime(2026, 11, 10).toIso8601String(),
        'status': 'unpaid',
        'period': 'Oct 2026',
      };
      final parsedLegacy = HouseholdExpense.fromJson(legacyJson);
      expect(parsedLegacy.frequency, equals('Monthly'));

      // CopyWith with different frequency
      for (final freq in ['Annual', 'Weekly', 'One-Time']) {
        final updated = defaultExp.copyWith(frequency: freq);
        expect(updated.frequency, equals(freq));
        expect(HouseholdExpense.fromJson(updated.toJson()).frequency, equals(freq));
      }
    });

    test('Property model toJson and fromJson work', () {
      final property = Property(
        id: 'prop_1',
        title: 'Apartment 302',
        propertyType: 'Apartment',
        address: 'Bellandur, Bangalore',
        purchasePrice: 8500000.0,
        purchaseDate: DateTime(2021, 3, 15),
        propertyTaxAmount: 14000.0,
        propertyTaxFrequency: 'Quarterly',
        taxDueDate: DateTime(2027, 3, 15),
      );

      final json = property.toJson();
      final fromJson = Property.fromJson(json);

      expect(fromJson.title, equals('Apartment 302'));
      expect(fromJson.purchasePrice, equals(8500000.0));
      expect(fromJson.propertyTaxFrequency, equals('Quarterly'));
      expect(fromJson.propertyTaxAmount, equals(14000.0));
    });

    test('Property model supports all tax frequencies and defaults to Annual', () {
      expect(Property.taxFrequencies, containsAll(['Annual', 'Semi-Annual', 'Quarterly', 'Monthly']));

      // Backward compatibility default
      final defaultProp = Property(
        id: 'prop_def',
        title: 'Plot 45',
        propertyType: 'Plot / Land',
        address: 'Sarjapur, Bangalore',
        purchasePrice: 4500000.0,
        purchaseDate: DateTime(2022, 1, 10),
        propertyTaxAmount: 5000.0,
        taxDueDate: DateTime(2027, 1, 10),
      );
      expect(defaultProp.propertyTaxFrequency, equals('Annual'));

      // From JSON without propertyTaxFrequency (legacy data)
      final legacyJson = {
        'id': 'prop_leg',
        'title': 'Old Villa',
        'propertyType': 'Villa',
        'address': 'Whitefield',
        'purchasePrice': 12000000.0,
        'purchaseDate': DateTime(2020, 5, 20).toIso8601String(),
        'propertyTaxAmount': 20000.0,
        'taxDueDate': DateTime(2027, 5, 20).toIso8601String(),
      };
      final parsedLegacy = Property.fromJson(legacyJson);
      expect(parsedLegacy.propertyTaxFrequency, equals('Annual'));

      // Semi-Annual and Monthly
      for (final freq in ['Semi-Annual', 'Monthly']) {
        final prop = defaultProp.copyWith(propertyTaxFrequency: freq);
        expect(prop.propertyTaxFrequency, equals(freq));
        expect(Property.fromJson(prop.toJson()).propertyTaxFrequency, equals(freq));
      }
    });

    test('PropertyMaintenance model toJson and fromJson work', () {
      final maint = PropertyMaintenance(
        id: 'maint_1',
        propertyId: 'prop_1',
        title: 'Exterior Painting',
        category: 'Painting',
        cost: 45000.0,
        date: DateTime(2026, 9, 10),
        contractorName: 'Asian Paints Pro',
      );

      final json = maint.toJson();
      final fromJson = PropertyMaintenance.fromJson(json);

      expect(fromJson.title, equals('Exterior Painting'));
      expect(fromJson.cost, equals(45000.0));
      expect(fromJson.contractorName, equals('Asian Paints Pro'));
    });

    test('InvestmentRecord model toJson and fromJson work', () {
      final inv = InvestmentRecord(
        id: 'inv_1',
        title: 'Parag Parikh Flexi Cap',
        type: 'Mutual Funds',
        investedAmount: 50000.0,
        currentAmount: 64000.0,
        maturityDate: DateTime(2030, 1, 1),
        accountNumber: 'FOLIO-9921',
      );

      final json = inv.toJson();
      final fromJson = InvestmentRecord.fromJson(json);

      expect(fromJson.title, equals('Parag Parikh Flexi Cap'));
      expect(fromJson.currentAmount, equals(64000.0));
      expect(fromJson.accountNumber, equals('FOLIO-9921'));
    });

    test('JournalEntry model toJson and fromJson work', () {
      final entry = JournalEntry(
        id: 'jrn_1',
        title: 'Productive Day',
        content: 'Went for a walk and coded.',
        date: DateTime.now(),
        mood: '😌 Calm',
        tags: ['Daily'],
      );

      final json = entry.toJson();
      final fromJson = JournalEntry.fromJson(json);

      expect(fromJson.title, equals('Productive Day'));
      expect(fromJson.mood, equals('😌 Calm'));
    });

    test('Product model with standard warranty serializes and deserializes', () {
      final now = DateTime(2026, 1, 15);
      final product = Product(
        id: 'prod_1',
        userId: 'user_123',
        name: 'Sony WH-1000XM5',
        category: 'Electronics',
        brand: 'Sony',
        model: 'WH1000XM5',
        price: 29990.0,
        sellerInfo: 'Amazon India',
        purchaseDate: now,
        hasWarranty: true,
        warrantyDurationMonths: 12,
        warrantyStartDate: now,
        warrantyEndDate: DateTime(2027, 1, 15),
        extendedWarranty: false,
        isCustomWarranty: false,
        createdAt: now,
        updatedAt: now,
      );

      final map = product.toMap();
      expect(map['name'], equals('Sony WH-1000XM5'));
      expect(map['isCustomWarranty'], isFalse);
      expect(map['warrantyDurationMonths'], equals(12));

      final fromMap = Product.fromMap(map, 'prod_1');
      expect(fromMap.id, equals('prod_1'));
      expect(fromMap.name, equals('Sony WH-1000XM5'));
      expect(fromMap.hasWarranty, isTrue);
      expect(fromMap.isCustomWarranty, isFalse);
      expect(fromMap.warrantyDurationMonths, equals(12));
    });

    test('Product model with custom warranty duration and custom warrantyType', () {
      final purchaseDate = DateTime(2026, 3, 1);
      final customEndDate = DateTime(2028, 9, 1);
      final product = Product(
        id: 'prod_custom',
        userId: 'user_456',
        name: 'Custom Mechanical Keyboard',
        category: 'Gadgets',
        brand: 'Keychron',
        price: 14500.0,
        sellerInfo: 'Keychron Store',
        purchaseDate: purchaseDate,
        hasWarranty: true,
        warrantyDurationMonths: 30,
        warrantyStartDate: purchaseDate,
        warrantyEndDate: customEndDate,
        extendedWarranty: true,
        isCustomWarranty: true,
        warrantyType: 'Extended / Third-Party',
        createdAt: purchaseDate,
        updatedAt: purchaseDate,
      );

      final map = product.toMap();
      expect(map['isCustomWarranty'], isTrue);
      expect(map['warrantyType'], equals('Extended / Third-Party'));
      expect(map['warrantyDurationMonths'], equals(30));

      final fromMap = Product.fromMap(map, 'prod_custom');
      expect(fromMap.isCustomWarranty, isTrue);
      expect(fromMap.warrantyType, equals('Extended / Third-Party'));
      expect(fromMap.warrantyDurationMonths, equals(30));
      expect(fromMap.warrantyEndDate?.year, equals(2028));
      expect(fromMap.warrantyEndDate?.month, equals(9));

      final updated = fromMap.copyWith(
        warrantyType: 'Custom',
        warrantyDurationMonths: 36,
      );
      expect(updated.isCustomWarranty, isTrue);
      expect(updated.warrantyType, equals('Custom'));
      expect(updated.warrantyDurationMonths, equals(36));
    });

    test('DateCalculators evaluates custom warranty expiration accurately', () {
      final futureDate = DateTime.now().add(const Duration(days: 45));
      final statusActive = DateCalculators.getWarrantyStatus(futureDate);
      expect(statusActive, equals('active'));

      final soonExpiring = DateTime.now().add(const Duration(days: 10));
      final statusSoon = DateCalculators.getWarrantyStatus(soonExpiring);
      expect(statusSoon, equals('expiring_soon'));

      final pastDate = DateTime.now().subtract(const Duration(days: 5));
      final statusExpired = DateCalculators.getWarrantyStatus(pastDate);
      expect(statusExpired, equals('expired'));
    });

    test('Child model serializes and deserializes schoolName and grade', () {
      final dob = DateTime(2017, 8, 15);
      final created = DateTime.now();
      final child = Child(
        id: 'child_1',
        userId: 'user_1',
        name: 'Aarav Sharma',
        dateOfBirth: dob,
        gender: 'Male',
        schoolName: 'Greenwood High International',
        grade: 'Grade 3',
        notes: 'Section B, bus route #12',
        createdAt: created,
      );

      final map = child.toMap();
      expect(map['name'], equals('Aarav Sharma'));
      expect(map['schoolName'], equals('Greenwood High International'));
      expect(map['grade'], equals('Grade 3'));

      final fromMap = Child.fromMap(map, 'child_1');
      expect(fromMap.id, equals('child_1'));
      expect(fromMap.name, equals('Aarav Sharma'));
      expect(fromMap.schoolName, equals('Greenwood High International'));
      expect(fromMap.grade, equals('Grade 3'));

      // Backward compatibility: fromMap with null schoolName / grade
      final legacyMap = {
        'userId': 'user_1',
        'name': 'Ananya',
        'dateOfBirth': dob,
        'gender': 'Female',
        'createdAt': created,
      };
      final parsedLegacy = Child.fromMap(legacyMap, 'child_legacy');
      expect(parsedLegacy.name, equals('Ananya'));
      expect(parsedLegacy.schoolName, isNull);
      expect(parsedLegacy.grade, isNull);
    });
  });
}
