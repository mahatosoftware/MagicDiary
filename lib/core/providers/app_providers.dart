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

// Singletons
final authRepositoryProvider = Provider<AuthRepository>((ref) => AuthRepository());
final productRepositoryProvider = Provider<ProductRepository>((ref) => ProductRepository());
final schoolFeesRepositoryProvider = Provider<SchoolFeesRepository>((ref) => SchoolFeesRepository());
final billsRepositoryProvider = Provider<BillsRepository>((ref) => BillsRepository());
final documentRepositoryProvider = Provider<DocumentRepository>((ref) => DocumentRepository());
final reminderRepositoryProvider = Provider<ReminderRepository>((ref) => ReminderRepository());

final vehicleRepositoryProvider = Provider<VehicleRepository>((ref) => VehicleRepository());
final financeRepositoryProvider = Provider<FinanceRepository>((ref) => FinanceRepository());
final householdRepositoryProvider = Provider<HouseholdRepository>((ref) => HouseholdRepository());
final propertyRepositoryProvider = Provider<PropertyRepository>((ref) => PropertyRepository());
final personalRepositoryProvider = Provider<PersonalRepository>((ref) => PersonalRepository());

// Global Demo Mode state
final isDemoModeProvider = StateProvider<bool>((ref) => true);

// Auth State Provider
final userProfileProvider = StateNotifierProvider<UserNotifier, UserProfile?>((ref) {
  return UserNotifier(ref);
});

class UserNotifier extends StateNotifier<UserProfile?> {
  final Ref ref;

  UserNotifier(this.ref) : super(null) {
    loadUser();
  }

  Future<void> loadUser() async {
    final repo = ref.read(authRepositoryProvider);
    final isDemo = ref.read(isDemoModeProvider);
    repo.setDemoMode(isDemo);

    if (isDemo) {
      state = await repo.getUserProfile('demo_user_123');
    } else {
      final fbUser = repo.currentFirebaseUser;
      if (fbUser != null) {
        state = await repo.getUserProfile(fbUser.uid);
      } else {
        state = null;
      }
    }
  }

  Future<void> login(String email, String password) async {
    final repo = ref.read(authRepositoryProvider);
    state = await repo.signInWithEmail(email, password);
  }

  Future<void> register(String email, String password, String displayName) async {
    final repo = ref.read(authRepositoryProvider);
    state = await repo.registerWithEmail(email, password, displayName);
  }

  Future<void> logout() async {
    final repo = ref.read(authRepositoryProvider);
    await repo.signOut();
    state = null;
  }

  void toggleDemoMode(bool isDemo) {
    ref.read(isDemoModeProvider.notifier).state = isDemo;
    loadUser();
  }

  Future<void> updateProfile(UserProfile updated) async {
    final repo = ref.read(authRepositoryProvider);
    await repo.updateUserProfile(updated);
    state = updated;
  }
}

// Products Provider
final productsProvider = FutureProvider<List<Product>>((ref) async {
  final repo = ref.read(productRepositoryProvider);
  final isDemo = ref.watch(isDemoModeProvider);
  final user = ref.watch(userProfileProvider);
  return repo.getProducts(user?.uid ?? 'demo_user', isDemo: isDemo);
});

// Children Provider
final childrenProvider = FutureProvider<List<Child>>((ref) async {
  final repo = ref.read(schoolFeesRepositoryProvider);
  final isDemo = ref.watch(isDemoModeProvider);
  final user = ref.watch(userProfileProvider);
  return repo.getChildren(user?.uid ?? 'demo_user', isDemo: isDemo);
});

// Fee Installments Provider
final feeInstallmentsProvider = FutureProvider<List<FeeInstallment>>((ref) async {
  final repo = ref.read(schoolFeesRepositoryProvider);
  final isDemo = ref.watch(isDemoModeProvider);
  final user = ref.watch(userProfileProvider);
  return repo.getInstallments(user?.uid ?? 'demo_user', isDemo: isDemo);
});

// Bill Accounts Provider
final billAccountsProvider = FutureProvider<List<BillAccount>>((ref) async {
  final repo = ref.read(billsRepositoryProvider);
  final isDemo = ref.watch(isDemoModeProvider);
  final user = ref.watch(userProfileProvider);
  return repo.getBillAccounts(user?.uid ?? 'demo_user', isDemo: isDemo);
});

// Bills Provider
final billsProvider = FutureProvider<List<Bill>>((ref) async {
  final repo = ref.read(billsRepositoryProvider);
  final isDemo = ref.watch(isDemoModeProvider);
  final user = ref.watch(userProfileProvider);
  return repo.getBills(user?.uid ?? 'demo_user', isDemo: isDemo);
});

// Documents Provider
final documentsProvider = FutureProvider<List<DocumentRecord>>((ref) async {
  final repo = ref.read(documentRepositoryProvider);
  final isDemo = ref.watch(isDemoModeProvider);
  final user = ref.watch(userProfileProvider);
  return repo.getDocuments(user?.uid ?? 'demo_user', isDemo: isDemo);
});

// Reminders Provider
final remindersProvider = FutureProvider<List<Reminder>>((ref) async {
  final repo = ref.read(reminderRepositoryProvider);
  final isDemo = ref.watch(isDemoModeProvider);
  final user = ref.watch(userProfileProvider);
  return repo.getReminders(user?.uid ?? 'demo_user', isDemo: isDemo);
});

// Vehicles Providers
final vehiclesProvider = FutureProvider<List<Vehicle>>((ref) async {
  final repo = ref.read(vehicleRepositoryProvider);
  final isDemo = ref.watch(isDemoModeProvider);
  final user = ref.watch(userProfileProvider);
  return repo.getVehicles(user?.uid ?? 'demo_user', isDemo: isDemo);
});

final vehicleServicesProvider = FutureProvider<List<ServiceRecord>>((ref) async {
  final repo = ref.read(vehicleRepositoryProvider);
  final isDemo = ref.watch(isDemoModeProvider);
  final user = ref.watch(userProfileProvider);
  return repo.getServices(user?.uid ?? 'demo_user', isDemo: isDemo);
});

// Finance Providers
final financialTransactionsProvider = FutureProvider<List<FinancialTransaction>>((ref) async {
  final repo = ref.read(financeRepositoryProvider);
  final isDemo = ref.watch(isDemoModeProvider);
  final user = ref.watch(userProfileProvider);
  return repo.getTransactions(user?.uid ?? 'demo_user', isDemo: isDemo);
});

final investmentsProvider = FutureProvider<List<InvestmentRecord>>((ref) async {
  final repo = ref.read(financeRepositoryProvider);
  final isDemo = ref.watch(isDemoModeProvider);
  final user = ref.watch(userProfileProvider);
  return repo.getInvestments(user?.uid ?? 'demo_user', isDemo: isDemo);
});

// Household Expenses Provider
final householdExpensesProvider = FutureProvider<List<HouseholdExpense>>((ref) async {
  final repo = ref.read(householdRepositoryProvider);
  final isDemo = ref.watch(isDemoModeProvider);
  final user = ref.watch(userProfileProvider);
  return repo.getExpenses(user?.uid ?? 'demo_user', isDemo: isDemo);
});

// Property Providers
final propertiesProvider = FutureProvider<List<Property>>((ref) async {
  final repo = ref.read(propertyRepositoryProvider);
  final isDemo = ref.watch(isDemoModeProvider);
  final user = ref.watch(userProfileProvider);
  return repo.getProperties(user?.uid ?? 'demo_user', isDemo: isDemo);
});

final propertyMaintenancesProvider = FutureProvider<List<PropertyMaintenance>>((ref) async {
  final repo = ref.read(propertyRepositoryProvider);
  final isDemo = ref.watch(isDemoModeProvider);
  final user = ref.watch(userProfileProvider);
  return repo.getMaintenances(user?.uid ?? 'demo_user', isDemo: isDemo);
});

// Personal Diary Providers
final journalEntriesProvider = FutureProvider<List<JournalEntry>>((ref) async {
  final repo = ref.read(personalRepositoryProvider);
  final isDemo = ref.watch(isDemoModeProvider);
  final user = ref.watch(userProfileProvider);
  return repo.getJournals(user?.uid ?? 'demo_user', isDemo: isDemo);
});

final personalGoalsProvider = FutureProvider<List<PersonalGoal>>((ref) async {
  final repo = ref.read(personalRepositoryProvider);
  final isDemo = ref.watch(isDemoModeProvider);
  final user = ref.watch(userProfileProvider);
  return repo.getGoals(user?.uid ?? 'demo_user', isDemo: isDemo);
});

final specialEventsProvider = FutureProvider<List<SpecialEvent>>((ref) async {
  final repo = ref.read(personalRepositoryProvider);
  final isDemo = ref.watch(isDemoModeProvider);
  final user = ref.watch(userProfileProvider);
  return repo.getEvents(user?.uid ?? 'demo_user', isDemo: isDemo);
});

// Global Search Query Provider
final searchQueryProvider = StateProvider<String>((ref) => '');
