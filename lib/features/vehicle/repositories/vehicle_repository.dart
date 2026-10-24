import 'package:cloud_firestore/cloud_firestore.dart';
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
  }

  Future<void> addServiceRecord(String userId, ServiceRecord service) async {
    if (userId.isEmpty) return;
    await firestore
        .collection('users')
        .doc(userId)
        .collection('serviceRecords')
        .doc(service.id)
        .set(service.toJson());
  }
}
