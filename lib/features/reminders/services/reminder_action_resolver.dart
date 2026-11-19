import 'package:flutter/material.dart';
import '../models/reminder.dart';

/// Supported reminder action types.
enum ReminderActionType {
  markPaid,
  markComplete,
  markResolved,
  markAcknowledged,
  custom;

  String toDbString() {
    switch (this) {
      case ReminderActionType.markPaid:
        return 'mark_paid';
      case ReminderActionType.markComplete:
        return 'mark_complete';
      case ReminderActionType.markResolved:
        return 'mark_resolved';
      case ReminderActionType.markAcknowledged:
        return 'mark_acknowledged';
      case ReminderActionType.custom:
        return 'custom';
    }
  }

  static ReminderActionType fromString(String? val) {
    if (val == null || val.isEmpty) return ReminderActionType.markComplete;
    final lower = val.toLowerCase().replaceAll('-', '_').replaceAll(' ', '_').trim();
    switch (lower) {
      case 'mark_paid':
      case 'pay':
      case 'paid':
        return ReminderActionType.markPaid;
      case 'mark_complete':
      case 'complete':
      case 'completed':
      case 'done':
        return ReminderActionType.markComplete;
      case 'mark_resolved':
      case 'resolve':
      case 'resolved':
        return ReminderActionType.markResolved;
      case 'mark_acknowledged':
      case 'acknowledge':
      case 'acknowledged':
        return ReminderActionType.markAcknowledged;
      case 'custom':
        return ReminderActionType.custom;
      default:
        return ReminderActionType.markComplete;
    }
  }

  String get label {
    switch (this) {
      case ReminderActionType.markPaid:
        return 'Mark as Paid';
      case ReminderActionType.markComplete:
        return 'Mark as Complete';
      case ReminderActionType.markResolved:
        return 'Mark as Resolved';
      case ReminderActionType.markAcknowledged:
        return 'Mark as Acknowledged';
      case ReminderActionType.custom:
        return 'Action';
    }
  }

  String get pastTenseLabel {
    switch (this) {
      case ReminderActionType.markPaid:
        return 'Paid';
      case ReminderActionType.markComplete:
        return 'Completed';
      case ReminderActionType.markResolved:
        return 'Resolved';
      case ReminderActionType.markAcknowledged:
        return 'Acknowledged';
      case ReminderActionType.custom:
        return 'Completed';
    }
  }

  IconData get icon {
    switch (this) {
      case ReminderActionType.markPaid:
        return Icons.payments_outlined;
      case ReminderActionType.markComplete:
        return Icons.check_circle_outline;
      case ReminderActionType.markResolved:
        return Icons.task_alt;
      case ReminderActionType.markAcknowledged:
        return Icons.thumb_up_alt_outlined;
      case ReminderActionType.custom:
        return Icons.arrow_forward;
    }
  }

  Color get color {
    switch (this) {
      case ReminderActionType.markPaid:
        return const Color(0xFF2E7D32); // Forest Green
      case ReminderActionType.markComplete:
        return const Color(0xFF1565C0); // Cobalt Blue
      case ReminderActionType.markResolved:
        return const Color(0xFF6A1B9A); // Deep Purple
      case ReminderActionType.markAcknowledged:
        return const Color(0xFF00838F); // Cyan/Teal
      case ReminderActionType.custom:
        return Colors.blueGrey;
    }
  }
}

/// Centralized Context-Aware Reminder Action Resolver.
/// Resolves the semantic completion action based on explicit configuration,
/// financial classification, linked record type, and domain content.
class ReminderActionResolver {
  /// Keywords indicating financial payments/settlements.
  static final RegExp _financialKeywords = RegExp(
    r'\b(bill|payment|pay|emi|loan|fee|fees|tuition|premium|rent|installment|salary|tax|invoice|subscription renewal|recharge)\b',
    caseSensitive: false,
  );

  /// Keywords indicating resolutions (disputes, complaints, issues).
  static final RegExp _resolvedKeywords = RegExp(
    r'\b(complaint|issue|grievance|ticket|dispute|defect|repair request)\b',
    caseSensitive: false,
  );

  /// Keywords indicating acknowledgments (informational, circulars, notices).
  static final RegExp _acknowledgedKeywords = RegExp(
    r'\b(notice|circular|announcement|policy update|alert memo|guidelines)\b',
    caseSensitive: false,
  );

  /// Resolves the appropriate action type for a reminder.
  static ReminderActionType resolve(Reminder reminder) {
    // 1. Explicit configured action type matching canonical types
    final explicitType = reminder.actionType.toLowerCase().replaceAll('-', '_').trim();
    if (explicitType == 'mark_paid' || explicitType == 'pay') {
      return ReminderActionType.markPaid;
    }
    if (explicitType == 'mark_complete') {
      return ReminderActionType.markComplete;
    }
    if (explicitType == 'mark_resolved' || explicitType == 'resolve') {
      return ReminderActionType.markResolved;
    }
    if (explicitType == 'mark_acknowledged' || explicitType == 'acknowledge') {
      return ReminderActionType.markAcknowledged;
    }
    if (explicitType == 'custom') {
      return ReminderActionType.custom;
    }

    // 2. Explicit financial classification flag
    if (reminder.isFinancial == true) {
      return ReminderActionType.markPaid;
    }
    if (reminder.isFinancial == false) {
      // Check for resolved / acknowledged before defaulting to complete
      final fullText = '${reminder.title} ${reminder.description}';
      if (_resolvedKeywords.hasMatch(fullText)) {
        return ReminderActionType.markResolved;
      }
      if (_acknowledgedKeywords.hasMatch(fullText)) {
        return ReminderActionType.markAcknowledged;
      }
      return ReminderActionType.markComplete;
    }

    // 3. Inspect Title, Description, and Module for Financial vs Non-Financial context
    final fullText = '${reminder.title} ${reminder.description}'.toLowerCase();

    // Check for issues / complaints
    if (_resolvedKeywords.hasMatch(fullText)) {
      return ReminderActionType.markResolved;
    }

    // Check for informational notices
    if (_acknowledgedKeywords.hasMatch(fullText)) {
      return ReminderActionType.markAcknowledged;
    }

    // Distinguish specific task/verification cases:
    // e.g. "Vehicle service appointment" vs "Vehicle service invoice payment"
    // e.g. "Insurance document upload" vs "Insurance premium payment"
    // e.g. "Complete property audit / verify papers" vs "Property tax payment"
    final isExplicitAppointmentOrTask = fullText.contains('appointment') ||
        fullText.contains('inspection') ||
        fullText.contains('audit') ||
        fullText.contains('upload') ||
        fullText.contains('servicing') ||
        fullText.contains('maintenance task') ||
        fullText.contains('puc renewal') ||
        fullText.contains('verification') ||
        fullText.contains('verify') ||
        fullText.contains('preparation');

    final isExplicitPaymentWord = fullText.contains('payment') ||
        fullText.contains('bill') ||
        fullText.contains('emi') ||
        fullText.contains('installment') ||
        fullText.contains('premium') ||
        fullText.contains('rent') ||
        fullText.contains('salary') ||
        fullText.contains('invoice') ||
        fullText.contains('fee');

    final hasFinancialKeyword = _financialKeywords.hasMatch(fullText);
    final hasAmount = reminder.amount != null && reminder.amount! > 0;

    if (isExplicitAppointmentOrTask && !isExplicitPaymentWord) {
      return ReminderActionType.markComplete;
    }

    if (hasFinancialKeyword) {
      return ReminderActionType.markPaid;
    }

    if (hasAmount && !isExplicitAppointmentOrTask) {
      return ReminderActionType.markPaid;
    }

    // 4. Safe fallback to Mark as Complete
    return ReminderActionType.markComplete;
  }

  /// Whether this reminder requires a payment settlement interface.
  static bool isFinancial(Reminder reminder) {
    return resolve(reminder) == ReminderActionType.markPaid;
  }
}
