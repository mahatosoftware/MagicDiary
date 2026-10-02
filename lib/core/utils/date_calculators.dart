enum DeferOption { plus1Day, plus1Week, plus1Month, customDays }

class WarrantyCalculation {
  final String status; // 'active', 'expiring_soon', 'expired', 'unknown'
  final int? daysRemaining;
  final String? effectiveEndDate;

  WarrantyCalculation({
    required this.status,
    this.daysRemaining,
    this.effectiveEndDate,
  });
}

class DateCalculators {
  static String getWarrantyStatus(DateTime endDate) {
    final diffDays = endDate.difference(DateTime.now()).inDays;
    if (diffDays < 0) return 'expired';
    if (diffDays <= 30) return 'expiring_soon';
    return 'active';
  }

  static DateTime calculateDeferredDate(DateTime base, DeferOption option, {int customDays = 0}) {
    switch (option) {
      case DeferOption.plus1Day:
        return base.add(const Duration(days: 1));
      case DeferOption.plus1Week:
        return base.add(const Duration(days: 7));
      case DeferOption.plus1Month:
        return DateTime(base.year, base.month + 1, base.day);
      case DeferOption.customDays:
        return base.add(Duration(days: customDays));
    }
  }

  static WarrantyCalculation calculateWarrantyStatus({
    required bool hasWarranty,
    String? warrantyStartDate,
    String? warrantyEndDate,
    int? warrantyDurationMonths,
    String? extendedWarrantyEndDate,
    DateTime? referenceDate,
  }) {
    if (!hasWarranty) {
      return WarrantyCalculation(status: 'unknown', daysRemaining: null, effectiveEndDate: null);
    }

    final now = referenceDate ?? DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    String? effectiveEnd = extendedWarrantyEndDate;

    if (effectiveEnd == null || effectiveEnd.isEmpty) {
      if (warrantyEndDate != null && warrantyEndDate.isNotEmpty) {
        effectiveEnd = warrantyEndDate;
      } else if (warrantyStartDate != null &&
          warrantyStartDate.isNotEmpty &&
          warrantyDurationMonths != null &&
          warrantyDurationMonths > 0) {
        final start = DateTime.tryParse(warrantyStartDate);
        if (start != null) {
          final end = DateTime(start.year, start.month + warrantyDurationMonths, start.day);
          effectiveEnd = end.toIso8601String().split('T')[0];
        }
      }
    }

    if (effectiveEnd == null || effectiveEnd.isEmpty) {
      return WarrantyCalculation(status: 'unknown', daysRemaining: null, effectiveEndDate: null);
    }

    final endDate = DateTime.tryParse(effectiveEnd);
    if (endDate == null) {
      return WarrantyCalculation(status: 'unknown', daysRemaining: null, effectiveEndDate: null);
    }

    final targetDate = DateTime(endDate.year, endDate.month, endDate.day);
    final diffDays = targetDate.difference(today).inDays;

    String status;
    if (diffDays < 0) {
      status = 'expired';
    } else if (diffDays <= 30) {
      status = 'expiring_soon';
    } else {
      status = 'active';
    }

    return WarrantyCalculation(
      status: status,
      daysRemaining: diffDays,
      effectiveEndDate: effectiveEnd,
    );
  }

  static List<Map<String, dynamic>> generateSchoolFeeSchedule({
    required String feeStructureId,
    required String childId,
    required double totalAmount,
    required String frequency,
    required int numberOfInstallments,
    required DateTime firstDueDate,
  }) {
    final List<Map<String, dynamic>> schedule = [];
    final amountPerInstallment = totalAmount / (numberOfInstallments > 0 ? numberOfInstallments : 1);

    int monthIncrement = 3;
    if (frequency == 'Monthly') monthIncrement = 1;
    if (frequency == 'Quarterly') monthIncrement = 3;
    if (frequency == 'Semi-Annually') monthIncrement = 6;
    if (frequency == 'Annually') monthIncrement = 12;

    for (int i = 0; i < numberOfInstallments; i++) {
      final dueDate = DateTime(firstDueDate.year, firstDueDate.month + (i * monthIncrement), firstDueDate.day);
      schedule.add({
        'installmentNumber': i + 1,
        'title': 'Installment ${i + 1} ($frequency)',
        'amount': amountPerInstallment,
        'dueDate': dueDate,
      });
    }

    return schedule;
  }
}
