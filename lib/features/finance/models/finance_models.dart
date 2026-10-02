class FinancialTransaction {
  final String id;
  final String type; // "Income" or "Expense"
  final String category; // "Salary", "Investment", "Credit Card", "EMI", "Tax", "Subscription"
  final double amount;
  final DateTime date;
  final String description;
  final String paymentMethod; // "UPI", "Credit Card", "Bank Transfer", "Cash"

  FinancialTransaction({
    required this.id,
    required this.type,
    required this.category,
    required this.amount,
    required this.date,
    required this.description,
    required this.paymentMethod,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type,
        'category': category,
        'amount': amount,
        'date': date.toIso8601String(),
        'description': description,
        'paymentMethod': paymentMethod,
      };

  factory FinancialTransaction.fromJson(Map<String, dynamic> json) =>
      FinancialTransaction(
        id: json['id'] as String,
        type: json['type'] as String,
        category: json['category'] as String,
        amount: (json['amount'] as num).toDouble(),
        date: DateTime.parse(json['date'] as String),
        description: json['description'] as String,
        paymentMethod: json['paymentMethod'] as String,
      );
}

class InvestmentRecord {
  final String id;
  final String title; // "HDFC Fixed Deposit", "Mutual Fund SIP"
  final String type; // "FD", "SIP", "Stocks", "PPF", "Gold"
  final double investedAmount;
  final double currentAmount;
  final DateTime maturityDate;
  final String accountNumber;

  InvestmentRecord({
    required this.id,
    required this.title,
    required this.type,
    required this.investedAmount,
    required this.currentAmount,
    required this.maturityDate,
    required this.accountNumber,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'type': type,
        'investedAmount': investedAmount,
        'currentAmount': currentAmount,
        'maturityDate': maturityDate.toIso8601String(),
        'accountNumber': accountNumber,
      };

  factory InvestmentRecord.fromJson(Map<String, dynamic> json) =>
      InvestmentRecord(
        id: json['id'] as String,
        title: json['title'] as String,
        type: json['type'] as String,
        investedAmount: (json['investedAmount'] as num).toDouble(),
        currentAmount: (json['currentAmount'] as num).toDouble(),
        maturityDate: DateTime.parse(json['maturityDate'] as String),
        accountNumber: json['accountNumber'] as String,
      );
}
