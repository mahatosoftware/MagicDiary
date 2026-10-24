import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/financial_transaction.dart';
import '../models/financial_obligation.dart';
import '../models/financial_category.dart';
import '../repositories/financial_transaction_repository.dart';
import '../repositories/financial_obligation_repository.dart';

import '../../../../features/finance/models/finance_models.dart' as legacy_finance;
import '../../../../features/household/models/household_models.dart';
import '../../../../features/school_fees/models/school_fees_models.dart';
import '../../../../features/vehicle/models/vehicle_models.dart';
import '../../../../features/property/models/property_models.dart';
import '../../../../features/bills/models/bills_models.dart';

class MigrationReconciliationReport {
  final String userId;
  final DateTime executedAt;
  final int legacyTransactionsRead;
  final int canonicalTransactionsWritten;
  final int canonicalObligationsWritten;
  final double legacySumAmount;
  final double canonicalIncomeSum;
  final double canonicalExpenseSum;
  final double canonicalObligationDueSum;
  final Map<String, int> moduleBreakdown;
  final List<String> auditLogs;

  const MigrationReconciliationReport({
    required this.userId,
    required this.executedAt,
    required this.legacyTransactionsRead,
    required this.canonicalTransactionsWritten,
    required this.canonicalObligationsWritten,
    required this.legacySumAmount,
    required this.canonicalIncomeSum,
    required this.canonicalExpenseSum,
    required this.canonicalObligationDueSum,
    required this.moduleBreakdown,
    required this.auditLogs,
  });

  bool get isBalanced => (legacyTransactionsRead == canonicalTransactionsWritten);
}

/// Service that performs safe, idempotent backfills from legacy module collections
/// into the canonical `financialTransactions` and `financialObligations` collections.
class FinancialMigrationService {
  final FirebaseFirestore _firestore;
  final FinancialTransactionRepository _txRepo;
  final FinancialObligationRepository _obRepo;

  FinancialMigrationService({
    FirebaseFirestore? firestore,
    FinancialTransactionRepository? txRepo,
    FinancialObligationRepository? obRepo,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _txRepo = txRepo ?? FinancialTransactionRepository(firestore: firestore),
        _obRepo = obRepo ?? FinancialObligationRepository(firestore: firestore);

  /// Execute idempotent migration and return reconciliation audit report
  Future<MigrationReconciliationReport> migrateAllModules(String userId) async {
    if (userId.isEmpty) throw ArgumentError('userId cannot be empty');

    final List<String> logs = [];
    final Map<String, int> moduleCounts = {};
    int legacyRead = 0;
    double legacySum = 0.0;

    final List<FinancialTransaction> canonicalTxList = [];
    final List<FinancialObligation> canonicalObList = [];

    logs.add('Starting Migration for user: $userId at ${DateTime.now().toIso8601String()}');

    // 1. Migrate Personal Finance Transactions
    try {
      final snap = await _firestore.collection('users').doc(userId).collection('transactions').get();
      int fCount = 0;
      for (final doc in snap.docs) {
        final legacyTx = legacy_finance.FinancialTransaction.fromJson(doc.data());
        legacyRead++;
        legacySum += legacyTx.amount;
        fCount++;

        final isIncome = legacyTx.type.toLowerCase() == 'income';
        final isTransfer = legacyTx.type.toLowerCase() == 'transfer' ||
            legacyTx.category.toLowerCase().contains('sip') ||
            legacyTx.category.toLowerCase().contains('investment');

        TransactionType type = TransactionType.expense;
        if (isTransfer) {
          type = TransactionType.transfer;
        } else if (isIncome) {
          type = TransactionType.income;
        }

        final catId = CategoryRegistry.mapLegacyToCategoryId(legacyTx.category, legacyTx.description);

        canonicalTxList.add(FinancialTransaction.fromMajorUnits(
          id: FinancialTransaction.generateDeterministicId('finance', legacyTx.id),
          userId: userId,
          type: type,
          amountMajor: legacyTx.amount,
          categoryId: catId,
          sourceModule: 'finance',
          sourceRecordId: legacyTx.id,
          description: legacyTx.description.isNotEmpty ? legacyTx.description : legacyTx.category,
          transactionDate: legacyTx.date,
          paymentMethod: legacyTx.paymentMethod,
        ));
      }
      moduleCounts['finance'] = fCount;
      logs.add('Finance module: processed $fCount legacy transactions.');
    } catch (e) {
      logs.add('Finance module error: $e');
    }

    // 2. Migrate Household Expenses (Paid -> Transaction, Unpaid -> Obligation)
    try {
      final snap = await _firestore.collection('users').doc(userId).collection('householdExpenses').get();
      int hTx = 0;
      int hOb = 0;
      for (final doc in snap.docs) {
        final h = HouseholdExpense.fromJson(doc.data());
        final isPaid = h.status.toLowerCase() == 'paid';
        final catId = CategoryRegistry.mapLegacyToCategoryId(h.category, h.providerName);

        if (isPaid) {
          legacyRead++;
          legacySum += h.amount;
          hTx++;
          canonicalTxList.add(FinancialTransaction.fromMajorUnits(
            id: FinancialTransaction.generateDeterministicId('household', h.id),
            userId: userId,
            type: TransactionType.expense,
            amountMajor: h.amount,
            categoryId: catId,
            sourceModule: 'household',
            sourceRecordId: h.id,
            description: '${h.category} - ${h.providerName}',
            transactionDate: h.dueDate,
            notes: h.period,
          ));
        } else {
          hOb++;
          canonicalObList.add(FinancialObligation.fromMajorUnits(
            id: FinancialObligation.generateDeterministicId('household', h.id),
            userId: userId,
            title: '${h.category} (${h.providerName})',
            categoryId: catId,
            sourceModule: 'household',
            sourceRecordId: h.id,
            expectedAmountMajor: h.amount,
            dueDate: h.dueDate,
            status: ObligationStatus.pending,
            notes: h.period,
          ));
        }
      }
      moduleCounts['household_tx'] = hTx;
      moduleCounts['household_ob'] = hOb;
      logs.add('Household module: $hTx paid transactions, $hOb unpaid obligations.');
    } catch (e) {
      logs.add('Household module error: $e');
    }

    // 3. Migrate School Fees (FeePayments -> Transactions, FeeInstallments -> Obligations)
    try {
      final paymentsSnap = await _firestore.collection('users').doc(userId).collection('feePayments').get();
      int feeTx = 0;
      for (final doc in paymentsSnap.docs) {
        final p = FeePayment.fromMap(doc.data(), doc.id);
        legacyRead++;
        legacySum += p.amountPaid;
        feeTx++;

        canonicalTxList.add(FinancialTransaction.fromMajorUnits(
          id: FinancialTransaction.generateDeterministicId('school_fees', p.id),
          userId: userId,
          type: TransactionType.expense,
          amountMajor: p.amountPaid,
          categoryId: 'education_school_fees',
          sourceModule: 'school_fees',
          sourceRecordId: p.id,
          description: 'School Fee Payment (Ref: ${p.transactionRef})',
          transactionDate: p.paymentDate,
          paymentMethod: p.paymentMethod,
          notes: p.notes,
        ));
      }
      moduleCounts['school_fees_tx'] = feeTx;

      final instSnap = await _firestore.collection('users').doc(userId).collection('feeInstallments').get();
      int feeOb = 0;
      for (final doc in instSnap.docs) {
        final inst = FeeInstallment.fromMap(doc.data(), doc.id);
        if (inst.status != 'paid') {
          feeOb++;
          canonicalObList.add(FinancialObligation.fromMajorUnits(
            id: FinancialObligation.generateDeterministicId('school_fees', inst.id),
            userId: userId,
            title: inst.title,
            categoryId: 'education_school_fees',
            sourceModule: 'school_fees',
            sourceRecordId: inst.id,
            expectedAmountMajor: inst.amount,
            paidAmountMajor: inst.paidAmount,
            dueDate: inst.dueDate,
            status: inst.paidAmount > 0 ? ObligationStatus.partiallyPaid : ObligationStatus.pending,
          ));
        }
      }
      moduleCounts['school_fees_ob'] = feeOb;
      logs.add('School fees: $feeTx payments migrated, $feeOb pending installments tracked.');
    } catch (e) {
      logs.add('School fees error: $e');
    }

    // 4. Migrate Vehicle Maintenance Service Records
    try {
      final servSnap = await _firestore.collection('users').doc(userId).collection('serviceRecords').get();
      int vTx = 0;
      for (final doc in servSnap.docs) {
        final s = ServiceRecord.fromJson(doc.data());
        legacyRead++;
        legacySum += s.totalCost;
        vTx++;

        final catId = CategoryRegistry.mapLegacyToCategoryId(s.serviceType, s.workPerformed);

        canonicalTxList.add(FinancialTransaction.fromMajorUnits(
          id: FinancialTransaction.generateDeterministicId('vehicle', s.id),
          userId: userId,
          type: TransactionType.expense,
          amountMajor: s.totalCost,
          categoryId: catId,
          sourceModule: 'vehicle',
          sourceRecordId: s.id,
          description: '${s.serviceType} (${s.serviceCenter})',
          transactionDate: s.serviceDate,
          merchantOrPayee: s.serviceCenter,
          notes: s.workPerformed,
        ));
      }
      moduleCounts['vehicle_tx'] = vTx;
      logs.add('Vehicle module: $vTx service transactions migrated.');
    } catch (e) {
      logs.add('Vehicle module error: $e');
    }

    // 5. Migrate Property Maintenances & Property Taxes
    try {
      final maintSnap = await _firestore.collection('users').doc(userId).collection('propertyMaintenances').get();
      int pTx = 0;
      for (final doc in maintSnap.docs) {
        final m = PropertyMaintenance.fromJson(doc.data());
        legacyRead++;
        legacySum += m.cost;
        pTx++;

        final catId = CategoryRegistry.mapLegacyToCategoryId(m.category, m.title);

        canonicalTxList.add(FinancialTransaction.fromMajorUnits(
          id: FinancialTransaction.generateDeterministicId('property', m.id),
          userId: userId,
          type: TransactionType.expense,
          amountMajor: m.cost,
          categoryId: catId,
          sourceModule: 'property',
          sourceRecordId: m.id,
          description: '${m.title} (${m.contractorName})',
          transactionDate: m.date,
          merchantOrPayee: m.contractorName,
        ));
      }
      moduleCounts['property_tx'] = pTx;

      final propSnap = await _firestore.collection('users').doc(userId).collection('properties').get();
      int pOb = 0;
      for (final doc in propSnap.docs) {
        final prop = Property.fromJson(doc.data());
        if (prop.propertyTaxAmount > 0) {
          pOb++;
          canonicalObList.add(FinancialObligation.fromMajorUnits(
            id: FinancialObligation.generateDeterministicId('property_tax', prop.id),
            userId: userId,
            title: 'Property Tax - ${prop.title}',
            categoryId: 'property_tax',
            sourceModule: 'property',
            sourceRecordId: prop.id,
            expectedAmountMajor: prop.propertyTaxAmount,
            dueDate: prop.taxDueDate,
            notes: 'Frequency: ${prop.propertyTaxFrequency}',
          ));
        }
      }
      moduleCounts['property_ob'] = pOb;
      logs.add('Property module: $pTx maintenance transactions, $pOb tax obligations.');
    } catch (e) {
      logs.add('Property module error: $e');
    }

    // 6. Migrate Bills Diary (BillPayments -> Transactions, Unpaid Bills -> Obligations)
    try {
      final billPaySnap = await _firestore.collection('users').doc(userId).collection('billPayments').get();
      int bTx = 0;
      for (final doc in billPaySnap.docs) {
        final bp = BillPayment.fromMap(doc.data(), doc.id);
        legacyRead++;
        legacySum += bp.amountPaid;
        bTx++;

        canonicalTxList.add(FinancialTransaction.fromMajorUnits(
          id: FinancialTransaction.generateDeterministicId('bills', bp.id),
          userId: userId,
          type: TransactionType.expense,
          amountMajor: bp.amountPaid,
          categoryId: 'household_other',
          sourceModule: 'bills',
          sourceRecordId: bp.id,
          description: 'Bill Payment (Ref: ${bp.transactionRef})',
          transactionDate: bp.paymentDate,
          paymentMethod: bp.paymentMethod,
          notes: bp.notes,
        ));
      }
      moduleCounts['bills_tx'] = bTx;

      final billSnap = await _firestore.collection('users').doc(userId).collection('bills').get();
      int bOb = 0;
      for (final doc in billSnap.docs) {
        final bill = Bill.fromMap(doc.data(), doc.id);
        if (bill.status != 'paid') {
          bOb++;
          canonicalObList.add(FinancialObligation.fromMajorUnits(
            id: FinancialObligation.generateDeterministicId('bills', bill.id),
            userId: userId,
            title: 'Bill ${bill.billPeriod}',
            categoryId: 'household_other',
            sourceModule: 'bills',
            sourceRecordId: bill.id,
            expectedAmountMajor: bill.amount,
            dueDate: bill.dueDate,
            notes: bill.notes,
          ));
        }
      }
      moduleCounts['bills_ob'] = bOb;
      logs.add('Bills module: $bTx payments migrated, $bOb unpaid bills tracked.');
    } catch (e) {
      logs.add('Bills module error: $e');
    }

    // 7. Write in Idempotent Batches
    await _txRepo.batchUpsert(userId, canonicalTxList);
    await _obRepo.batchUpsert(userId, canonicalObList);

    // 8. Reconcile Totals
    double canonIncome = 0.0;
    double canonExpense = 0.0;
    for (final tx in canonicalTxList) {
      if (tx.type == TransactionType.income) {
        canonIncome += tx.amount;
      } else if (tx.type == TransactionType.expense) {
        canonExpense += tx.amount;
      }
    }

    double canonObDue = 0.0;
    for (final ob in canonicalObList) {
      canonObDue += ob.remainingAmount;
    }

    logs.add('Migration completed. Total canonical transactions: ${canonicalTxList.length}, obligations: ${canonicalObList.length}');

    return MigrationReconciliationReport(
      userId: userId,
      executedAt: DateTime.now(),
      legacyTransactionsRead: legacyRead,
      canonicalTransactionsWritten: canonicalTxList.length,
      canonicalObligationsWritten: canonicalObList.length,
      legacySumAmount: legacySum,
      canonicalIncomeSum: canonIncome,
      canonicalExpenseSum: canonExpense,
      canonicalObligationDueSum: canonObDue,
      moduleBreakdown: moduleCounts,
      auditLogs: logs,
    );
  }
}
