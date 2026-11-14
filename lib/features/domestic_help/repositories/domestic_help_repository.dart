import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/financial/models/financial_transaction.dart';
import '../../../core/financial/repositories/financial_transaction_repository.dart';
import '../models/domestic_help_models.dart';

class DomesticHelpRepository {
  final FirebaseFirestore _firestore;

  DomesticHelpRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  // --- Domestic Workers ---
  Future<List<DomesticWorker>> getWorkers(String userId, {String? householdId}) async {
    if (userId.isEmpty) return const [];
    try {
      final snap = await _firestore
          .collection('users')
          .doc(userId)
          .collection('domesticWorkers')
          .get();
      var list = snap.docs.map((d) => DomesticWorker.fromJson(d.data())).toList();
      if (householdId != null && householdId.isNotEmpty) {
        list = list.where((w) => w.householdId == householdId).toList();
      }
      return list;
    } catch (_) {
      return const [];
    }
  }

  Future<void> addWorker(String userId, DomesticWorker worker) async {
    if (userId.isEmpty) return;
    await _firestore
        .collection('users')
        .doc(userId)
        .collection('domesticWorkers')
        .doc(worker.id)
        .set(worker.toJson());
  }

  Future<void> updateWorker(String userId, DomesticWorker worker) async {
    if (userId.isEmpty) return;
    await _firestore
        .collection('users')
        .doc(userId)
        .collection('domesticWorkers')
        .doc(worker.id)
        .update(worker.toJson());
  }

  Future<void> deleteWorker(String userId, String workerId) async {
    if (userId.isEmpty || workerId.isEmpty) return;
    await _firestore
        .collection('users')
        .doc(userId)
        .collection('domesticWorkers')
        .doc(workerId)
        .delete();
  }

  // --- Attendance ---
  Future<List<WorkerAttendance>> getAttendanceForDate(String userId, DateTime date) async {
    if (userId.isEmpty) return const [];
    final dateStr = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    try {
      final snap = await _firestore
          .collection('users')
          .doc(userId)
          .collection('workerAttendance')
          .where('date', isEqualTo: dateStr)
          .get();
      return snap.docs.map((d) => WorkerAttendance.fromJson(d.data())).toList();
    } catch (_) {
      return const [];
    }
  }

  /// Records attendance uniquely per worker per day to prevent duplicate entries
  Future<void> recordAttendance(String userId, WorkerAttendance attendance) async {
    if (userId.isEmpty) return;
    final docId = 'att_${attendance.workerId}_${attendance.date}';
    final data = attendance.toJson()..['id'] = docId;

    await _firestore
        .collection('users')
        .doc(userId)
        .collection('workerAttendance')
        .doc(docId)
        .set(data, SetOptions(merge: true));
  }

  Future<List<WorkerAttendance>> getMonthlyAttendance(
    String userId,
    String workerId,
    int month,
    int year,
  ) async {
    if (userId.isEmpty) return const [];
    final prefix = '$year-${month.toString().padLeft(2, '0')}';
    try {
      final snap = await _firestore
          .collection('users')
          .doc(userId)
          .collection('workerAttendance')
          .where('workerId', isEqualTo: workerId)
          .get();
      return snap.docs
          .map((d) => WorkerAttendance.fromJson(d.data()))
          .where((a) => a.date.startsWith(prefix))
          .toList();
    } catch (_) {
      return const [];
    }
  }

  // --- Advances & Adjustments ---
  Future<void> addAdvance(String userId, SalaryAdvance advance) async {
    if (userId.isEmpty) return;
    await _firestore
        .collection('users')
        .doc(userId)
        .collection('salaryAdvances')
        .doc(advance.id)
        .set(advance.toJson());

    // Update worker's advance balance
    final workerRef = _firestore
        .collection('users')
        .doc(userId)
        .collection('domesticWorkers')
        .doc(advance.workerId);
    final doc = await workerRef.get();
    if (doc.exists && doc.data() != null) {
      final currentBal = (doc.data()!['advanceBalance'] as num?)?.toDouble() ?? 0.0;
      await workerRef.update({'advanceBalance': currentBal + advance.amount});
    }
  }

  Future<List<SalaryAdvance>> getAdvances(String userId, String workerId) async {
    if (userId.isEmpty) return const [];
    try {
      final snap = await _firestore
          .collection('users')
          .doc(userId)
          .collection('salaryAdvances')
          .where('workerId', isEqualTo: workerId)
          .get();
      return snap.docs.map((d) => SalaryAdvance.fromJson(d.data())).toList();
    } catch (_) {
      return const [];
    }
  }

  Future<void> addAdjustment(String userId, SalaryAdjustment adjustment) async {
    if (userId.isEmpty) return;
    await _firestore
        .collection('users')
        .doc(userId)
        .collection('salaryAdjustments')
        .doc(adjustment.id)
        .set(adjustment.toJson());
  }

  // --- Salary Statement Calculations & Settlement ---
  Future<SalaryStatement> calculateSalaryStatement(
    String userId,
    DomesticWorker worker,
    int month,
    int year,
  ) async {
    final daysInMonth = DateTime(year, month + 1, 0).day;
    final baseSalary = worker.baseSalary;

    // 1. Fetch monthly attendance
    final attendanceList = await getMonthlyAttendance(userId, worker.id, month, year);
    double deductions = 0.0;
    if (worker.attendancePolicy == AttendancePolicy.deductUnpaidAbsence) {
      final unexcusedAbsences = attendanceList.where((a) => a.status == AttendanceStatus.absent || a.status == AttendanceStatus.unpaidLeave).length;
      final halfDays = attendanceList.where((a) => a.status == AttendanceStatus.halfDay).length;
      final deductionDays = unexcusedAbsences + (halfDays * 0.5);
      final dailyRate = baseSalary / daysInMonth;
      deductions = deductionDays * dailyRate;
    }

    // 2. Fetch adjustments
    double bonuses = 0.0;
    double extraWorkPay = 0.0;
    try {
      final snap = await _firestore
          .collection('users')
          .doc(userId)
          .collection('salaryAdjustments')
          .where('workerId', isEqualTo: worker.id)
          .get();
      for (final doc in snap.docs) {
        final adj = SalaryAdjustment.fromJson(doc.data());
        if (adj.date.month == month && adj.date.year == year) {
          if (adj.type == 'bonus') bonuses += adj.amount;
          if (adj.type == 'extra_work') extraWorkPay += adj.amount;
          if (adj.type == 'deduction') deductions += adj.amount;
        }
      }
    } catch (_) {}

    // 3. Check active advances for monthly recovery
    double advanceRecovery = 0.0;
    final advances = await getAdvances(userId, worker.id);
    for (final adv in advances) {
      if (!adv.isFullyRecovered && adv.remainingBalance > 0) {
        final recovery = adv.monthlyRecoveryAmount > 0
            ? (adv.monthlyRecoveryAmount < adv.remainingBalance ? adv.monthlyRecoveryAmount : adv.remainingBalance)
            : 0.0;
        advanceRecovery += recovery;
      }
    }

    // Formula: Base Salary + Bonuses + Extra Work - Deductions - Advance Recovery
    final netPayable = (baseSalary + bonuses + extraWorkPay - deductions - advanceRecovery).clamp(0.0, double.infinity);
    final statementId = 'stmt_${worker.id}_${year}_$month';

    return SalaryStatement(
      id: statementId,
      workerId: worker.id,
      workerName: worker.name,
      householdId: worker.householdId,
      month: month,
      year: year,
      baseSalary: baseSalary,
      bonuses: bonuses,
      extraWorkPay: extraWorkPay,
      deductions: deductions,
      advanceRecovery: advanceRecovery,
      netPayable: netPayable,
      status: 'draft',
    );
  }

  Future<void> saveSalaryStatement(String userId, SalaryStatement statement) async {
    if (userId.isEmpty) return;
    await _firestore
        .collection('users')
        .doc(userId)
        .collection('salaryStatements')
        .doc(statement.id)
        .set(statement.toJson(), SetOptions(merge: true));
  }

  Future<List<SalaryStatement>> getSalaryStatements(String userId, {int? month, int? year}) async {
    if (userId.isEmpty) return const [];
    try {
      final snap = await _firestore
          .collection('users')
          .doc(userId)
          .collection('salaryStatements')
          .get();
      var list = snap.docs.map((d) => SalaryStatement.fromJson(d.data())).toList();
      if (month != null) list = list.where((s) => s.month == month).toList();
      if (year != null) list = list.where((s) => s.year == year).toList();
      return list;
    } catch (_) {
      return const [];
    }
  }

  /// Settles a full or partial salary payment and updates canonical financial ledger idempotently
  Future<SalaryStatement> settleSalaryPayment(
    String userId,
    String statementId,
    double paymentAmount, {
    String paymentMethod = 'UPI / Cash',
    String? paymentReference,
  }) async {
    if (userId.isEmpty || statementId.isEmpty || paymentAmount <= 0) {
      throw ArgumentError('Invalid payment arguments');
    }

    final docRef = _firestore
        .collection('users')
        .doc(userId)
        .collection('salaryStatements')
        .doc(statementId);
    final doc = await docRef.get();
    if (!doc.exists || doc.data() == null) {
      throw StateError('Salary statement not found');
    }

    final existing = SalaryStatement.fromJson(doc.data()!);
    final newPaid = existing.paidAmount + paymentAmount;
    final isFullySettled = newPaid >= existing.netPayable;
    final newStatus = isFullySettled ? 'paid' : 'partially_paid';

    // 1. Write single canonical transaction to financial ledger
    final txRepo = FinancialTransactionRepository(firestore: _firestore);
    final detTxId = FinancialTransaction.generateDeterministicId('domestic_salary', statementId);

    try {
      await txRepo.recordTransaction(
        userId,
        FinancialTransaction.fromMajorUnits(
          id: detTxId,
          userId: userId,
          type: TransactionType.expense,
          amountMajor: paymentAmount,
          categoryId: 'household_domestic_help',
          sourceModule: 'domestic_help',
          sourceRecordId: statementId,
          description: 'Domestic Staff Salary: ${existing.workerName} (${existing.month}/${existing.year})',
          transactionDate: DateTime.now(),
          notes: 'Method: $paymentMethod. Ref: ${paymentReference ?? "N/A"}',
        ),
      );
    } catch (_) {}

    // 2. If advance recovery was planned, reduce worker's advance balance
    if (existing.advanceRecovery > 0) {
      final workerRef = _firestore
          .collection('users')
          .doc(userId)
          .collection('domesticWorkers')
          .doc(existing.workerId);
      final workerDoc = await workerRef.get();
      if (workerDoc.exists && workerDoc.data() != null) {
        final currentBal = (workerDoc.data()!['advanceBalance'] as num?)?.toDouble() ?? 0.0;
        final updatedBal = (currentBal - existing.advanceRecovery).clamp(0.0, double.infinity);
        await workerRef.update({'advanceBalance': updatedBal});
      }
    }

    final updated = existing.copyWith(
      paidAmount: newPaid,
      status: newStatus,
      paymentDate: DateTime.now(),
      paymentMethod: paymentMethod,
      paymentReference: paymentReference,
      financialTransactionId: detTxId,
    );

    await docRef.set(updated.toJson(), SetOptions(merge: true));
    return updated;
  }

  // --- Recurring Household Services ---
  Future<List<RecurringService>> getRecurringServices(String userId, {String? householdId}) async {
    if (userId.isEmpty) return const [];
    try {
      final snap = await _firestore
          .collection('users')
          .doc(userId)
          .collection('recurringServices')
          .get();
      var list = snap.docs.map((d) => RecurringService.fromJson(d.data())).toList();
      if (householdId != null && householdId.isNotEmpty) {
        list = list.where((s) => s.householdId == householdId).toList();
      }
      return list;
    } catch (_) {
      return const [];
    }
  }

  Future<void> addRecurringService(String userId, RecurringService service) async {
    if (userId.isEmpty) return;
    await _firestore
        .collection('users')
        .doc(userId)
        .collection('recurringServices')
        .doc(service.id)
        .set(service.toJson());
  }

  Future<void> updateRecurringService(String userId, RecurringService service) async {
    if (userId.isEmpty) return;
    await _firestore
        .collection('users')
        .doc(userId)
        .collection('recurringServices')
        .doc(service.id)
        .update(service.toJson());
  }

  Future<void> deleteRecurringService(String userId, String serviceId) async {
    if (userId.isEmpty || serviceId.isEmpty) return;
    await _firestore
        .collection('users')
        .doc(userId)
        .collection('recurringServices')
        .doc(serviceId)
        .delete();
  }

  Future<List<ServiceEntry>> getDailyServiceEntries(String userId, DateTime date) async {
    if (userId.isEmpty) return const [];
    final dateStr = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    try {
      final snap = await _firestore
          .collection('users')
          .doc(userId)
          .collection('serviceEntries')
          .where('date', isEqualTo: dateStr)
          .get();
      return snap.docs.map((d) => ServiceEntry.fromJson(d.data())).toList();
    } catch (_) {
      return const [];
    }
  }

  /// Records actual daily service consumption (e.g. 2 Litres of milk)
  Future<void> recordServiceEntry(String userId, ServiceEntry entry) async {
    if (userId.isEmpty) return;
    final docId = 'entry_${entry.serviceId}_${entry.date}';
    final data = entry.toJson()..['id'] = docId;

    await _firestore
        .collection('users')
        .doc(userId)
        .collection('serviceEntries')
        .doc(docId)
        .set(data, SetOptions(merge: true));
  }

  /// Settles a recurring service bill and records canonical transaction
  Future<void> settleServiceBill(
    String userId,
    String serviceId,
    String serviceName,
    int month,
    int year,
    double amount, {
    String paymentMethod = 'UPI',
  }) async {
    if (userId.isEmpty || amount <= 0) return;

    final billId = 'serv_bill_${serviceId}_${year}_$month';
    final txRepo = FinancialTransactionRepository(firestore: _firestore);
    final detTxId = FinancialTransaction.generateDeterministicId('recurring_service', billId);

    // 1. Record single financial transaction
    try {
      await txRepo.recordTransaction(
        userId,
        FinancialTransaction.fromMajorUnits(
          id: detTxId,
          userId: userId,
          type: TransactionType.expense,
          amountMajor: amount,
          categoryId: 'household_groceries',
          sourceModule: 'household',
          sourceRecordId: billId,
          description: '$serviceName Delivery Bill ($month/$year)',
          transactionDate: DateTime.now(),
          notes: 'Method: $paymentMethod',
        ),
      );
    } catch (_) {}

    // 2. Save bill record
    final bill = ServiceBill(
      id: billId,
      serviceId: serviceId,
      serviceName: serviceName,
      householdId: '',
      month: month,
      year: year,
      totalQuantity: 0.0,
      totalAmount: amount,
      paidAmount: amount,
      status: 'paid',
      paidDate: DateTime.now(),
      financialTransactionId: detTxId,
    );

    await _firestore
        .collection('users')
        .doc(userId)
        .collection('serviceBills')
        .doc(billId)
        .set(bill.toJson(), SetOptions(merge: true));
  }
}
