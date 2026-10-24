import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/financial_transaction.dart';
import '../models/financial_obligation.dart';
import '../repositories/financial_transaction_repository.dart';
import '../repositories/financial_obligation_repository.dart';
import '../services/financial_migration_service.dart';
import '../../providers/app_providers.dart';

final canonicalTxRepositoryProvider = Provider<FinancialTransactionRepository>((ref) {
  return FinancialTransactionRepository();
});

final canonicalObligationRepositoryProvider = Provider<FinancialObligationRepository>((ref) {
  return FinancialObligationRepository();
});

final financialMigrationServiceProvider = Provider<FinancialMigrationService>((ref) {
  final txRepo = ref.watch(canonicalTxRepositoryProvider);
  final obRepo = ref.watch(canonicalObligationRepositoryProvider);
  return FinancialMigrationService(txRepo: txRepo, obRepo: obRepo);
});

final canonicalTransactionsProvider = FutureProvider<List<FinancialTransaction>>((ref) async {
  final user = ref.watch(userProfileProvider);
  if (user == null) return const [];
  final repo = ref.watch(canonicalTxRepositoryProvider);
  return repo.getTransactions(user.uid);
});

final canonicalObligationsProvider = FutureProvider<List<FinancialObligation>>((ref) async {
  final user = ref.watch(userProfileProvider);
  if (user == null) return const [];
  final repo = ref.watch(canonicalObligationRepositoryProvider);
  return repo.getObligations(user.uid);
});
