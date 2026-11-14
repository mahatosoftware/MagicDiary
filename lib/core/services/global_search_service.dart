import 'package:flutter/material.dart';
import '../../features/personal/models/personal_models.dart';
import '../../features/documents/models/document_record.dart';
import '../../features/bills/models/bills_models.dart';
import '../../features/warranty/models/product.dart';
import '../../features/vehicle/models/vehicle_models.dart';
import '../../features/property/models/property_models.dart';
import '../../features/reminders/models/reminder.dart';
import '../../features/school_fees/models/school_fees_models.dart';
import '../../features/household/models/household_models.dart';
import '../../features/domestic_help/models/domestic_help_models.dart';

class GlobalSearchResult {
  final String id;
  final String title;
  final String subtitle;
  final String module;
  final String route;
  final IconData icon;
  final DateTime? timestamp;
  final Map<String, dynamic>? extra;

  const GlobalSearchResult({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.module,
    required this.route,
    required this.icon,
    this.timestamp,
    this.extra,
  });
}

class GlobalSearchService {
  static List<GlobalSearchResult> search({
    required String query,
    List<JournalEntry> journals = const [],
    List<DocumentRecord> documents = const [],
    List<BillAccount> billAccounts = const [],
    List<Bill> bills = const [],
    List<Product> products = const [],
    List<Vehicle> vehicles = const [],
    List<Property> properties = const [],
    List<Reminder> reminders = const [],
    List<Child> children = const [],
    List<FeeInstallment> feeInstallments = const [],
    List<HouseholdExpense> householdExpenses = const [],
    List<DomesticWorker> domesticWorkers = const [],
    List<RecurringService> recurringServices = const [],
  }) {
    final cleanQuery = query.trim().toLowerCase();
    if (cleanQuery.isEmpty) return const [];

    final results = <GlobalSearchResult>[];

    // 1. Reminders & Tasks
    for (final rem in reminders) {
      if (rem.title.toLowerCase().contains(cleanQuery) ||
          rem.description.toLowerCase().contains(cleanQuery) ||
          rem.module.toLowerCase().contains(cleanQuery)) {
        results.add(GlobalSearchResult(
          id: rem.id,
          title: rem.title,
          subtitle: '${rem.module} • Due: ${rem.dueDate.day}/${rem.dueDate.month}/${rem.dueDate.year}',
          module: 'Reminders',
          route: rem.actionRoute ?? '/my-day',
          icon: Icons.notifications_active_outlined,
          timestamp: rem.dueDate,
        ));
      }
    }

    // 2. Personal Journals
    for (final j in journals) {
      final matchesTag = j.tags.any((t) => t.toLowerCase().contains(cleanQuery));
      if (j.title.toLowerCase().contains(cleanQuery) ||
          j.content.toLowerCase().contains(cleanQuery) ||
          (j.person != null && j.person!.toLowerCase().contains(cleanQuery)) ||
          (j.place != null && j.place!.toLowerCase().contains(cleanQuery)) ||
          matchesTag) {
        results.add(GlobalSearchResult(
          id: j.id,
          title: j.title.isNotEmpty ? j.title : 'Journal Entry',
          subtitle: 'Diary • ${j.mood} • ${j.date.day}/${j.date.month}/${j.date.year}',
          module: 'Personal',
          route: '/personal',
          icon: Icons.menu_book_outlined,
          timestamp: j.date,
        ));
      }
    }

    // 3. Document Library & Identity Vault
    for (final doc in documents) {
      final matchesTag = doc.tags.any((t) => t.toLowerCase().contains(cleanQuery));
      final folder = doc.folder ?? '';
      final extracted = doc.extractedText ?? '';
      if (doc.title.toLowerCase().contains(cleanQuery) ||
          doc.category.toLowerCase().contains(cleanQuery) ||
          folder.toLowerCase().contains(cleanQuery) ||
          extracted.toLowerCase().contains(cleanQuery) ||
          matchesTag) {
        results.add(GlobalSearchResult(
          id: doc.id,
          title: doc.title,
          subtitle: '${folder.isNotEmpty ? folder : doc.category}${doc.isIdentityDocument ? " (Identity Vault)" : ""}',
          module: 'Documents',
          route: '/documents',
          icon: doc.isIdentityDocument ? Icons.shield_outlined : Icons.description_outlined,
          timestamp: doc.createdAt,
        ));
      }
    }

    // 4. Bills & Subscriptions
    final accountMap = {for (final a in billAccounts) a.id: a};
    for (final b in bills) {
      final acc = accountMap[b.billAccountId];
      final accName = acc?.name ?? 'Bill';
      final provider = acc?.providerName ?? '';
      if (accName.toLowerCase().contains(cleanQuery) ||
          provider.toLowerCase().contains(cleanQuery) ||
          b.billPeriod.toLowerCase().contains(cleanQuery)) {
        results.add(GlobalSearchResult(
          id: b.id,
          title: '$accName (${b.billPeriod})',
          subtitle: '$provider • ₹${b.amount.toStringAsFixed(0)} • ${b.status}',
          module: 'Bills',
          route: '/bills',
          icon: Icons.receipt_long_outlined,
          timestamp: b.dueDate,
        ));
      }
    }

    // 5. Products & Warranties
    for (final p in products) {
      final model = p.model ?? '';
      final serial = p.serialNumber ?? '';
      if (p.name.toLowerCase().contains(cleanQuery) ||
          p.brand.toLowerCase().contains(cleanQuery) ||
          model.toLowerCase().contains(cleanQuery) ||
          serial.toLowerCase().contains(cleanQuery) ||
          p.category.toLowerCase().contains(cleanQuery)) {
        results.add(GlobalSearchResult(
          id: p.id,
          title: '${p.brand} ${p.name}',
          subtitle: '${p.category} • Model: ${model.isNotEmpty ? model : "N/A"}',
          module: 'Warranty',
          route: '/warranty',
          icon: Icons.devices_outlined,
          timestamp: p.purchaseDate,
        ));
      }
    }

    // 6. Vehicles
    for (final v in vehicles) {
      if (v.name.toLowerCase().contains(cleanQuery) ||
          v.registrationNumber.toLowerCase().contains(cleanQuery) ||
          v.brand.toLowerCase().contains(cleanQuery) ||
          v.model.toLowerCase().contains(cleanQuery)) {
        results.add(GlobalSearchResult(
          id: v.id,
          title: '${v.brand} ${v.name}',
          subtitle: 'Vehicle • Reg: ${v.registrationNumber}',
          module: 'Vehicle',
          route: '/vehicle',
          icon: Icons.directions_car_outlined,
        ));
      }
    }

    // 7. Property
    for (final prop in properties) {
      final tenant = prop.tenantName ?? '';
      if (prop.title.toLowerCase().contains(cleanQuery) ||
          prop.address.toLowerCase().contains(cleanQuery) ||
          tenant.toLowerCase().contains(cleanQuery) ||
          prop.propertyType.toLowerCase().contains(cleanQuery)) {
        results.add(GlobalSearchResult(
          id: prop.id,
          title: prop.title,
          subtitle: '${prop.propertyType} • ${prop.address}',
          module: 'Property',
          route: '/property',
          icon: Icons.apartment_outlined,
        ));
      }
    }

    // 8. School Fees
    final childMap = {for (final c in children) c.id: c.name};
    for (final fee in feeInstallments) {
      final childName = childMap[fee.childId] ?? 'Child';
      if (childName.toLowerCase().contains(cleanQuery) ||
          fee.title.toLowerCase().contains(cleanQuery)) {
        results.add(GlobalSearchResult(
          id: fee.id,
          title: '$childName: ${fee.title}',
          subtitle: 'School Fee • ₹${fee.outstandingBalance.toStringAsFixed(0)} due • ${fee.status}',
          module: 'SchoolFees',
          route: '/school-fees',
          icon: Icons.school_outlined,
          timestamp: fee.dueDate,
        ));
      }
    }

    // 9. Household
    for (final exp in householdExpenses) {
      if (exp.category.toLowerCase().contains(cleanQuery) ||
          exp.providerName.toLowerCase().contains(cleanQuery) ||
          exp.period.toLowerCase().contains(cleanQuery)) {
        results.add(GlobalSearchResult(
          id: exp.id,
          title: '${exp.category} (${exp.providerName})',
          subtitle: 'Household • ₹${exp.amount.toStringAsFixed(0)} • ${exp.period}',
          module: 'Household',
          route: '/household',
          icon: Icons.home_repair_service_outlined,
          timestamp: exp.dueDate,
        ));
      }
    }

    // 10. Domestic Workers
    for (final w in domesticWorkers) {
      if (w.name.toLowerCase().contains(cleanQuery) ||
          w.role.toLowerCase().contains(cleanQuery) ||
          w.phone.toLowerCase().contains(cleanQuery)) {
        results.add(GlobalSearchResult(
          id: w.id,
          title: '${w.name} (${w.role})',
          subtitle: 'Staff • ₹${w.baseSalary.toStringAsFixed(0)}/mo • Due: ${w.paymentDueDay}th',
          module: 'DomesticHelp',
          route: '/domestic-help',
          icon: Icons.clean_hands_outlined,
        ));
      }
    }

    // 11. Recurring Services
    for (final s in recurringServices) {
      if (s.name.toLowerCase().contains(cleanQuery) ||
          s.providerName.toLowerCase().contains(cleanQuery) ||
          s.serviceType.toLowerCase().contains(cleanQuery)) {
        results.add(GlobalSearchResult(
          id: s.id,
          title: s.name,
          subtitle: 'Daily Service • ${s.providerName} • ₹${s.unitRate.toStringAsFixed(0)}/${s.unitName}',
          module: 'DomesticHelp',
          route: '/domestic-help',
          icon: Icons.local_shipping_outlined,
        ));
      }
    }

    return results;
  }
}
