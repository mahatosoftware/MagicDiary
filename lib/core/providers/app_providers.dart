import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../security/security.dart';
import '../../features/auth/repositories/auth_repository.dart';
import '../../features/auth/models/user_profile.dart';
import '../../features/warranty/repositories/product_repository.dart';
import '../../features/warranty/models/product.dart';
import '../../features/school_fees/repositories/school_fees_repository.dart';
import '../../features/school_fees/models/school_fees_models.dart';
import '../../features/bills/repositories/bills_repository.dart';
import '../../features/bills/models/bills_models.dart';
import '../../features/documents/repositories/document_repository.dart';
import '../../features/documents/models/document_record.dart';
import '../../features/reminders/repositories/reminder_repository.dart';
import '../../features/reminders/models/reminder.dart';
import '../../features/reminders/services/reminder_sync_service.dart';
import '../utils/date_calculators.dart';
import '../notifications/services/notification_manager.dart';

// New Diary Repositories
import '../../features/vehicle/repositories/vehicle_repository.dart';
import '../../features/vehicle/models/vehicle_models.dart';
import '../../features/finance/repositories/finance_repository.dart';
import '../../features/finance/models/finance_models.dart';
import '../../features/household/repositories/household_repository.dart';
import '../../features/household/models/household_models.dart';
import '../../features/property/repositories/property_repository.dart';
import '../../features/property/models/property_models.dart';

// Personal Diary Repository
import '../../features/personal/repositories/personal_repository.dart';
import '../../features/personal/models/personal_models.dart';

// Services
import '../services/global_search_service.dart';
import '../services/magic_assistant_service.dart';
import '../../features/cash_forecast/services/cash_forecast_service.dart';
import '../../features/cash_forecast/models/cash_forecast_models.dart';

// Domestic Help & Family Workspace
import '../../features/domestic_help/models/domestic_help_models.dart';
import '../../features/domestic_help/repositories/domestic_help_repository.dart';
import '../../features/household/models/household_management_models.dart';
import '../../features/household/repositories/household_workspace_repository.dart';

// Repositories
final authRepositoryProvider = Provider<AuthRepository>((ref) => AuthRepository());
final productRepositoryProvider = Provider<ProductRepository>((ref) => ProductRepository());
final schoolFeesRepositoryProvider = Provider<SchoolFeesRepository>((ref) => SchoolFeesRepository());
final billsRepositoryProvider = Provider<BillsRepository>((ref) => BillsRepository());
final documentRepositoryProvider = Provider<DocumentRepository>((ref) => DocumentRepository());
final reminderRepositoryProvider = Provider<ReminderRepository>((ref) => ReminderRepository());
final reminderSyncServiceProvider = Provider<ReminderSyncService>((ref) => ReminderSyncService());

final vehicleRepositoryProvider = Provider<VehicleRepository>((ref) => VehicleRepository());
final financeRepositoryProvider = Provider<FinanceRepository>((ref) => FinanceRepository());
final householdRepositoryProvider = Provider<HouseholdRepository>((ref) => HouseholdRepository());
final propertyRepositoryProvider = Provider<PropertyRepository>((ref) => PropertyRepository());
final personalRepositoryProvider = Provider<PersonalRepository>((ref) => PersonalRepository());
final domesticHelpRepositoryProvider = Provider<DomesticHelpRepository>((ref) => DomesticHelpRepository());
final householdWorkspaceRepositoryProvider = Provider<HouseholdWorkspaceRepository>((ref) => HouseholdWorkspaceRepository());

// App Package & Version Information
class AppInfo {
  final String appName;
  final String packageName;
  final String version;
  final String buildNumber;

  const AppInfo({
    this.appName = 'Magic Diary',
    this.packageName = 'in.mahato.magicdiary',
    this.version = '1.0.8',
    this.buildNumber = '8',
  });

  String get versionString => 'v$version+$buildNumber';
  String get displaySubtitle => '$packageName (v$version+$buildNumber Production)\nYour Life. Your Records. Your Reminders.';
}

final appInfoProvider = FutureProvider<AppInfo>((ref) async {
  try {
    final info = await PackageInfo.fromPlatform();
    return AppInfo(
      appName: info.appName.isNotEmpty ? info.appName : 'Magic Diary',
      packageName: info.packageName.isNotEmpty ? info.packageName : 'in.mahato.magicdiary',
      version: info.version.isNotEmpty ? info.version : '1.0.8',
      buildNumber: info.buildNumber.isNotEmpty ? info.buildNumber : '8',
    );
  } catch (_) {
    return const AppInfo();
  }
});

// Auth State Provider
final userProfileProvider = StateNotifierProvider<UserNotifier, UserProfile?>((ref) {
  return UserNotifier(ref);
});

class UserNotifier extends StateNotifier<UserProfile?> {
  final Ref ref;
  StreamSubscription<UserProfile?>? _authSubscription;

  UserNotifier(this.ref) : super(null) {
    _initAuthListener();
  }

  void _initAuthListener() {
    final repo = ref.read(authRepositoryProvider);
    _authSubscription = repo.authStateChanges.listen((profile) {
      state = profile;
      if (profile != null && profile.uid.isNotEmpty) {
        try {
          NotificationManager().fcmService.initialize(profile.uid);
        } catch (_) {}
      }
    });
  }

  Future<void> login(String identifier, String password) async {
    final repo = ref.read(authRepositoryProvider);
    state = await repo.signInWithUsernameOrEmail(identifier, password);
  }

  Future<UserProfile?> loginWithGoogle() async {
    final repo = ref.read(authRepositoryProvider);
    final profile = await repo.signInWithGoogle();
    if (profile != null) {
      state = profile;
    }
    return profile;
  }

  Future<void> register({
    required String email,
    required String password,
    required String displayName,
    String? username,
  }) async {
    final repo = ref.read(authRepositoryProvider);
    state = await repo.registerWithEmail(
      email: email,
      password: password,
      displayName: displayName,
      username: username,
    );
  }

  Future<void> logout() async {
    final repo = ref.read(authRepositoryProvider);
    await repo.signOut();
    state = null;
  }

  Future<void> updateProfile(UserProfile updated) async {
    final oldUsername = state?.username;
    final repo = ref.read(authRepositoryProvider);
    await repo.updateUserProfile(updated, oldUsername: oldUsername);
    state = updated;
  }

  Future<void> deleteAccount({
    String? password,
    Function(String status)? onProgress,
  }) async {
    final repo = ref.read(authRepositoryProvider);
    await repo.deleteUserAccountAndData(
      password: password,
      onProgress: onProgress,
    );
    state = null;
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }
}

// Products Provider
final productsProvider = FutureProvider<List<Product>>((ref) async {
  final user = ref.watch(userProfileProvider);
  if (user == null) return const [];
  final repo = ref.read(productRepositoryProvider);
  return repo.getProducts(user.uid);
});

// Children Provider
final childrenProvider = FutureProvider<List<Child>>((ref) async {
  final user = ref.watch(userProfileProvider);
  if (user == null) return const [];
  final repo = ref.read(schoolFeesRepositoryProvider);
  return repo.getChildren(user.uid);
});

// Fee Installments Provider
final feeInstallmentsProvider = FutureProvider<List<FeeInstallment>>((ref) async {
  final user = ref.watch(userProfileProvider);
  if (user == null) return const [];
  final repo = ref.read(schoolFeesRepositoryProvider);
  return repo.getInstallments(user.uid);
});

// Bill Accounts Provider
final billAccountsProvider = FutureProvider<List<BillAccount>>((ref) async {
  final user = ref.watch(userProfileProvider);
  if (user == null) return const [];
  final repo = ref.read(billsRepositoryProvider);
  return repo.getBillAccounts(user.uid);
});

// Bills Provider
final billsProvider = FutureProvider<List<Bill>>((ref) async {
  final user = ref.watch(userProfileProvider);
  if (user == null) return const [];
  final repo = ref.read(billsRepositoryProvider);
  return repo.getBills(user.uid);
});

// Documents Provider
final documentsProvider = FutureProvider<List<DocumentRecord>>((ref) async {
  final user = ref.watch(userProfileProvider);
  if (user == null) return const [];
  final repo = ref.read(documentRepositoryProvider);
  return repo.getDocuments(user.uid);
});

// Reminders Provider
final remindersProvider = FutureProvider<List<Reminder>>((ref) async {
  final user = ref.watch(userProfileProvider);
  if (user == null) return const [];
  final repo = ref.read(reminderRepositoryProvider);
  final rawReminders = await repo.getReminders(user.uid);
  final now = DateTime.now();

  // Normalize any annual recurring reminders (Birthdays, Anniversaries)
  // that may have been saved with historical birth/wedding years:
  final reminders = rawReminders.map((r) {
    final lowerTitle = r.title.toLowerCase();
    final isAnnual = r.module == 'Personal' &&
        (lowerTitle.contains('birthday') || lowerTitle.contains('anniversary'));
    if (isAnnual && r.dueDate.year < now.year) {
      final nextDue = DateCalculators.calculateNextOccurrence(r.dueDate, now);
      return r.copyWith(dueDate: nextDue);
    }
    return r;
  }).toList();

  final List<Reminder> synthesized = [];
  final existingIds = reminders.map((r) => r.id).toSet();

  // 1. Proactive synthesis for Personal Life Events (Birthdays, Anniversaries, Milestones)
  try {
    final events = await ref.watch(specialEventsProvider.future);
    for (final ev in events) {
      final docId = 'reminder_evt_${ev.id}';
      if (!existingIds.contains(docId)) {
        final isAnnual = ev.eventType.toLowerCase().contains('birthday') ||
            ev.eventType.toLowerCase().contains('anniversary') ||
            ev.title.toLowerCase().contains('birthday') ||
            ev.title.toLowerCase().contains('anniversary');

        final nextDue = isAnnual
            ? DateCalculators.calculateNextOccurrence(ev.date, now)
            : ev.date;

        final milestoneDesc = isAnnual && ev.date.year < now.year
            ? '${DateCalculators.formatMilestoneLabel(ev.date, ev.eventType, nextDue)}${ev.giftIdeas != null ? " • Gift Ideas: ${ev.giftIdeas}" : ""}'
            : (ev.giftIdeas != null ? 'Gift Ideas: ${ev.giftIdeas}' : '${ev.eventType} celebration');

        synthesized.add(
          Reminder(
            id: docId,
            userId: user.uid,
            title: '${ev.eventType}: ${ev.title}',
            description: milestoneDesc,
            module: 'Personal',
            status: 'pending',
            dueDate: nextDue,
            relatedId: ev.id,
            actionRoute: '/personal',
            actionType: 'Review',
            priority: 'medium',
            createdAt: ev.date,
          ),
        );
        existingIds.add(docId);
      }
    }
  } catch (_) {}

  // 2. Proactive synthesis fallback: Ensure any active properties have their
  // property tax and lease reminders seamlessly present even if Firestore is syncing.
  try {
    final properties = await ref.watch(propertiesProvider.future);

    for (final prop in properties) {
      final taxId = 'reminder_prop_${prop.id}_tax';
      if (!existingIds.contains(taxId)) {
        synthesized.add(
          Reminder(
            id: taxId,
            userId: user.uid,
            title: 'Property Tax: ${prop.title}',
            description: '${prop.propertyTaxFrequency} property tax of ₹${prop.propertyTaxAmount.toStringAsFixed(0)} for ${prop.address}.',
            module: 'Property',
            status: 'pending',
            dueDate: prop.taxDueDate,
            relatedId: prop.id,
            amount: prop.propertyTaxAmount,
            actionRoute: '/property',
            actionType: 'Pay',
            priority: 'medium',
            createdAt: prop.taxDueDate,
          ),
        );
        existingIds.add(taxId);
      }

      if (prop.leaseEndDate != null) {
        final leaseId = 'reminder_prop_${prop.id}_lease';
        if (!existingIds.contains(leaseId)) {
          final tenantInfo = prop.tenantName != null && prop.tenantName!.isNotEmpty ? ' (${prop.tenantName})' : '';
          synthesized.add(
            Reminder(
              id: leaseId,
              userId: user.uid,
              title: 'Lease Expiry: ${prop.title}',
              description: 'Lease agreement$tenantInfo for ${prop.address} expires on ${prop.leaseEndDate!.day}/${prop.leaseEndDate!.month}/${prop.leaseEndDate!.year}.',
              module: 'Property',
              status: 'pending',
              dueDate: prop.leaseEndDate!,
              relatedId: prop.id,
              actionRoute: '/property',
              actionType: 'Renew',
              priority: 'high',
              createdAt: prop.leaseEndDate!,
            ),
          );
          existingIds.add(leaseId);
        }
      }
    }
  } catch (_) {}

  if (synthesized.isNotEmpty) {
    reminders.addAll(synthesized);
  }

  // Filter: Show birthdays and anniversaries in reminder ONLY if due in the next 30 days (0 <= daysUntil <= 30)
  final today = DateTime(now.year, now.month, now.day);
  final visibleReminders = reminders.where((r) {
    final lowerTitle = r.title.toLowerCase();
    final isAnnual = r.module == 'Personal' &&
        (lowerTitle.contains('birthday') || lowerTitle.contains('anniversary'));
    if (!isAnnual) return true;

    final targetDay = DateTime(r.dueDate.year, r.dueDate.month, r.dueDate.day);
    final daysUntil = targetDay.difference(today).inDays;
    return daysUntil >= 0 && daysUntil <= 30;
  }).toList();

  visibleReminders.sort((a, b) => a.dueDate.compareTo(b.dueDate));
  return visibleReminders;
});

// Vehicles Providers
final vehiclesProvider = FutureProvider<List<Vehicle>>((ref) async {
  final user = ref.watch(userProfileProvider);
  if (user == null) return const [];
  final repo = ref.read(vehicleRepositoryProvider);
  return repo.getVehicles(user.uid);
});

final vehicleServicesProvider = FutureProvider<List<ServiceRecord>>((ref) async {
  final user = ref.watch(userProfileProvider);
  if (user == null) return const [];
  final repo = ref.read(vehicleRepositoryProvider);
  return repo.getServices(user.uid);
});

// Finance Providers
final financialTransactionsProvider = FutureProvider<List<FinancialTransaction>>((ref) async {
  final user = ref.watch(userProfileProvider);
  if (user == null) return const [];
  final repo = ref.read(financeRepositoryProvider);
  return repo.getTransactions(user.uid);
});

final investmentsProvider = FutureProvider<List<InvestmentRecord>>((ref) async {
  final user = ref.watch(userProfileProvider);
  if (user == null) return const [];
  final repo = ref.read(financeRepositoryProvider);
  return repo.getInvestments(user.uid);
});

// Household Expenses & Budgets Provider
final householdExpensesProvider = FutureProvider<List<HouseholdExpense>>((ref) async {
  final user = ref.watch(userProfileProvider);
  if (user == null) return const [];
  final repo = ref.read(householdRepositoryProvider);
  return repo.getExpenses(user.uid);
});

final householdBudgetsProvider = FutureProvider<List<HouseholdBudget>>((ref) async {
  final user = ref.watch(userProfileProvider);
  if (user == null) return const [];
  final repo = ref.read(householdRepositoryProvider);
  return repo.getBudgets(user.uid);
});

final shoppingListProvider = FutureProvider<List<ShoppingItem>>((ref) async {
  final user = ref.watch(userProfileProvider);
  if (user == null) return const [];
  final repo = ref.read(householdRepositoryProvider);
  return repo.getShoppingItems(user.uid);
});

// Property Providers
final propertiesProvider = FutureProvider<List<Property>>((ref) async {
  final user = ref.watch(userProfileProvider);
  if (user == null) return const [];
  final repo = ref.read(propertyRepositoryProvider);
  return repo.getProperties(user.uid);
});

final propertyMaintenancesProvider = FutureProvider<List<PropertyMaintenance>>((ref) async {
  final user = ref.watch(userProfileProvider);
  if (user == null) return const [];
  final repo = ref.read(propertyRepositoryProvider);
  return repo.getMaintenances(user.uid);
});

// Personal Diary Providers
final journalEntriesProvider = FutureProvider<List<JournalEntry>>((ref) async {
  final user = ref.watch(userProfileProvider);
  if (user == null) return const [];
  final repo = ref.read(personalRepositoryProvider);
  return repo.getJournals(user.uid);
});

final personalGoalsProvider = FutureProvider<List<PersonalGoal>>((ref) async {
  final user = ref.watch(userProfileProvider);
  if (user == null) return const [];
  final repo = ref.read(personalRepositoryProvider);
  return repo.getGoals(user.uid);
});

final specialEventsProvider = FutureProvider<List<SpecialEvent>>((ref) async {
  final user = ref.watch(userProfileProvider);
  if (user == null) return const [];
  final repo = ref.read(personalRepositoryProvider);
  return repo.getEvents(user.uid);
});

final habitsProvider = FutureProvider<List<Habit>>((ref) async {
  final user = ref.watch(userProfileProvider);
  if (user == null) return const [];
  final repo = ref.read(personalRepositoryProvider);
  return repo.getHabits(user.uid);
});

// Global Search Query Provider
final searchQueryProvider = StateProvider<String>((ref) => '');

// Global Search Results Provider
final globalSearchResultsProvider = Provider<List<GlobalSearchResult>>((ref) {
  final query = ref.watch(searchQueryProvider);
  if (query.trim().isEmpty) return const [];

  final journals = ref.watch(journalEntriesProvider).value ?? const [];
  final documents = ref.watch(documentsProvider).value ?? const [];
  final billAccounts = ref.watch(billAccountsProvider).value ?? const [];
  final bills = ref.watch(billsProvider).value ?? const [];
  final products = ref.watch(productsProvider).value ?? const [];
  final vehicles = ref.watch(vehiclesProvider).value ?? const [];
  final properties = ref.watch(propertiesProvider).value ?? const [];
  final reminders = ref.watch(remindersProvider).value ?? const [];
  final children = ref.watch(childrenProvider).value ?? const [];
  final feeInstallments = ref.watch(feeInstallmentsProvider).value ?? const [];
  final householdExpenses = ref.watch(householdExpensesProvider).value ?? const [];
  final domesticWorkers = ref.watch(domesticWorkersProvider).value ?? const [];
  final recurringServices = ref.watch(recurringServicesProvider).value ?? const [];

  return GlobalSearchService.search(
    query: query,
    journals: journals,
    documents: documents,
    billAccounts: billAccounts,
    bills: bills,
    products: products,
    vehicles: vehicles,
    properties: properties,
    reminders: reminders,
    children: children,
    feeInstallments: feeInstallments,
    householdExpenses: householdExpenses,
    domesticWorkers: domesticWorkers,
    recurringServices: recurringServices,
  );
});

// Magic Assistant Proactive Insights Provider
final magicAssistantInsightsProvider = Provider<List<MagicInsight>>((ref) {
  final now = DateTime.now();
  final reminders = ref.watch(remindersProvider).value ?? const [];
  final products = ref.watch(productsProvider).value ?? const [];
  final vehicles = ref.watch(vehiclesProvider).value ?? const [];
  final billAccounts = ref.watch(billAccountsProvider).value ?? const [];
  final bills = ref.watch(billsProvider).value ?? const [];
  final budgets = ref.watch(householdBudgetsProvider).value ?? const [];
  final householdExpenses = ref.watch(householdExpensesProvider).value ?? const [];

  return MagicAssistantService.generateInsights(
    now: now,
    reminders: reminders,
    products: products,
    vehicles: vehicles,
    billAccounts: billAccounts,
    bills: bills,
    budgets: budgets,
    householdExpenses: householdExpenses,
  );
});

// --- Domestic Help & Recurring Services Providers ---
final domesticWorkersProvider = FutureProvider<List<DomesticWorker>>((ref) async {
  final user = ref.watch(userProfileProvider);
  if (user == null) return const [];
  final repo = ref.read(domesticHelpRepositoryProvider);
  return repo.getWorkers(user.uid);
});

final todayWorkerAttendanceProvider = FutureProvider<List<WorkerAttendance>>((ref) async {
  final user = ref.watch(userProfileProvider);
  if (user == null) return const [];
  final repo = ref.read(domesticHelpRepositoryProvider);
  return repo.getAttendanceForDate(user.uid, DateTime.now());
});

final salaryStatementsProvider = FutureProvider<List<SalaryStatement>>((ref) async {
  final user = ref.watch(userProfileProvider);
  if (user == null) return const [];
  final repo = ref.read(domesticHelpRepositoryProvider);
  return repo.getSalaryStatements(user.uid);
});

final recurringServicesProvider = FutureProvider<List<RecurringService>>((ref) async {
  final user = ref.watch(userProfileProvider);
  if (user == null) return const [];
  final repo = ref.read(domesticHelpRepositoryProvider);
  return repo.getRecurringServices(user.uid);
});

final todayServiceEntriesProvider = FutureProvider<List<ServiceEntry>>((ref) async {
  final user = ref.watch(userProfileProvider);
  if (user == null) return const [];
  final repo = ref.read(domesticHelpRepositoryProvider);
  return repo.getDailyServiceEntries(user.uid, DateTime.now());
});

// --- Shared Family Workspace Providers ---
final userHouseholdsProvider = FutureProvider<List<Household>>((ref) async {
  final user = ref.watch(userProfileProvider);
  if (user == null) return const [];
  final repo = ref.read(householdWorkspaceRepositoryProvider);
  return repo.getUserHouseholds(user.uid);
});

final activeHouseholdIdProvider = StateProvider<String?>((ref) => null);

final activeHouseholdTasksProvider = FutureProvider<List<HouseholdTask>>((ref) async {
  final hId = ref.watch(activeHouseholdIdProvider);
  if (hId == null || hId.isEmpty) return const [];
  final repo = ref.read(householdWorkspaceRepositoryProvider);
  return repo.getTasks(hId);
});

final activeHouseholdSettlementsProvider = FutureProvider<List<InterMemberSettlement>>((ref) async {
  final hId = ref.watch(activeHouseholdIdProvider);
  if (hId == null || hId.isEmpty) return const [];
  final repo = ref.read(householdWorkspaceRepositoryProvider);
  return repo.getSettlements(hId);
});

// --- Cash Commitment Forecast Providers ---
final forecastDaysProvider = StateProvider<int>((ref) => 30); // 7, 30, 90
final forecastSafetyBufferProvider = StateProvider<double>((ref) => 0.0);
final forecastActiveScenarioProvider = StateProvider<ForecastScenario?>((ref) => null);
final forecastManualStartingCashProvider = StateProvider<double?>((ref) => null);

final cashForecastSummaryProvider = Provider<ForecastSummary>((ref) {
  final now = DateTime.now();
  final days = ref.watch(forecastDaysProvider);
  final buffer = ref.watch(forecastSafetyBufferProvider);
  final scenario = ref.watch(forecastActiveScenarioProvider);

  final manualCash = ref.watch(forecastManualStartingCashProvider);
  final txs = ref.watch(financialTransactionsProvider).value ?? const [];
  double startingCash = manualCash ?? 45000.0; // Sensible starting baseline if uncalibrated
  if (manualCash == null && txs.isNotEmpty) {
    double computed = 0.0;
    for (final t in txs) {
      if (t.type.toLowerCase() == 'income') {
        computed += t.amount;
      } else if (t.type.toLowerCase() == 'expense') {
        computed -= t.amount;
      }
    }
    if (computed > 0) startingCash = computed;
  }

  final bills = ref.watch(billsProvider).value ?? const [];
  final feeInstallments = ref.watch(feeInstallmentsProvider).value ?? const [];
  final vehicles = ref.watch(vehiclesProvider).value ?? const [];
  final properties = ref.watch(propertiesProvider).value ?? const [];
  final householdExpenses = ref.watch(householdExpensesProvider).value ?? const [];
  final workers = ref.watch(domesticWorkersProvider).value ?? const [];
  final recurringServices = ref.watch(recurringServicesProvider).value ?? const [];

  return CashForecastService.generateForecast(
    now: now,
    startingCashBalance: startingCash,
    safetyBuffer: buffer,
    forecastDays: days,
    bills: bills,
    feeInstallments: feeInstallments,
    vehicles: vehicles,
    properties: properties,
    householdExpenses: householdExpenses,
    domesticWorkers: workers,
    recurringServices: recurringServices,
    scenario: scenario,
  );
});

// --- Centralized Security Providers ---
final secureStorageServiceProvider = Provider<SecureStorageService>((ref) => SecureStorageService());
final authSecurityServiceProvider = Provider<AuthSecurityService>((ref) => AuthSecurityService());
final sessionManagementServiceProvider = Provider<SessionManagementService>((ref) => SessionManagementService());
final circlePermissionServiceProvider = Provider<CirclePermissionService>((ref) => CirclePermissionService());
final attachmentSecurityServiceProvider = Provider<AttachmentSecurityService>((ref) => AttachmentSecurityService());
final appCheckServiceProvider = Provider<AppCheckService>((ref) => AppCheckService());
final notificationPrivacyServiceProvider = Provider<NotificationPrivacyService>((ref) => NotificationPrivacyService());
final voiceIntegrationSecurityServiceProvider = Provider<VoiceIntegrationSecurityService>((ref) => VoiceIntegrationSecurityService());
final securityAuditServiceProvider = Provider<SecurityAuditService>((ref) => SecurityAuditService());
final dataExportSecurityServiceProvider = Provider<DataExportSecurityService>((ref) => DataExportSecurityService());

