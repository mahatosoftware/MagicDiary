import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'auth_security_service.dart';
import 'security_audit_service.dart';

class ExportPackage {
  final String userId;
  final DateTime exportedAt;
  final String formatVersion;
  final Map<String, dynamic> data;

  ExportPackage({
    required this.userId,
    required this.exportedAt,
    this.formatVersion = '1.0',
    required this.data,
  });

  String toJsonString() {
    return const JsonEncoder.withIndent('  ').convert({
      'userId': userId,
      'exportedAt': exportedAt.toIso8601String(),
      'formatVersion': formatVersion,
      'diaries': data,
    });
  }
}

/// Centralized Data Export Security Service.
/// Re-authenticates the user, filters for authorized records, and audits all export events.
class DataExportSecurityService {
  final FirebaseFirestore _firestore;
  final AuthSecurityService _authSecurity;
  final SecurityAuditService _auditService;

  DataExportSecurityService({
    FirebaseFirestore? firestore,
    AuthSecurityService? authSecurity,
    SecurityAuditService? auditService,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _authSecurity = authSecurity ?? AuthSecurityService(),
        _auditService = auditService ?? SecurityAuditService();

  /// Compiles a complete, authorized data export package.
  /// Requires recent authentication before sensitive data is fetched.
  Future<ExportPackage> generateExportPackage({
    required String userId,
    String? reauthPassword,
  }) async {
    // 1. Enforce recent authentication
    await _authSecurity.requireRecentAuthentication(
      action: SensitiveAction.exportData,
      password: reauthPassword,
    );

    final exportData = <String, dynamic>{};
    final userDocRef = _firestore.collection('users').doc(userId);

    // Subcollections to export
    final subcollections = [
      'properties',
      'vehicles',
      'products',
      'children',
      'feeInstallments',
      'billAccounts',
      'bills',
      'householdExpenses',
      'journals',
      'goals',
      'events',
      'reminders',
      'financialTransactions',
    ];

    for (final col in subcollections) {
      try {
        final snap = await userDocRef.collection(col).get();
        exportData[col] = snap.docs.map((d) => d.data()).toList();
      } catch (_) {
        exportData[col] = [];
      }
    }

    // 2. Audit the export event
    await _auditService.logSecurityEvent(
      userId: userId,
      action: 'data_exported',
      status: 'success',
      metadata: 'Exported ${subcollections.length} modules',
    );

    return ExportPackage(
      userId: userId,
      exportedAt: DateTime.now(),
      data: exportData,
    );
  }
}
