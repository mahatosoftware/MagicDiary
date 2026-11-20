import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../../../core/financial/models/financial_category.dart';
import '../../../core/financial/models/financial_transaction.dart';
import '../../../core/financial/repositories/financial_transaction_repository.dart';
import '../../reminders/models/reminder.dart';
import '../../reminders/repositories/reminder_repository.dart';
import '../models/vehicle_models.dart';

class VehicleRepository {
  final FirebaseFirestore? _firestore;
  VehicleRepository({FirebaseFirestore? firestore}) : _firestore = firestore;

  FirebaseFirestore get firestore => _firestore ?? FirebaseFirestore.instance;

  Future<List<Vehicle>> getVehicles(String userId) async {
    if (userId.isEmpty) return const [];
    try {
      final snapshot = await firestore
          .collection('users')
          .doc(userId)
          .collection('vehicles')
          .get();
      return snapshot.docs.map((doc) => Vehicle.fromJson(doc.data())).toList();
    } catch (e) {
      return const [];
    }
  }

  Future<List<ServiceRecord>> getServices(String userId) async {
    if (userId.isEmpty) return const [];
    try {
      final snapshot = await firestore
          .collection('users')
          .doc(userId)
          .collection('serviceRecords')
          .get();
      return snapshot.docs.map((doc) => ServiceRecord.fromJson(doc.data())).toList();
    } catch (e) {
      return const [];
    }
  }

  Future<void> addVehicle(String userId, Vehicle vehicle) async {
    if (userId.isEmpty) return;
    await firestore
        .collection('users')
        .doc(userId)
        .collection('vehicles')
        .doc(vehicle.id)
        .set(vehicle.toJson());

    // Synchronize deterministic insurance and PUCC reminders
    await _syncVehicleReminders(userId, vehicle);
  }

  Future<void> updateVehicle(String userId, Vehicle vehicle) async {
    await addVehicle(userId, vehicle);
  }

  /// Removes a vehicle and all its associated records (service records, reminders, and obligations).
  Future<void> deleteVehicle(
    String userId,
    String vehicleId, {
    bool deleteServiceRecords = true,
    bool deleteReminders = true,
  }) async {
    if (userId.isEmpty || vehicleId.isEmpty) return;

    final batch = firestore.batch();

    // 1. Delete vehicle doc
    final vehicleDoc = firestore
        .collection('users')
        .doc(userId)
        .collection('vehicles')
        .doc(vehicleId);
    batch.delete(vehicleDoc);

    // 2. Delete associated service records if requested
    if (deleteServiceRecords) {
      try {
        final serviceSnap = await firestore
            .collection('users')
            .doc(userId)
            .collection('serviceRecords')
            .where('vehicleId', isEqualTo: vehicleId)
            .get();
        for (final doc in serviceSnap.docs) {
          batch.delete(doc.reference);
        }
      } catch (_) {}
    }

    // 3. Clean up associated reminders
    if (deleteReminders) {
      final reminderCol = firestore.collection('users').doc(userId).collection('reminders');
      // Deterministic reminders
      batch.delete(reminderCol.doc('reminder_veh_${vehicleId}_insurance'));
      batch.delete(reminderCol.doc('reminder_veh_${vehicleId}_pucc'));
      batch.delete(reminderCol.doc('reminder_veh_${vehicleId}_service'));

      // Any other reminder linked by relatedId
      try {
        final relatedReminders = await reminderCol
            .where('relatedId', isEqualTo: vehicleId)
            .get();
        for (final doc in relatedReminders.docs) {
          batch.delete(doc.reference);
        }
      } catch (_) {}
    }

    // 4. Clean up any linked obligations
    try {
      final obligations = await firestore
          .collection('users')
          .doc(userId)
          .collection('financialObligations')
          .where('sourceRecordId', isEqualTo: vehicleId)
          .get();
      for (final doc in obligations.docs) {
        batch.delete(doc.reference);
      }
    } catch (_) {}

    await batch.commit();
  }

  /// Sell Vehicle: Records the sale proceeds as Income in the canonical Financial Reports,
  /// and removes the vehicle and its associated records from the user's garage.
  Future<void> sellVehicle(
    String userId,
    Vehicle vehicle, {
    required double salePrice,
    required DateTime saleDate,
    String? buyerName,
    String? notes,
    bool deleteServiceRecords = true,
  }) async {
    if (userId.isEmpty) return;

    // 1. Record sale proceeds if > 0
    if (salePrice > 0) {
      try {
        final txRepo = FinancialTransactionRepository(firestore: firestore);
        const uuid = Uuid();
        await txRepo.recordTransaction(
          userId,
          FinancialTransaction.fromMajorUnits(
            id: uuid.v4(),
            userId: userId,
            type: TransactionType.income,
            amountMajor: salePrice,
            categoryId: 'other_income',
            sourceModule: 'vehicle',
            sourceRecordId: vehicle.id,
            description: 'Sale Proceeds: ${vehicle.name} (${vehicle.registrationNumber})',
            transactionDate: saleDate,
            merchantOrPayee: buyerName?.trim().isNotEmpty == true ? buyerName!.trim() : 'Vehicle Buyer',
            notes: notes?.trim().isNotEmpty == true ? notes!.trim() : 'Vehicle sold from garage',
          ),
        );
      } catch (_) {}
    }

    // 2. Remove the vehicle and its associated records
    await deleteVehicle(
      userId,
      vehicle.id,
      deleteServiceRecords: deleteServiceRecords,
      deleteReminders: true,
    );
  }

  /// Delete an individual service record and its corresponding transaction
  Future<void> deleteServiceRecord(String userId, String serviceId) async {
    if (userId.isEmpty || serviceId.isEmpty) return;
    await firestore
        .collection('users')
        .doc(userId)
        .collection('serviceRecords')
        .doc(serviceId)
        .delete();

    try {
      final txRepo = FinancialTransactionRepository(firestore: firestore);
      final detTxId = FinancialTransaction.generateDeterministicId('vehicle', serviceId);
      await txRepo.deleteTransaction(userId, detTxId);
    } catch (_) {}
  }

  /// Renew Vehicle Insurance: Updates vehicle insurance expiry, records optional expense,
  /// and updates the notification reminder.
  Future<void> renewInsurance(
    String userId,
    Vehicle vehicle, {
    required DateTime newExpiryDate,
    double? premiumAmount,
    String? insurer,
    String? policyNumber,
    int? newTenureMonths,
    DateTime? newStartDate,
  }) async {
    if (userId.isEmpty) return;

    final updatedVehicle = vehicle.copyWith(
      insuranceExpiry: newExpiryDate,
      insuranceTenureMonths: newTenureMonths ?? vehicle.insuranceTenureMonths,
      insuranceStartDate: newStartDate ?? vehicle.insuranceStartDate,
    );
    await updateVehicle(userId, updatedVehicle);

    // If an insurance premium was paid, record a canonical financial transaction
    if (premiumAmount != null && premiumAmount > 0) {
      try {
        final txRepo = FinancialTransactionRepository(firestore: firestore);
        const uuid = Uuid();
        final txId = uuid.v4();
        await txRepo.recordTransaction(
          userId,
          FinancialTransaction.fromMajorUnits(
            id: txId,
            userId: userId,
            type: TransactionType.expense,
            amountMajor: premiumAmount,
            categoryId: 'vehicle_insurance',
            sourceModule: 'vehicle',
            sourceRecordId: vehicle.id,
            description: 'Insurance Renewal: ${vehicle.name}',
            transactionDate: DateTime.now(),
            merchantOrPayee: insurer?.trim().isNotEmpty == true ? insurer!.trim() : 'Insurance Provider',
            notes: policyNumber?.trim().isNotEmpty == true ? 'Policy No: ${policyNumber!.trim()}' : null,
          ),
        );
      } catch (_) {}
    }
  }

  /// Update / Renew PUC Certificate: Updates vehicle PUC expiry, records optional testing fee,
  /// and updates the notification reminder.
  Future<void> renewPucc(
    String userId,
    Vehicle vehicle, {
    required DateTime newExpiryDate,
    double? testFee,
    String? testCenter,
    String? certificateNumber,
    int? newTenureMonths,
    DateTime? newStartDate,
  }) async {
    if (userId.isEmpty) return;

    final updatedVehicle = vehicle.copyWith(
      pucExpiry: newExpiryDate,
      pucTenureMonths: newTenureMonths ?? vehicle.pucTenureMonths,
      pucStartDate: newStartDate ?? vehicle.pucStartDate,
    );
    await updateVehicle(userId, updatedVehicle);

    // If test fee was paid, record canonical financial transaction
    if (testFee != null && testFee > 0) {
      try {
        final txRepo = FinancialTransactionRepository(firestore: firestore);
        const uuid = Uuid();
        final txId = uuid.v4();
        await txRepo.recordTransaction(
          userId,
          FinancialTransaction.fromMajorUnits(
            id: txId,
            userId: userId,
            type: TransactionType.expense,
            amountMajor: testFee,
            categoryId: 'vehicle_puc_statutory',
            sourceModule: 'vehicle',
            sourceRecordId: vehicle.id,
            description: 'PUC Renewal: ${vehicle.name}',
            transactionDate: DateTime.now(),
            merchantOrPayee: testCenter?.trim().isNotEmpty == true ? testCenter!.trim() : 'Pollution Testing Center',
            notes: certificateNumber?.trim().isNotEmpty == true ? 'Cert No: ${certificateNumber!.trim()}' : null,
          ),
        );
      } catch (_) {}
    }
  }

  Future<void> _syncVehicleReminders(String userId, Vehicle vehicle) async {
    if (userId.isEmpty) return;
    try {
      final remRepo = ReminderRepository(firestore: firestore);
      final dateFormat = DateFormat('dd MMM yyyy');

      // 1. Insurance Renewal Reminder
      await remRepo.syncReminder(
        userId,
        Reminder(
          id: 'reminder_veh_${vehicle.id}_insurance',
          userId: userId,
          title: 'Vehicle Insurance (${vehicle.insuranceTenureLabel}): ${vehicle.name}',
          description:
              'Insurance policy (${vehicle.insuranceTenureLabel}) for ${vehicle.name} (${vehicle.registrationNumber}) expires on ${dateFormat.format(vehicle.insuranceExpiry)}. Renew to avoid penalty or loss of cover.',
          module: 'Vehicle',
          status: 'pending',
          dueDate: vehicle.insuranceExpiry,
          relatedId: vehicle.id,
          actionRoute: '/vehicle',
          actionType: 'Renew',
          priority: 'high',
          repeatSchedule: vehicle.insuranceRepeatSchedule,
          createdAt: DateTime.now(),
        ),
      );

      // 2. PUCC Expiry Reminder
      await remRepo.syncReminder(
        userId,
        Reminder(
          id: 'reminder_veh_${vehicle.id}_pucc',
          userId: userId,
          title: 'PUC Certificate (${vehicle.pucTenureLabel}): ${vehicle.name}',
          description:
              'Pollution Under Control (PUC) certificate (${vehicle.pucTenureLabel}) for ${vehicle.name} (${vehicle.registrationNumber}) expires on ${dateFormat.format(vehicle.pucExpiry)}. Configured for ${vehicle.pucTenureLabel} renewals.',
          module: 'Vehicle',
          status: 'pending',
          dueDate: vehicle.pucExpiry,
          relatedId: vehicle.id,
          actionRoute: '/vehicle',
          actionType: 'Renew',
          priority: 'medium',
          repeatSchedule: vehicle.pucRepeatSchedule,
          createdAt: DateTime.now(),
        ),
      );

      // 3. Optional Routine Service Reminder
      final svcDocId = 'reminder_veh_${vehicle.id}_service';
      if (vehicle.nextServiceDate != null) {
        await remRepo.syncReminder(
          userId,
          Reminder(
            id: svcDocId,
            userId: userId,
            title: 'Routine Service (${vehicle.serviceIntervalLabel}): ${vehicle.name}',
            description:
                'Scheduled periodic maintenance (${vehicle.serviceIntervalLabel} / ${vehicle.serviceIntervalKm} km) for ${vehicle.name} (${vehicle.registrationNumber}) on ${dateFormat.format(vehicle.nextServiceDate!)}. Configured interval: every ${vehicle.serviceIntervalLabel}.',
            module: 'Vehicle',
            status: 'pending',
            dueDate: vehicle.nextServiceDate!,
            relatedId: vehicle.id,
            actionRoute: '/vehicle',
            actionType: 'Schedule Service',
            priority: 'medium',
            repeatSchedule: vehicle.serviceRepeatSchedule,
            createdAt: DateTime.now(),
          ),
        );
      } else {
        await remRepo.deleteReminder(userId, svcDocId);
      }
    } catch (_) {}
  }

  Future<void> updateServiceRecord(String userId, ServiceRecord service, {DateTime? nextServiceDate}) async {
    await addServiceRecord(userId, service, nextServiceDate: nextServiceDate);
  }

  Future<void> addServiceRecord(
    String userId,
    ServiceRecord service, {
    DateTime? nextServiceDate,
  }) async {
    if (userId.isEmpty) return;
    await firestore
        .collection('users')
        .doc(userId)
        .collection('serviceRecords')
        .doc(service.id)
        .set(service.toJson());

    // Record canonical financial transaction idempotently
    try {
      final txRepo = FinancialTransactionRepository(firestore: firestore);
      await txRepo.recordTransaction(
        userId,
        FinancialTransaction.fromMajorUnits(
          id: FinancialTransaction.generateDeterministicId('vehicle', service.id),
          userId: userId,
          type: TransactionType.expense,
          amountMajor: service.totalCost,
          categoryId: CategoryRegistry.mapLegacyToCategoryId(service.serviceType, service.workPerformed),
          sourceModule: 'vehicle',
          sourceRecordId: service.id,
          description: '${service.serviceType} (${service.serviceCenter})',
          transactionDate: service.serviceDate,
          merchantOrPayee: service.serviceCenter,
          notes: service.workPerformed,
        ),
      );
    } catch (_) {}

    // Synchronize vehicle's lastServiceOdometer, currentOdometer, and nextServiceDate
    try {
      final vehicleDoc = await firestore
          .collection('users')
          .doc(userId)
          .collection('vehicles')
          .doc(service.vehicleId)
          .get();

      if (vehicleDoc.exists && vehicleDoc.data() != null) {
        final vehicle = Vehicle.fromJson(vehicleDoc.data()!);
        final newLastServiceOdo = service.odometerReading > 0
            ? service.odometerReading
            : vehicle.lastServiceOdometer;
        final newCurrentOdo = service.odometerReading > vehicle.currentOdometer
            ? service.odometerReading
            : vehicle.currentOdometer;
        final calculatedNextDate = nextServiceDate ??
            Vehicle.calculateExpiryDate(service.serviceDate, vehicle.serviceIntervalMonths);

        final updatedVehicle = vehicle.copyWith(
          lastServiceOdometer: newLastServiceOdo,
          currentOdometer: newCurrentOdo,
          nextServiceDate: calculatedNextDate,
        );

        await updateVehicle(userId, updatedVehicle);
      }
    } catch (_) {}
  }
}
