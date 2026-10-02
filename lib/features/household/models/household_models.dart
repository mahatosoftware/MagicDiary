class HouseholdExpense {
  final String id;
  final String category; // "Electricity", "Water", "Gas", "Internet", "Mobile", "Newspaper", "Rent", "Domestic Help"
  final String providerName;
  final double amount;
  final DateTime dueDate;
  final String status; // "paid", "unpaid"
  final String period; // "Monthly - Sep 2026"

  HouseholdExpense({
    required this.id,
    required this.category,
    required this.providerName,
    required this.amount,
    required this.dueDate,
    required this.status,
    required this.period,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'category': category,
        'providerName': providerName,
        'amount': amount,
        'dueDate': dueDate.toIso8601String(),
        'status': status,
        'period': period,
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
      );
}
