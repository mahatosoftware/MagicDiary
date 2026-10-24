import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
    final repo = ref.read(authRepositoryProvider);
    await repo.updateUserProfile(updated);
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
  return repo.getReminders(user.uid);
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

// Household Expenses Provider
final householdExpensesProvider = FutureProvider<List<HouseholdExpense>>((ref) async {
  final user = ref.watch(userProfileProvider);
  if (user == null) return const [];
  final repo = ref.read(householdRepositoryProvider);
  return repo.getExpenses(user.uid);
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

// Global Search Query Provider
final searchQueryProvider = StateProvider<String>((ref) => '');
