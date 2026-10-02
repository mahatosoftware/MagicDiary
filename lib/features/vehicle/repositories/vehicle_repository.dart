import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/vehicle_models.dart';

class VehicleRepository {
  final FirebaseFirestore? _firestore;
  VehicleRepository({FirebaseFirestore? firestore}) : _firestore = firestore;

  FirebaseFirestore get firestore => _firestore ?? FirebaseFirestore.instance;

  final List<Vehicle> _mockVehicles = [
    Vehicle(
      id: 'veh_1',
      name: 'Hyundai Creta SX',
      type: 'Car',
      brand: 'Hyundai',
      model: 'Creta 2023',
      registrationNumber: 'KA-01-MJ-8821',
      purchaseDate: DateTime(2023, 5, 12),
      currentOdometer: 18450,
      insuranceExpiry: DateTime.now().add(const Duration(days: 45)),
      pucExpiry: DateTime.now().add(const Duration(days: 12)),
      loanEmiAmount: 18500.0,
      nextServiceDate: DateTime.now().add(const Duration(days: 60)),
      fastagId: 'FTG-8821901',
    ),
    Vehicle(
      id: 'veh_2',
      name: 'Royal Enfield Hunter 350',
      type: 'Bike',
      brand: 'Royal Enfield',
      model: 'Hunter 350 Dapper',
      registrationNumber: 'KA-03-HA-4412',
      purchaseDate: DateTime(2024, 1, 10),
      currentOdometer: 4200,
      insuranceExpiry: DateTime.now().add(const Duration(days: 120)),
      pucExpiry: DateTime.now().add(const Duration(days: 90)),
      loanEmiAmount: null,
      nextServiceDate: DateTime.now().add(const Duration(days: 15)),
      fastagId: null,
    ),
  ];

  final List<ServiceRecord> _mockServices = [
    ServiceRecord(
      id: 'srv_1',
      vehicleId: 'veh_1',
      serviceDate: DateTime(2024, 4, 15),
      odometerReading: 12000,
      serviceType: 'Periodic Service',
      workPerformed: 'Engine oil change, air filter replacement, wheel balancing',
      totalCost: 4850.0,
      serviceCenter: 'Hyundai Authorised Service Center, Indiranagar',
    ),
    ServiceRecord(
      id: 'srv_2',
      vehicleId: 'veh_1',
      serviceDate: DateTime(2024, 8, 20),
      odometerReading: 17500,
      serviceType: 'Tyre Replacement',
      workPerformed: 'Front 2 tyres replaced with Michelin Primacy 4',
      totalCost: 16200.0,
      serviceCenter: 'PitLine Tyre Shop',
    ),
  ];

  Future<List<Vehicle>> getVehicles(String userId, {bool isDemo = true}) async {
    if (isDemo) return List.from(_mockVehicles);
    final snapshot = await firestore
        .collection('users')
        .doc(userId)
        .collection('vehicles')
        .get();
    return snapshot.docs.map((doc) => Vehicle.fromJson(doc.data())).toList();
  }

  Future<List<ServiceRecord>> getServices(String userId, {bool isDemo = true}) async {
    if (isDemo) return List.from(_mockServices);
    final snapshot = await firestore
        .collection('users')
        .doc(userId)
        .collection('serviceRecords')
        .get();
    return snapshot.docs.map((doc) => ServiceRecord.fromJson(doc.data())).toList();
  }

  Future<void> addVehicle(String userId, Vehicle vehicle, {bool isDemo = true}) async {
    if (isDemo) {
      _mockVehicles.add(vehicle);
      return;
    }
    await firestore
        .collection('users')
        .doc(userId)
        .collection('vehicles')
        .doc(vehicle.id)
        .set(vehicle.toJson());
  }

  Future<void> addServiceRecord(String userId, ServiceRecord service, {bool isDemo = true}) async {
    if (isDemo) {
      _mockServices.add(service);
      return;
    }
    await firestore
        .collection('users')
        .doc(userId)
        .collection('serviceRecords')
        .doc(service.id)
        .set(service.toJson());
  }
}
