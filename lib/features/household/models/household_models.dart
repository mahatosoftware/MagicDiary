class HouseholdExpense {
  static const List<String> frequencies = [
    'Monthly',
    'Quarterly',
    'Semi-Annual',
    'Annual',
    'Weekly',
    'Bi-Weekly',
    'Daily',
    'One-Time',
  ];

  final String id;
  final String category; // "Electricity", "Water", "Gas", "Internet", "Mobile", "Newspaper", "Rent", "Domestic Help"
  final String providerName;
  final double amount;
  final DateTime dueDate;
  final String status; // "paid", "unpaid"
  final String period; // "Monthly - Sep 2026"
  final String frequency; // 'Monthly', 'Quarterly', 'Semi-Annual', 'Annual', 'Weekly', 'Bi-Weekly', 'Daily', 'One-Time'
  final String? paidBy;
  final List<ExpenseSplit> splits;
  final String? notes;

  HouseholdExpense({
    required this.id,
    required this.category,
    required this.providerName,
    required this.amount,
    required this.dueDate,
    required this.status,
    required this.period,
    this.frequency = 'Monthly',
    this.paidBy,
    this.splits = const [],
    this.notes,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'category': category,
        'providerName': providerName,
        'amount': amount,
        'dueDate': dueDate.toIso8601String(),
        'status': status,
        'period': period,
        'frequency': frequency,
        'paidBy': paidBy,
        'splits': splits.map((s) => s.toJson()).toList(),
        'notes': notes,
      };

  factory HouseholdExpense.fromJson(Map<String, dynamic> json) =>
      HouseholdExpense(
        id: json['id'] as String,
        category: json['category'] as String,
        providerName: json['providerName'] as String,
        amount: (json['amount'] as num).toDouble(),
        dueDate: DateTime.parse(json['dueDate'] as String),
        status: json['status'] as String,
        period: json['period'] as String,
        frequency: json['frequency'] as String? ?? 'Monthly',
        paidBy: json['paidBy'] as String?,
        splits: (json['splits'] as List<dynamic>?)
                ?.map((s) => ExpenseSplit.fromJson(s as Map<String, dynamic>))
                .toList() ??
            const [],
        notes: json['notes'] as String?,
      );

  HouseholdExpense copyWith({
    String? id,
    String? category,
    String? providerName,
    double? amount,
    DateTime? dueDate,
    String? status,
    String? period,
    String? frequency,
    String? paidBy,
    List<ExpenseSplit>? splits,
    String? notes,
  }) {
    return HouseholdExpense(
      id: id ?? this.id,
      category: category ?? this.category,
      providerName: providerName ?? this.providerName,
      amount: amount ?? this.amount,
      dueDate: dueDate ?? this.dueDate,
      status: status ?? this.status,
      period: period ?? this.period,
      frequency: frequency ?? this.frequency,
      paidBy: paidBy ?? this.paidBy,
      splits: splits ?? this.splits,
      notes: notes ?? this.notes,
    );
  }
}

class ExpenseSplit {
  final String memberName;
  final double amountOwed;
  final bool isSettled;

  ExpenseSplit({
    required this.memberName,
    required this.amountOwed,
    this.isSettled = false,
  });

  Map<String, dynamic> toJson() => {
        'memberName': memberName,
        'amountOwed': amountOwed,
        'isSettled': isSettled,
      };

  factory ExpenseSplit.fromJson(Map<String, dynamic> json) => ExpenseSplit(
        memberName: json['memberName'] as String,
        amountOwed: (json['amountOwed'] as num).toDouble(),
        isSettled: json['isSettled'] as bool? ?? false,
      );
}

class HouseholdBudget {
  final String id;
  final String category;
  final double monthlyLimit;
  final double actualSpent;

  HouseholdBudget({
    required this.id,
    required this.category,
    required this.monthlyLimit,
    this.actualSpent = 0.0,
  });

  double get remaining => (monthlyLimit - actualSpent).clamp(0.0, double.infinity);
  double get percentageUsed => monthlyLimit > 0 ? (actualSpent / monthlyLimit).clamp(0.0, 1.0) : 0.0;
  bool get isOverBudget => actualSpent > monthlyLimit;

  Map<String, dynamic> toJson() => {
        'id': id,
        'category': category,
        'monthlyLimit': monthlyLimit,
        'actualSpent': actualSpent,
      };

  factory HouseholdBudget.fromJson(Map<String, dynamic> json) => HouseholdBudget(
        id: json['id'] as String,
        category: json['category'] as String,
        monthlyLimit: (json['monthlyLimit'] as num).toDouble(),
        actualSpent: (json['actualSpent'] as num?)?.toDouble() ?? 0.0,
      );
}

class ShoppingItem {
  final String id;
  final String title;
  final String category; // "Groceries", "Household Supplies", "Repairs", "Kids"
  final bool isCompleted;
  final String? addedBy;
  final DateTime createdAt;

  ShoppingItem({
    required this.id,
    required this.title,
    this.category = 'Groceries',
    this.isCompleted = false,
    this.addedBy,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'category': category,
        'isCompleted': isCompleted,
        'addedBy': addedBy,
        'createdAt': createdAt.toIso8601String(),
      };

  factory ShoppingItem.fromJson(Map<String, dynamic> json) => ShoppingItem(
        id: json['id'] as String,
        title: json['title'] as String,
        category: json['category'] as String? ?? 'Groceries',
        isCompleted: json['isCompleted'] as bool? ?? false,
        addedBy: json['addedBy'] as String?,
        createdAt: json['createdAt'] != null ? DateTime.parse(json['createdAt'] as String) : DateTime.now(),
      );
}
