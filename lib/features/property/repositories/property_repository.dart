import 'package:cloud_firestore/cloud_firestore.dart';
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
  }

  Future<void> addMaintenance(String userId, PropertyMaintenance maintenance) async {
    if (userId.isEmpty) return;
    await firestore
        .collection('users')
        .doc(userId)
        .collection('propertyMaintenances')
        .doc(maintenance.id)
        .set(maintenance.toJson());
  }

  Future<void> deleteProperty(String userId, String propertyId) async {
    if (userId.isEmpty || propertyId.isEmpty) return;
    await firestore
        .collection('users')
        .doc(userId)
        .collection('properties')
        .doc(propertyId)
        .delete();
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
