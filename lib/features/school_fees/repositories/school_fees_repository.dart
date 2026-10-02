import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import '../../../core/utils/mock_data.dart';
import '../../../core/utils/date_calculators.dart';
import '../models/school_fees_models.dart';

class SchoolFeesRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final Uuid _uuid = const Uuid();

  final List<Child> _mockChildren = List.from(MockData.initialChildren);
  final List<School> _mockSchools = List.from(MockData.initialSchools);
  final List<AcademicYear> _mockAcademicYears = List.from(MockData.initialAcademicYears);
  final List<FeeStructure> _mockFeeStructures = List.from(MockData.initialFeeStructures);
  final List<FeeInstallment> _mockInstallments = List.from(MockData.initialInstallments);
  final List<FeePayment> _mockPayments = [];

  // Children
  Future<List<Child>> getChildren(String userId, {bool isDemo = true}) async {
    if (isDemo) return List.unmodifiable(_mockChildren);
    try {
      final snapshot = await _firestore.collection('users').doc(userId).collection('children').get();
      return snapshot.docs.map((d) => Child.fromMap(d.data(), d.id)).toList();
    } catch (e) {
      return List.unmodifiable(_mockChildren);
    }
  }

  Future<Child> addChild(String userId, Child child, {bool isDemo = true}) async {
    final newId = child.id.isEmpty ? _uuid.v4() : child.id;
    final newChild = Child(
      id: newId,
      userId: userId,
      name: child.name,
      dateOfBirth: child.dateOfBirth,
      gender: child.gender,
      profilePhotoUrl: child.profilePhotoUrl,
      notes: child.notes,
      createdAt: DateTime.now(),
    );
    if (isDemo) {
      _mockChildren.add(newChild);
      return newChild;
    }
    await _firestore.collection('users').doc(userId).collection('children').doc(newId).set(newChild.toMap());
    return newChild;
  }

  // Schools
  Future<List<School>> getSchools(String userId, {bool isDemo = true}) async {
    if (isDemo) return List.unmodifiable(_mockSchools);
    try {
      final snapshot = await _firestore.collection('users').doc(userId).collection('schools').get();
      return snapshot.docs.map((d) => School.fromMap(d.data(), d.id)).toList();
    } catch (e) {
      return List.unmodifiable(_mockSchools);
    }
  }

  Future<School> addSchool(String userId, School school, {bool isDemo = true}) async {
    final newId = school.id.isEmpty ? _uuid.v4() : school.id;
    final newSchool = School(
      id: newId,
      userId: userId,
      name: school.name,
      address: school.address,
      contactPhone: school.contactPhone,
      contactEmail: school.contactEmail,
      website: school.website,
      createdAt: DateTime.now(),
    );
    if (isDemo) {
      _mockSchools.add(newSchool);
      return newSchool;
    }
    await _firestore.collection('users').doc(userId).collection('schools').doc(newId).set(newSchool.toMap());
    return newSchool;
  }

  // Academic Years
  Future<List<AcademicYear>> getAcademicYears(String userId, String childId, {bool isDemo = true}) async {
    if (isDemo) return _mockAcademicYears.where((ay) => ay.childId == childId).toList();
    try {
      final snapshot = await _firestore.collection('users').doc(userId).collection('academicYears').where('childId', isEqualTo: childId).get();
      return snapshot.docs.map((d) => AcademicYear.fromMap(d.data(), d.id)).toList();
    } catch (e) {
      return _mockAcademicYears.where((ay) => ay.childId == childId).toList();
    }
  }

  Future<AcademicYear> addAcademicYear(String userId, AcademicYear ay, {bool isDemo = true}) async {
    final newId = ay.id.isEmpty ? _uuid.v4() : ay.id;
    final newAy = AcademicYear(
      id: newId,
      childId: ay.childId,
      schoolId: ay.schoolId,
      yearLabel: ay.yearLabel,
      grade: ay.grade,
      startDate: ay.startDate,
      endDate: ay.endDate,
      createdAt: DateTime.now(),
    );
    if (isDemo) {
      _mockAcademicYears.add(newAy);
      return newAy;
    }
    await _firestore.collection('users').doc(userId).collection('academicYears').doc(newId).set(newAy.toMap());
    return newAy;
  }

  // Fee Structure & Installments Generator
  Future<FeeStructure> createFeeStructureWithInstallments(String userId, FeeStructure fs, String childId, {bool isDemo = true}) async {
    final newFsId = fs.id.isEmpty ? _uuid.v4() : fs.id;
    final newFs = FeeStructure(
      id: newFsId,
      academicYearId: fs.academicYearId,
      name: fs.name,
      totalAmount: fs.totalAmount,
      frequency: fs.frequency,
      numberOfInstallments: fs.numberOfInstallments,
      firstDueDate: fs.firstDueDate,
      createdAt: DateTime.now(),
    );

    // Generate installments
    final generated = DateCalculators.generateSchoolFeeSchedule(
      feeStructureId: newFsId,
      childId: childId,
      totalAmount: fs.totalAmount,
      frequency: fs.frequency,
      numberOfInstallments: fs.numberOfInstallments,
      firstDueDate: fs.firstDueDate,
    );

    final installments = generated.map((instMap) => FeeInstallment(
      id: _uuid.v4(),
      feeStructureId: newFsId,
      childId: childId,
      installmentNumber: instMap['installmentNumber'],
      title: instMap['title'],
      amount: instMap['amount'],
      dueDate: instMap['dueDate'],
      status: 'pending',
      paidAmount: 0.0,
    )).toList();

    if (isDemo) {
      _mockFeeStructures.add(newFs);
      _mockInstallments.addAll(installments);
      return newFs;
    }

    await _firestore.collection('users').doc(userId).collection('feeStructures').doc(newFsId).set(newFs.toMap());
    for (var inst in installments) {
      await _firestore.collection('users').doc(userId).collection('feeInstallments').doc(inst.id).set(inst.toMap());
    }
    return newFs;
  }

  // Installments
  Future<List<FeeInstallment>> getInstallments(String userId, {String? childId, bool isDemo = true}) async {
    if (isDemo) {
      if (childId != null) {
        return _mockInstallments.where((i) => i.childId == childId).toList();
      }
      return List.unmodifiable(_mockInstallments);
    }
    try {
      Query query = _firestore.collection('users').doc(userId).collection('feeInstallments');
      if (childId != null) {
        query = query.where('childId', isEqualTo: childId);
      }
      final snapshot = await query.get();
      return snapshot.docs.map((d) => FeeInstallment.fromMap(d.data() as Map<String, dynamic>, d.id)).toList();
    } catch (e) {
      return List.unmodifiable(_mockInstallments);
    }
  }

  Future<FeePayment> recordPayment(String userId, FeePayment payment, {bool isDemo = true}) async {
    final newId = payment.id.isEmpty ? _uuid.v4() : payment.id;
    final newPayment = FeePayment(
      id: newId,
      installmentId: payment.installmentId,
      amountPaid: payment.amountPaid,
      paymentDate: payment.paymentDate,
      paymentMethod: payment.paymentMethod,
      transactionRef: payment.transactionRef,
      receiptDocumentId: payment.receiptDocumentId,
      notes: payment.notes,
    );

    if (isDemo) {
      _mockPayments.add(newPayment);
      final instIndex = _mockInstallments.indexWhere((i) => i.id == payment.installmentId);
      if (instIndex != -1) {
        final current = _mockInstallments[instIndex];
        final newPaidAmount = current.paidAmount + payment.amountPaid;
        final newStatus = newPaidAmount >= current.amount ? 'paid' : 'partially_paid';
        _mockInstallments[instIndex] = FeeInstallment(
          id: current.id,
          feeStructureId: current.feeStructureId,
          childId: current.childId,
          installmentNumber: current.installmentNumber,
          title: current.title,
          amount: current.amount,
          dueDate: current.dueDate,
          status: newStatus,
          paidAmount: newPaidAmount,
          paidDate: payment.paymentDate,
        );
      }
      return newPayment;
    }

    await _firestore.collection('users').doc(userId).collection('feePayments').doc(newId).set(newPayment.toMap());
    
    // Update installment
    final instRef = _firestore.collection('users').doc(userId).collection('feeInstallments').doc(payment.installmentId);
    final instDoc = await instRef.get();
    if (instDoc.exists) {
      final currentInst = FeeInstallment.fromMap(instDoc.data()!, instDoc.id);
      final newPaidAmount = currentInst.paidAmount + payment.amountPaid;
      final newStatus = newPaidAmount >= currentInst.amount ? 'paid' : 'partially_paid';
      await instRef.update({
        'paidAmount': newPaidAmount,
        'status': newStatus,
        'paidDate': Timestamp.fromDate(payment.paymentDate),
      });
    }

    return newPayment;
  }
}
