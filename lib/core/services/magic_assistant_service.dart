import 'package:flutter/material.dart';
import '../../features/bills/models/bills_models.dart';
import '../../features/warranty/models/product.dart';
import '../../features/vehicle/models/vehicle_models.dart';
import '../../features/household/models/household_models.dart';
import '../../features/reminders/models/reminder.dart';

enum InsightType {
  urgent,
  warning,
  suggestion,
  celebration,
}

class MagicInsight {
  final String id;
  final String title;
  final String message;
  final InsightType type;
  final String actionLabel;
  final String actionRoute;
  final IconData icon;

  const MagicInsight({
    required this.id,
    required this.title,
    required this.message,
    required this.type,
    required this.actionLabel,
    required this.actionRoute,
    required this.icon,
  });
}

class MagicAssistantService {
  static List<MagicInsight> generateInsights({
    required DateTime now,
    List<Reminder> reminders = const [],
    List<Product> products = const [],
    List<Vehicle> vehicles = const [],
    List<BillAccount> billAccounts = const [],
    List<Bill> bills = const [],
    List<HouseholdBudget> budgets = const [],
    List<HouseholdExpense> householdExpenses = const [],
  }) {
    final insights = <MagicInsight>[];

    // 1. Overdue Reminders Alert
    final overdueCount = reminders.where((r) => r.isOverdue(now)).length;
    if (overdueCount > 0) {
      insights.add(MagicInsight(
        id: 'insight_overdue',
        title: '$overdueCount Action${overdueCount > 1 ? "s" : ""} Overdue',
        message: 'You have $overdueCount pending items that passed their due date. Resolve or reschedule them to stay organized.',
        type: InsightType.urgent,
        actionLabel: 'Review Overdue',
        actionRoute: '/my-day',
        icon: Icons.error_outline,
      ));
    }

    // 2. Product Return Windows Closing Soon (<= 3 days)
    for (final p in products) {
      if (p.returnDeadline != null) {
        final days = p.returnDeadline!.difference(DateTime(now.year, now.month, now.day)).inDays;
        if (days >= 0 && days <= 3) {
          insights.add(MagicInsight(
            id: 'insight_return_${p.id}',
            title: 'Return Window Closing Soon',
            message: '${p.brand} ${p.name} return window closes in $days day${days == 1 ? "" : "s"}. Inspect the item if you wish to exchange or return.',
            type: InsightType.urgent,
            actionLabel: 'View Product',
            actionRoute: '/warranty',
            icon: Icons.assignment_return_outlined,
          ));
        }
      }
    }

    // 3. Vehicle Odometer & Service Milestones
    for (final v in vehicles) {
      if (v.isOdometerServiceDue) {
        final km = v.kmUntilNextService;
        final kmMsg = km <= 0 ? 'exceeded by ${-km} km' : 'due in $km km';
        insights.add(MagicInsight(
          id: 'insight_odo_${v.id}',
          title: 'Service Due: ${v.name}',
          message: '${v.brand} ${v.name} odometer service is $kmMsg. Schedule a service to maintain warranty and performance.',
          type: InsightType.warning,
          actionLabel: 'Schedule Service',
          actionRoute: '/vehicle',
          icon: Icons.build_circle_outlined,
        ));
      }

      if (v.drivingLicenseExpiry != null) {
        final dlDays = v.drivingLicenseExpiry!.difference(DateTime(now.year, now.month, now.day)).inDays;
        if (dlDays >= 0 && dlDays <= 30) {
          insights.add(MagicInsight(
            id: 'insight_dl_${v.id}',
            title: 'License Expiring Soon',
            message: 'Driving license associated with ${v.name} expires in $dlDays days. Apply for renewal online or at RTO.',
            type: InsightType.warning,
            actionLabel: 'Renew License',
            actionRoute: '/vehicle',
            icon: Icons.badge_outlined,
          ));
        }
      }
    }

    // 4. Missing Receipts on Paid Bills
    for (final b in bills) {
      if (b.status.toLowerCase() == 'paid' && (b.notes == null || !b.notes!.toLowerCase().contains('receipt'))) {
        // Flag recently paid bills without receipt mentions
        final daysAgo = DateTime(now.year, now.month, now.day).difference(b.dueDate).inDays;
        if (daysAgo >= 0 && daysAgo <= 7) {
          insights.add(MagicInsight(
            id: 'insight_receipt_${b.id}',
            title: 'Attach Payment Receipt',
            message: 'Bill of ₹${b.amount.toStringAsFixed(0)} for ${b.billPeriod} was settled recently. Store the receipt in Document Vault for tax tracking.',
            type: InsightType.suggestion,
            actionLabel: 'Upload Receipt',
            actionRoute: '/documents',
            icon: Icons.receipt_long_outlined,
          ));
          break; // Show at most one receipt suggestion to prevent clutter
        }
      }
    }

    // 5. Unused Subscriptions Alert
    for (final acc in billAccounts) {
      if (acc.isSubscription && acc.isUnusedFlagged) {
        insights.add(MagicInsight(
          id: 'insight_sub_${acc.id}',
          title: 'Unused Subscription Detected',
          message: 'You have flagged ${acc.name} (${acc.providerName}) as underutilized. Consider canceling or downgrading to save on monthly recurring costs.',
          type: InsightType.suggestion,
          actionLabel: 'Manage Bills',
          actionRoute: '/bills',
          icon: Icons.subscriptions_outlined,
        ));
      }
    }

    // 6. Household Budget Overruns
    if (budgets.isNotEmpty && householdExpenses.isNotEmpty) {
      final currentMonth = now.month;
      final currentYear = now.year;
      final currentMonthExpenses = householdExpenses.where((e) {
        return e.dueDate.month == currentMonth && e.dueDate.year == currentYear;
      });

      final categorySpent = <String, double>{};
      for (final e in currentMonthExpenses) {
        categorySpent[e.category] = (categorySpent[e.category] ?? 0.0) + e.amount;
      }

      for (final b in budgets) {
        final spent = categorySpent[b.category] ?? 0.0;
        if (spent > b.monthlyLimit) {
          final overage = spent - b.monthlyLimit;
          insights.add(MagicInsight(
            id: 'insight_budget_${b.id}',
            title: 'Budget Exceeded: ${b.category}',
            message: 'You have spent ₹${spent.toStringAsFixed(0)} on ${b.category} this month (limit: ₹${b.monthlyLimit.toStringAsFixed(0)}). Over by ₹${overage.toStringAsFixed(0)}.',
            type: InsightType.warning,
            actionLabel: 'View Household',
            actionRoute: '/household',
            icon: Icons.pie_chart_outline,
          ));
        }
      }
    }

    // 7. All Clear Celebration
    if (insights.isEmpty && reminders.isNotEmpty) {
      insights.add(const MagicInsight(
        id: 'insight_all_clear',
        title: 'You\'re All Caught Up!',
        message: 'No overdue tasks, no expiring warranties, and all budgets are within safe thresholds.',
        type: InsightType.celebration,
        actionLabel: 'Add New Record',
        actionRoute: '/my-day',
        icon: Icons.check_circle_outline,
      ));
    }

    return insights;
  }
}
