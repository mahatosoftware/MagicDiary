class Property {
  static const List<String> taxFrequencies = [
    'Annual',
    'Semi-Annual',
    'Quarterly',
    'Monthly',
  ];

  final String id;
  final String title; // "Green Glen Apartment 302"
  final String propertyType; // "Apartment", "Villa", "Commercial", "Plot"
  final String address;
  final double purchasePrice;
  final DateTime purchaseDate;
  final double propertyTaxAmount;
  final String propertyTaxFrequency;
  final DateTime taxDueDate;
  final double? monthlyRentIncome;

  Property({
    required this.id,
    required this.title,
    required this.propertyType,
    required this.address,
    required this.purchasePrice,
    required this.purchaseDate,
    required this.propertyTaxAmount,
    this.propertyTaxFrequency = 'Annual',
    required this.taxDueDate,
    this.monthlyRentIncome,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'propertyType': propertyType,
        'address': address,
        'purchasePrice': purchasePrice,
        'purchaseDate': purchaseDate.toIso8601String(),
        'propertyTaxAmount': propertyTaxAmount,
        'propertyTaxFrequency': propertyTaxFrequency,
        'taxDueDate': taxDueDate.toIso8601String(),
        'monthlyRentIncome': monthlyRentIncome,
      };

  factory Property.fromJson(Map<String, dynamic> json) => Property(
        id: json['id'] as String,
        title: json['title'] as String,
        propertyType: json['propertyType'] as String,
        address: json['address'] as String,
        purchasePrice: (json['purchasePrice'] as num).toDouble(),
        purchaseDate: DateTime.parse(json['purchaseDate'] as String),
        propertyTaxAmount: (json['propertyTaxAmount'] as num).toDouble(),
        propertyTaxFrequency: json['propertyTaxFrequency'] as String? ?? 'Annual',
        taxDueDate: DateTime.parse(json['taxDueDate'] as String),
        monthlyRentIncome: (json['monthlyRentIncome'] as num?)?.toDouble(),
      );

  Property copyWith({
    String? id,
    String? title,
    String? propertyType,
    String? address,
    double? purchasePrice,
    DateTime? purchaseDate,
    double? propertyTaxAmount,
    String? propertyTaxFrequency,
    DateTime? taxDueDate,
    double? monthlyRentIncome,
  }) {
    return Property(
      id: id ?? this.id,
      title: title ?? this.title,
      propertyType: propertyType ?? this.propertyType,
      address: address ?? this.address,
      purchasePrice: purchasePrice ?? this.purchasePrice,
      purchaseDate: purchaseDate ?? this.purchaseDate,
      propertyTaxAmount: propertyTaxAmount ?? this.propertyTaxAmount,
      propertyTaxFrequency: propertyTaxFrequency ?? this.propertyTaxFrequency,
      taxDueDate: taxDueDate ?? this.taxDueDate,
      monthlyRentIncome: monthlyRentIncome ?? this.monthlyRentIncome,
    );
  }
}

class PropertyMaintenance {
  final String id;
  final String propertyId;
  final String title; // "Full Exterior Painting", "Kitchen Plumbing Repair"
  final String category; // "Painting", "Plumbing", "Renovation", "Society Fee"
  final double cost;
  final DateTime date;
  final String contractorName;

  PropertyMaintenance({
    required this.id,
    required this.propertyId,
    required this.title,
    required this.category,
    required this.cost,
    required this.date,
    required this.contractorName,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'propertyId': propertyId,
        'title': title,
        'category': category,
        'cost': cost,
        'date': date.toIso8601String(),
        'contractorName': contractorName,
      };

  factory PropertyMaintenance.fromJson(Map<String, dynamic> json) =>
      PropertyMaintenance(
        id: json['id'] as String,
        propertyId: json['propertyId'] as String,
        title: json['title'] as String,
        category: json['category'] as String,
        cost: (json['cost'] as num).toDouble(),
        date: DateTime.parse(json['date'] as String),
        contractorName: json['contractorName'] as String,
      );
}
