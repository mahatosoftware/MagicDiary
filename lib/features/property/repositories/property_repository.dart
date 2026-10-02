import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/property_models.dart';

class PropertyRepository {
  final FirebaseFirestore? _firestore;
  PropertyRepository({FirebaseFirestore? firestore}) : _firestore = firestore;

  FirebaseFirestore get firestore => _firestore ?? FirebaseFirestore.instance;

  final List<Property> _mockProperties = [
    Property(
      id: 'prop_1',
      title: 'Green Glen Apartment #302',
      propertyType: 'Apartment',
      address: 'Outer Ring Road, Bellandur, Bangalore',
      purchasePrice: 8500000.0,
      purchaseDate: DateTime(2021, 3, 15),
      propertyTaxAmount: 14200.0,
      taxDueDate: DateTime.now().add(const Duration(days: 60)),
      monthlyRentIncome: 35000.0,
    ),
  ];

  final List<PropertyMaintenance> _mockMaintenances = [
    PropertyMaintenance(
      id: 'maint_1',
      propertyId: 'prop_1',
      title: 'Waterproofing & Balcony Repair',
      category: 'Renovation',
      cost: 42000.0,
      date: DateTime(2024, 2, 10),
      contractorName: 'BuildCare Solutions',
    ),
    PropertyMaintenance(
      id: 'maint_2',
      propertyId: 'prop_1',
      title: 'Quarterly Society Maintenance Fee',
      category: 'Society Fee',
      cost: 9500.0,
      date: DateTime(2024, 7, 1),
      contractorName: 'Green Glen Owners Association',
    ),
  ];

  Future<List<Property>> getProperties(String userId, {bool isDemo = true}) async {
    if (isDemo) return List.from(_mockProperties);
    final snapshot = await firestore
        .collection('users')
        .doc(userId)
        .collection('properties')
        .get();
    return snapshot.docs.map((doc) => Property.fromJson(doc.data())).toList();
  }

  Future<List<PropertyMaintenance>> getMaintenances(String userId, {bool isDemo = true}) async {
    if (isDemo) return List.from(_mockMaintenances);
    final snapshot = await firestore
        .collection('users')
        .doc(userId)
        .collection('propertyMaintenances')
        .get();
    return snapshot.docs.map((doc) => PropertyMaintenance.fromJson(doc.data())).toList();
  }

  Future<void> addProperty(String userId, Property prop, {bool isDemo = true}) async {
    if (isDemo) {
      _mockProperties.add(prop);
      return;
    }
    await firestore
        .collection('users')
        .doc(userId)
        .collection('properties')
        .doc(prop.id)
        .set(prop.toJson());
  }

  Future<void> addMaintenance(String userId, PropertyMaintenance maint, {bool isDemo = true}) async {
    if (isDemo) {
      _mockMaintenances.add(maint);
      return;
    }
    await firestore
        .collection('users')
        .doc(userId)
        .collection('propertyMaintenances')
        .doc(maint.id)
        .set(maint.toJson());
  }
}
