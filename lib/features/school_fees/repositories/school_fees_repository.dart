import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import '../../../core/utils/date_calculators.dart';
import '../models/school_fees_models.dart';

class SchoolFeesRepository {
  final FirebaseFirestore _firestore;
  final Uuid _uuid = const Uuid();

  SchoolFeesRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  // Children
  Future<List<Child>> getChildren(String userId) async {
    if (userId.isEmpty) return const [];
    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('children')
          .orderBy('createdAt', descending: false)
          .get();
      return snapshot.docs.map((d) => Child.fromMap(d.data(), d.id)).toList();
    } catch (e) {
      try {
        final snapshot = await _firestore.collection('users').doc(userId).collection('children').get();
        return snapshot.docs.map((d) => Child.fromMap(d.data(), d.id)).toList();
      } catch (inner) {
        return const [];
      }
    }
  }

  Future<Child> addChild(String userId, Child child) async {
    final newId = child.id.isEmpty ? _uuid.v4() : child.id;
    final newChild = Child(
      id: newId,
      userId: userId,
      name: child.name,
      dateOfBirth: child.dateOfBirth,
      gender: child.gender,
      schoolName: child.schoolName,
      grade: child.grade,
      profilePhotoUrl: child.profilePhotoUrl,
      notes: child.notes,
      createdAt: child.id.isEmpty ? DateTime.now() : child.createdAt,
    );
    await _firestore
        .collection('users')
        .doc(userId)
        .collection('children')
        .doc(newId)
        .set(newChild.toMap());
    return newChild;
  }

  Future<void> deleteChild(String userId, String childId) async {
    if (userId.isEmpty || childId.isEmpty) return;
    await _firestore
        .collection('users')
        .doc(userId)
        .collection('children')
        .doc(childId)
        .delete();
  }

  // Schools
  Future<List<School>> getSchools(String userId) async {
    if (userId.isEmpty) return const [];
    try {
      final snapshot = await _firestore.collection('users').doc(userId).collection('schools').get();
      return snapshot.docs.map((d) => School.fromMap(d.data(), d.id)).toList();
    } catch (e) {
      return const [];
    }
  }

  Future<School> addSchool(String userId, School school) async {
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
    await _firestore.collection('users').doc(userId).collection('schools').doc(newId).set(newSchool.toMap());
    return newSchool;
  }

  // Academic Years
  Future<List<AcademicYear>> getAcademicYears(String userId, String childId) async {
    if (userId.isEmpty || childId.isEmpty) return const [];
    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('academicYears')
          .where('childId', isEqualTo: childId)
          .get();
      return snapshot.docs.map((d) => AcademicYear.fromMap(d.data(), d.id)).toList();
    } catch (e) {
      return const [];
    }
  }

  Future<AcademicYear> addAcademicYear(String userId, AcademicYear ay) async {
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
    await _firestore.collection('users').doc(userId).collection('academicYears').doc(newId).set(newAy.toMap());
    return newAy;
  }

  // Fee Structure & Installments Generator
  Future<FeeStructure> createFeeStructureWithInstallments(String userId, FeeStructure fs, String childId) async {
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

    await _firestore.collection('users').doc(userId).collection('feeStructures').doc(newFsId).set(newFs.toMap());
    for (var inst in installments) {
      await _firestore.collection('users').doc(userId).collection('feeInstallments').doc(inst.id).set(inst.toMap());
    }
    return newFs;
  }

  // Installments
  Future<List<FeeInstallment>> getInstallments(String userId, {String? childId}) async {
    if (userId.isEmpty) return const [];
    try {
      Query query = _firestore.collection('users').doc(userId).collection('feeInstallments');
      if (childId != null && childId.isNotEmpty) {
        query = query.where('childId', isEqualTo: childId);
      }
      final snapshot = await query.get();
      final list = snapshot.docs.map((d) => FeeInstallment.fromMap(d.data() as Map<String, dynamic>, d.id)).toList();
      list.sort((a, b) => a.dueDate.compareTo(b.dueDate));
      return list;
    } catch (e) {
      return const [];
    }
  }

  Future<FeePayment> recordPayment(String userId, FeePayment payment) async {
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

    await _firestore.collection('users').doc(userId).collection('feePayments').doc(newId).set(newPayment.toMap());
    
    // Update installment in Firestore
    final instRef = _firestore.collection('users').doc(userId).collection('feeInstallments').doc(payment.installmentId);
    final instDoc = await instRef.get();
    if (instDoc.exists && instDoc.data() != null) {
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
