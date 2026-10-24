import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/financial/models/financial_category.dart';
import '../../../core/financial/models/financial_transaction.dart';
import '../../../core/financial/repositories/financial_transaction_repository.dart';
import '../models/property_models.dart';

class PropertyRepository {
  final FirebaseFirestore? _firestore;
  PropertyRepository({FirebaseFirestore? firestore}) : _firestore = firestore;

  FirebaseFirestore get firestore => _firestore ?? FirebaseFirestore.instance;

  Future<List<Property>> getProperties(String userId) async {
    if (userId.isEmpty) return const [];
    try {
      final snapshot = await firestore
          .collection('users')
          .doc(userId)
          .collection('properties')
          .get();
      return snapshot.docs.map((doc) => Property.fromJson(doc.data())).toList();
    } catch (e) {
      return const [];
    }
  }

  Future<List<PropertyMaintenance>> getMaintenances(String userId) async {
    if (userId.isEmpty) return const [];
    try {
      final snapshot = await firestore
          .collection('users')
          .doc(userId)
          .collection('propertyMaintenances')
          .get();
      final list = snapshot.docs.map((doc) => PropertyMaintenance.fromJson(doc.data())).toList();
      list.sort((a, b) => b.date.compareTo(a.date));
      return list;
    } catch (e) {
      return const [];
    }
  }

  Future<void> addProperty(String userId, Property property) async {
    if (userId.isEmpty) return;
    await firestore
        .collection('users')
        .doc(userId)
        .collection('properties')
        .doc(property.id)
        .set(property.toJson());

    // Sync property tax reminder
    try {
      final remRef = firestore.collection('users').doc(userId).collection('reminders').doc('reminder_prop_${property.id}_tax');
      await remRef.set({
        'id': 'reminder_prop_${property.id}_tax',
        'userId': userId,
        'title': 'Property Tax: ${property.title}',
        'description': '${property.propertyTaxFrequency} property tax of ₹${property.propertyTaxAmount.toStringAsFixed(0)} for ${property.address}.',
        'module': 'Property',
        'status': 'pending',
        'dueDate': Timestamp.fromDate(property.taxDueDate),
        'relatedId': property.id,
        'amount': property.propertyTaxAmount,
        'actionRoute': '/property',
        'createdAt': Timestamp.fromDate(DateTime.now()),
      }, SetOptions(merge: true));
    } catch (_) {}
  }

  Future<void> addMaintenance(String userId, PropertyMaintenance maintenance) async {
    if (userId.isEmpty) return;
    await firestore
        .collection('users')
        .doc(userId)
        .collection('propertyMaintenances')
        .doc(maintenance.id)
        .set(maintenance.toJson());

    // Record canonical financial transaction idempotently
    try {
      final txRepo = FinancialTransactionRepository(firestore: firestore);
      await txRepo.recordTransaction(
        userId,
        FinancialTransaction.fromMajorUnits(
          id: FinancialTransaction.generateDeterministicId('property', maintenance.id),
          userId: userId,
          type: TransactionType.expense,
          amountMajor: maintenance.cost,
          categoryId: CategoryRegistry.mapLegacyToCategoryId(maintenance.category, maintenance.title),
          sourceModule: 'property',
          sourceRecordId: maintenance.id,
          description: '${maintenance.title} (${maintenance.contractorName})',
          transactionDate: maintenance.date,
          merchantOrPayee: maintenance.contractorName,
        ),
      );
    } catch (_) {}
  }

  Future<void> deleteProperty(String userId, String propertyId) async {
    if (userId.isEmpty || propertyId.isEmpty) return;
    await firestore
        .collection('users')
        .doc(userId)
        .collection('properties')
        .doc(propertyId)
        .delete();

    try {
      final remRef = firestore.collection('users').doc(userId).collection('reminders').doc('reminder_prop_${propertyId}_tax');
      await remRef.delete();
    } catch (_) {}
  }

  Future<void> deleteMaintenance(String userId, String maintenanceId) async {
    if (userId.isEmpty || maintenanceId.isEmpty) return;
    await firestore
        .collection('users')
        .doc(userId)
        .collection('propertyMaintenances')
        .doc(maintenanceId)
        .delete();
  }
}
