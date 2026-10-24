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

  HouseholdExpense({
    required this.id,
    required this.category,
    required this.providerName,
    required this.amount,
    required this.dueDate,
    required this.status,
    required this.period,
    this.frequency = 'Monthly',
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
    );
  }
}
