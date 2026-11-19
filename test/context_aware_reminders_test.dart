import 'package:flutter_test/flutter_test.dart';
import 'package:magic_diary/core/security/diary_access_control_service.dart';
import 'package:magic_diary/features/reminders/models/reminder.dart';
import 'package:magic_diary/features/reminders/services/reminder_action_resolver.dart';
import 'package:magic_diary/features/shared_diaries/models/shared_diary_models.dart';

void main() {
  group('ReminderActionResolver Context-Aware Classification Tests', () {
    final now = DateTime(2026, 11, 25, 10, 0);

    test('Financial reminders correctly resolve to markPaid', () {
      final electricityBill = Reminder(
        id: 'rem_elec',
        userId: 'u1',
        title: 'Electricity Bill Due',
        description: 'Monthly electricity bill from Tata Power. Amount: ₹1850.',
        module: 'Bills',
        status: 'pending',
        dueDate: now,
        amount: 1850.0,
        createdAt: now,
      );

      final loanEmi = Reminder(
        id: 'rem_emi',
        userId: 'u1',
        title: 'Home Loan EMI: HDFC Bank',
        description: 'Monthly installment of ₹45,000.',
        module: 'Finance',
        status: 'pending',
        dueDate: now,
        amount: 45000.0,
        createdAt: now,
      );

      final schoolFee = Reminder(
        id: 'rem_fee',
        userId: 'u1',
        title: 'School Fee: Term 2 Installment',
        description: 'Tuition fees for Aarav',
        module: 'SchoolFees',
        status: 'pending',
        dueDate: now,
        amount: 25000.0,
        createdAt: now,
      );

      final insurancePremium = Reminder(
        id: 'rem_ins',
        userId: 'u1',
        title: 'Vehicle Insurance Premium Due',
        description: 'Pay annual comprehensive insurance premium',
        module: 'Vehicle',
        status: 'pending',
        dueDate: now,
        amount: 12500.0,
        createdAt: now,
      );

      final rentPayment = Reminder(
        id: 'rem_rent',
        userId: 'u1',
        title: 'Apartment Rent Payment',
        description: 'Monthly house rent to landlord',
        module: 'Property',
        status: 'pending',
        dueDate: now,
        amount: 22000.0,
        createdAt: now,
      );

      final maidSalary = Reminder(
        id: 'rem_salary',
        userId: 'u1',
        title: 'Salary Payment: Sunita (Housekeeping)',
        description: 'Monthly domestic help salary',
        module: 'DomesticHelp',
        status: 'pending',
        dueDate: now,
        amount: 6000.0,
        createdAt: now,
      );

      expect(ReminderActionResolver.resolve(electricityBill), equals(ReminderActionType.markPaid));
      expect(ReminderActionResolver.resolve(loanEmi), equals(ReminderActionType.markPaid));
      expect(ReminderActionResolver.resolve(schoolFee), equals(ReminderActionType.markPaid));
      expect(ReminderActionResolver.resolve(insurancePremium), equals(ReminderActionType.markPaid));
      expect(ReminderActionResolver.resolve(rentPayment), equals(ReminderActionType.markPaid));
      expect(ReminderActionResolver.resolve(maidSalary), equals(ReminderActionType.markPaid));
      expect(ReminderActionResolver.isFinancial(electricityBill), isTrue);
    });

    test('Non-financial reminders correctly resolve to markComplete', () {
      final vehicleService = Reminder(
        id: 'rem_serv',
        userId: 'u1',
        title: 'Routine Service Appointment: Honda City',
        description: 'Periodic maintenance at Authorized Service Station',
        module: 'Vehicle',
        status: 'pending',
        dueDate: now,
        createdAt: now,
      );

      final pucRenewal = Reminder(
        id: 'rem_puc',
        userId: 'u1',
        title: 'PUC Certificate Renewal',
        description: 'Get pollution check done for vehicle',
        module: 'Vehicle',
        status: 'pending',
        dueDate: now,
        createdAt: now,
      );

      final warrantyVerification = Reminder(
        id: 'rem_warr',
        userId: 'u1',
        title: 'Warranty Document Verification: Refrigerator',
        description: 'Check extended warranty coverage period',
        module: 'Warranty',
        status: 'pending',
        dueDate: now,
        createdAt: now,
      );

      final doctorAppt = Reminder(
        id: 'rem_doc',
        userId: 'u1',
        title: 'Doctor Appointment: Annual Health Checkup',
        description: 'Visit Apollo Clinic at 4:00 PM',
        module: 'Personal',
        status: 'pending',
        dueDate: now,
        createdAt: now,
      );

      final birthdayPrep = Reminder(
        id: 'rem_bday',
        userId: 'u1',
        title: 'Birthday: Priya Sharma',
        description: 'Order birthday cake and gifts',
        module: 'Personal',
        status: 'pending',
        dueDate: now,
        createdAt: now,
      );

      expect(ReminderActionResolver.resolve(vehicleService), equals(ReminderActionType.markComplete));
      expect(ReminderActionResolver.resolve(pucRenewal), equals(ReminderActionType.markComplete));
      expect(ReminderActionResolver.resolve(warrantyVerification), equals(ReminderActionType.markComplete));
      expect(ReminderActionResolver.resolve(doctorAppt), equals(ReminderActionType.markComplete));
      expect(ReminderActionResolver.resolve(birthdayPrep), equals(ReminderActionType.markComplete));
      expect(ReminderActionResolver.isFinancial(vehicleService), isFalse);
    });

    test('Document uploads and non-financial tasks in financial modules are NOT marked as financial', () {
      final insuranceDocUpload = Reminder(
        id: 'rem_ins_doc',
        userId: 'u1',
        title: 'Insurance Document Upload',
        description: 'Upload renewed vehicle insurance policy copy to diary',
        module: 'Vehicle',
        status: 'pending',
        dueDate: now,
        createdAt: now,
      );

      final kycVerification = Reminder(
        id: 'rem_kyc',
        userId: 'u1',
        title: 'Bank KYC Document Verification Task',
        description: 'Submit updated address proof to bank branch',
        module: 'Finance',
        status: 'pending',
        dueDate: now,
        createdAt: now,
      );

      expect(ReminderActionResolver.resolve(insuranceDocUpload), equals(ReminderActionType.markComplete));
      expect(ReminderActionResolver.resolve(kycVerification), equals(ReminderActionType.markComplete));
    });

    test('Issues and complaints resolve to markResolved', () {
      final billingDispute = Reminder(
        id: 'rem_dispute',
        userId: 'u1',
        title: 'Overcharge Complaint: Broadband Billing Dispute',
        description: 'Follow up on ticket #9872 with customer care',
        module: 'Bills',
        status: 'pending',
        dueDate: now,
        createdAt: now,
      );

      final plumbingDefect = Reminder(
        id: 'rem_defect',
        userId: 'u1',
        title: 'Plumbing Issue Grievance',
        description: 'Society maintenance complaint for pipe leakage',
        module: 'Household',
        status: 'pending',
        dueDate: now,
        createdAt: now,
      );

      expect(ReminderActionResolver.resolve(billingDispute), equals(ReminderActionType.markResolved));
      expect(ReminderActionResolver.resolve(plumbingDefect), equals(ReminderActionType.markResolved));
    });

    test('Informational notices resolve to markAcknowledged', () {
      final societyNotice = Reminder(
        id: 'rem_notice',
        userId: 'u1',
        title: 'Society Annual Meeting Notice',
        description: 'General body circular for upcoming AGM',
        module: 'Household',
        status: 'pending',
        dueDate: now,
        createdAt: now,
      );

      expect(ReminderActionResolver.resolve(societyNotice), equals(ReminderActionType.markAcknowledged));
    });

    test('Explicit actionType override is respected', () {
      final customReminder = Reminder(
        id: 'rem_cust',
        userId: 'u1',
        title: 'Custom Task Action',
        description: 'Some task',
        module: 'General',
        status: 'pending',
        dueDate: now,
        actionType: 'mark_resolved',
        createdAt: now,
      );

      expect(ReminderActionResolver.resolve(customReminder), equals(ReminderActionType.markResolved));
    });
  });

  group('Reminder Model & Payment Details Serialization Tests', () {
    test('ReminderPaymentDetails correctly serializes and deserializes', () {
      final paidAt = DateTime(2026, 11, 24, 14, 30);

      final detailsWithDate = ReminderPaymentDetails(
        amount: 1850.0,
        currency: 'INR',
        paidAt: paidAt,
        paymentMethod: 'UPI',
        transactionReference: 'UPI-9876543210',
        notes: 'Paid via Google Pay',
      );

      final map = detailsWithDate.toMap();
      expect(map['amount'], equals(1850.0));
      expect(map['paymentMethod'], equals('UPI'));
      expect(map['transactionReference'], equals('UPI-9876543210'));

      final restored = ReminderPaymentDetails.fromMap(map);
      expect(restored.amount, equals(1850.0));
      expect(restored.paymentMethod, equals('UPI'));
      expect(restored.transactionReference, equals('UPI-9876543210'));
      expect(restored.notes, equals('Paid via Google Pay'));
    });

    test('Reminder model serializes and deserializes payment and occurrence metadata', () {
      final now = DateTime(2026, 11, 20, 10, 0);
      final paidAt = DateTime(2026, 11, 24, 11, 0);

      final reminder = Reminder(
        id: 'rem_recur_bill_1',
        userId: 'u123',
        title: 'Electricity Bill',
        description: 'Monthly electricity bill',
        module: 'Bills',
        status: 'paid',
        dueDate: DateTime(2026, 11, 25),
        amount: 1850.0,
        isFinancial: true,
        actionType: 'mark_paid',
        repeatSchedule: 'monthly',
        occurrenceId: 'occ_2026_11_25',
        completedAt: paidAt,
        completedBy: 'u123',
        paymentDetails: ReminderPaymentDetails(
          amount: 1850.0,
          currency: 'INR',
          paidAt: paidAt,
          paymentMethod: 'UPI',
          transactionReference: 'TXN123456',
        ),
        createdAt: now,
      );

      expect(reminder.isPaid, isTrue);
      expect(reminder.isCompleted, isTrue);
      expect(reminder.isPending, isFalse);

      final map = reminder.toMap();
      expect(map['status'], equals('paid'));
      expect(map['isFinancial'], isTrue);
      expect(map['repeatSchedule'], equals('monthly'));
      expect(map['occurrenceId'], equals('occ_2026_11_25'));
      expect(map['completedBy'], equals('u123'));
      expect(map['payment'], isNotNull);

      final restored = Reminder.fromMap(map, 'rem_recur_bill_1');
      expect(restored.id, equals('rem_recur_bill_1'));
      expect(restored.status, equals('paid'));
      expect(restored.isPaid, isTrue);
      expect(restored.paymentDetails?.paymentMethod, equals('UPI'));
      expect(restored.paymentDetails?.transactionReference, equals('TXN123456'));
    });
  });

  group('Shared Diary Permission Checks for Reminders', () {
    final now = DateTime(2026, 11, 1);

    test('Owner, Admin, Editor, and Contributor can complete or pay reminders', () {
      // Owner
      expect(
        DiaryAccessControlService.canCompleteOrPayReminder(
          currentUserId: 'owner_user',
          diaryOwnerId: 'owner_user',
        ),
        isTrue,
      );

      // Admin
      final adminAccess = SharedDiaryAccess(
        id: 'share_admin',
        diaryId: 'bills',
        diaryName: 'Bills & Utilities',
        ownerUid: 'owner_user',
        ownerName: 'Owner User',
        sharedWithUid: 'admin_user',
        sharedWithEmail: 'admin@test.com',
        sharedWithName: 'Admin User',
        permission: SharedDiaryPermission.admin,
        status: ShareStatus.active,
        createdAt: now,
        updatedAt: now,
      );
      expect(
        DiaryAccessControlService.canCompleteOrPayReminder(
          currentUserId: 'admin_user',
          diaryOwnerId: 'owner_user',
          shareAccess: adminAccess,
        ),
        isTrue,
      );

      // Editor
      final editorAccess = SharedDiaryAccess(
        id: 'share_editor',
        diaryId: 'bills',
        diaryName: 'Bills & Utilities',
        ownerUid: 'owner_user',
        ownerName: 'Owner User',
        sharedWithUid: 'editor_user',
        sharedWithEmail: 'editor@test.com',
        sharedWithName: 'Editor User',
        permission: SharedDiaryPermission.editor,
        status: ShareStatus.active,
        createdAt: now,
        updatedAt: now,
      );
      expect(
        DiaryAccessControlService.canCompleteOrPayReminder(
          currentUserId: 'editor_user',
          diaryOwnerId: 'owner_user',
          shareAccess: editorAccess,
        ),
        isTrue,
      );

      // Contributor
      final contributorAccess = SharedDiaryAccess(
        id: 'share_contrib',
        diaryId: 'bills',
        diaryName: 'Bills & Utilities',
        ownerUid: 'owner_user',
        ownerName: 'Owner User',
        sharedWithUid: 'contrib_user',
        sharedWithEmail: 'contrib@test.com',
        sharedWithName: 'Contrib User',
        permission: SharedDiaryPermission.contributor,
        status: ShareStatus.active,
        createdAt: now,
        updatedAt: now,
      );
      expect(
        DiaryAccessControlService.canCompleteOrPayReminder(
          currentUserId: 'contrib_user',
          diaryOwnerId: 'owner_user',
          shareAccess: contributorAccess,
        ),
        isTrue,
      );
    });

    test('Viewer is strictly rejected from completing or recording payments', () {
      final viewerAccess = SharedDiaryAccess(
        id: 'share_viewer',
        diaryId: 'bills',
        diaryName: 'Bills & Utilities',
        ownerUid: 'owner_user',
        ownerName: 'Owner User',
        sharedWithUid: 'viewer_user',
        sharedWithEmail: 'viewer@test.com',
        sharedWithName: 'Viewer User',
        permission: SharedDiaryPermission.viewer,
        status: ShareStatus.active,
        createdAt: now,
        updatedAt: now,
      );

      expect(
        DiaryAccessControlService.canCompleteOrPayReminder(
          currentUserId: 'viewer_user',
          diaryOwnerId: 'owner_user',
          shareAccess: viewerAccess,
        ),
        isFalse,
      );
    });
  });
}
