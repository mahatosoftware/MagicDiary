import 'package:flutter/material.dart';
import 'financial_transaction.dart';

/// Represents a standardized financial category across all Magic Diary modules.
class FinancialCategory {
  final String id;
  final String parentCategory; // e.g. "Income", "Household", "Education", "Vehicle", "Property", "Financial", "Healthcare", "Lifestyle", "Other"
  final String displayName;
  final Set<TransactionType> permittedTypes;
  final IconData icon;
  final Color color;
  final bool isTransferOrBalanceMovement; // If true, excluded from standard Income/Expense cash flow

  const FinancialCategory({
    required this.id,
    required this.parentCategory,
    required this.displayName,
    required this.permittedTypes,
    required this.icon,
    required this.color,
    this.isTransferOrBalanceMovement = false,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'parentCategory': parentCategory,
        'displayName': displayName,
        'permittedTypes': permittedTypes.map((t) => t.toDbString()).toList(),
        'isTransferOrBalanceMovement': isTransferOrBalanceMovement,
      };
}

/// Shared Central Category Registry used by all diaries and reports.
class CategoryRegistry {
  static const Map<String, FinancialCategory> _categories = {
    // --- Income Categories ---
    'income_salary': FinancialCategory(
      id: 'income_salary',
      parentCategory: 'Income',
      displayName: 'Salary & Wages',
      permittedTypes: {TransactionType.income, TransactionType.adjustment},
      icon: Icons.work_rounded,
      color: Color(0xFF2E7D32),
    ),
    'income_business': FinancialCategory(
      id: 'income_business',
      parentCategory: 'Income',
      displayName: 'Business Income',
      permittedTypes: {TransactionType.income, TransactionType.adjustment},
      icon: Icons.storefront_rounded,
      color: Color(0xFF388E3C),
    ),
    'income_freelance': FinancialCategory(
      id: 'income_freelance',
      parentCategory: 'Income',
      displayName: 'Freelance & Consulting',
      permittedTypes: {TransactionType.income, TransactionType.adjustment},
      icon: Icons.laptop_chromebook_rounded,
      color: Color(0xFF43A047),
    ),
    'income_rental': FinancialCategory(
      id: 'income_rental',
      parentCategory: 'Income',
      displayName: 'Rental Income',
      permittedTypes: {TransactionType.income, TransactionType.adjustment},
      icon: Icons.real_estate_agent_rounded,
      color: Color(0xFF1B5E20),
    ),
    'income_interest_dividend': FinancialCategory(
      id: 'income_interest_dividend',
      parentCategory: 'Income',
      displayName: 'Interest & Dividends',
      permittedTypes: {TransactionType.income, TransactionType.adjustment},
      icon: Icons.savings_rounded,
      color: Color(0xFF00796B),
    ),
    'income_refund': FinancialCategory(
      id: 'income_refund',
      parentCategory: 'Income',
      displayName: 'Refunds & Reimbursements',
      permittedTypes: {TransactionType.income, TransactionType.refund, TransactionType.reimbursement},
      icon: Icons.receipt_long_rounded,
      color: Color(0xFF00897B),
    ),
    'income_other': FinancialCategory(
      id: 'income_other',
      parentCategory: 'Income',
      displayName: 'Other Income',
      permittedTypes: {TransactionType.income, TransactionType.adjustment},
      icon: Icons.attach_money_rounded,
      color: Color(0xFF4CAF50),
    ),

    // --- Household Categories ---
    'household_groceries': FinancialCategory(
      id: 'household_groceries',
      parentCategory: 'Household',
      displayName: 'Groceries & Supplies',
      permittedTypes: {TransactionType.expense, TransactionType.refund},
      icon: Icons.shopping_basket_rounded,
      color: Color(0xFF43A047),
    ),
    'household_electricity': FinancialCategory(
      id: 'household_electricity',
      parentCategory: 'Household',
      displayName: 'Electricity Bill',
      permittedTypes: {TransactionType.expense, TransactionType.refund},
      icon: Icons.bolt_rounded,
      color: Color(0xFFFBC02D),
    ),
    'household_water': FinancialCategory(
      id: 'household_water',
      parentCategory: 'Household',
      displayName: 'Water Bill',
      permittedTypes: {TransactionType.expense, TransactionType.refund},
      icon: Icons.water_drop_rounded,
      color: Color(0xFF0288D1),
    ),
    'household_gas': FinancialCategory(
      id: 'household_gas',
      parentCategory: 'Household',
      displayName: 'Gas & Cylinder',
      permittedTypes: {TransactionType.expense, TransactionType.refund},
      icon: Icons.local_fire_department_rounded,
      color: Color(0xFFE64A19),
    ),
    'household_internet_mobile': FinancialCategory(
      id: 'household_internet_mobile',
      parentCategory: 'Household',
      displayName: 'Internet & Mobile Bills',
      permittedTypes: {TransactionType.expense, TransactionType.refund},
      icon: Icons.wifi_rounded,
      color: Color(0xFF1976D2),
    ),
    'household_rent': FinancialCategory(
      id: 'household_rent',
      parentCategory: 'Household',
      displayName: 'House Rent',
      permittedTypes: {TransactionType.expense, TransactionType.refund},
      icon: Icons.house_rounded,
      color: Color(0xFF5D4037),
    ),
    'household_repairs': FinancialCategory(
      id: 'household_repairs',
      parentCategory: 'Household',
      displayName: 'Household Repairs',
      permittedTypes: {TransactionType.expense, TransactionType.refund},
      icon: Icons.build_rounded,
      color: Color(0xFF795548),
    ),
    'household_domestic_help': FinancialCategory(
      id: 'household_domestic_help',
      parentCategory: 'Household',
      displayName: 'Domestic Help & Cook',
      permittedTypes: {TransactionType.expense, TransactionType.refund},
      icon: Icons.clean_hands_rounded,
      color: Color(0xFF689F38),
    ),
    'household_other': FinancialCategory(
      id: 'household_other',
      parentCategory: 'Household',
      displayName: 'Other Household Expenses',
      permittedTypes: {TransactionType.expense, TransactionType.refund},
      icon: Icons.home_rounded,
      color: Color(0xFF2E7D32),
    ),

    // --- Education Categories ---
    'education_school_fees': FinancialCategory(
      id: 'education_school_fees',
      parentCategory: 'Education',
      displayName: 'School & College Fees',
      permittedTypes: {TransactionType.expense, TransactionType.refund},
      icon: Icons.school_rounded,
      color: Color(0xFF6A1B9A),
    ),
    'education_tuition': FinancialCategory(
      id: 'education_tuition',
      parentCategory: 'Education',
      displayName: 'Tuition & Coaching',
      permittedTypes: {TransactionType.expense, TransactionType.refund},
      icon: Icons.menu_book_rounded,
      color: Color(0xFF7B1FA2),
    ),
    'education_books': FinancialCategory(
      id: 'education_books',
      parentCategory: 'Education',
      displayName: 'Books & Stationery',
      permittedTypes: {TransactionType.expense, TransactionType.refund},
      icon: Icons.book_rounded,
      color: Color(0xFF8E24AA),
    ),
    'education_uniforms': FinancialCategory(
      id: 'education_uniforms',
      parentCategory: 'Education',
      displayName: 'Uniforms & Apparel',
      permittedTypes: {TransactionType.expense, TransactionType.refund},
      icon: Icons.checkroom_rounded,
      color: Color(0xFF9C27B0),
    ),
    'education_transport': FinancialCategory(
      id: 'education_transport',
      parentCategory: 'Education',
      displayName: 'School Bus & Transport',
      permittedTypes: {TransactionType.expense, TransactionType.refund},
      icon: Icons.directions_bus_rounded,
      color: Color(0xFFAB47BC),
    ),
    'education_exams': FinancialCategory(
      id: 'education_exams',
      parentCategory: 'Education',
      displayName: 'Examinations & Certifications',
      permittedTypes: {TransactionType.expense, TransactionType.refund},
      icon: Icons.assignment_rounded,
      color: Color(0xFFBA68C8),
    ),
    'education_other': FinancialCategory(
      id: 'education_other',
      parentCategory: 'Education',
      displayName: 'Other Education Expenses',
      permittedTypes: {TransactionType.expense, TransactionType.refund},
      icon: Icons.school_outlined,
      color: Color(0xFF4A148C),
    ),

    // --- Vehicle Categories ---
    'vehicle_fuel': FinancialCategory(
      id: 'vehicle_fuel',
      parentCategory: 'Vehicle',
      displayName: 'Fuel (Petrol / Diesel / EV Charge)',
      permittedTypes: {TransactionType.expense, TransactionType.refund},
      icon: Icons.local_gas_station_rounded,
      color: Color(0xFFC62828),
    ),
    'vehicle_servicing': FinancialCategory(
      id: 'vehicle_servicing',
      parentCategory: 'Vehicle',
      displayName: 'Periodic Servicing',
      permittedTypes: {TransactionType.expense, TransactionType.refund},
      icon: Icons.car_repair_rounded,
      color: Color(0xFFD32F2F),
    ),
    'vehicle_repairs': FinancialCategory(
      id: 'vehicle_repairs',
      parentCategory: 'Vehicle',
      displayName: 'Repairs & Spare Parts',
      permittedTypes: {TransactionType.expense, TransactionType.refund},
      icon: Icons.handyman_rounded,
      color: Color(0xFFE53935),
    ),
    'vehicle_insurance': FinancialCategory(
      id: 'vehicle_insurance',
      parentCategory: 'Vehicle',
      displayName: 'Vehicle Insurance Renewal',
      permittedTypes: {TransactionType.expense, TransactionType.refund},
      icon: Icons.security_rounded,
      color: Color(0xFFB71C1C),
    ),
    'vehicle_statutory_fees': FinancialCategory(
      id: 'vehicle_statutory_fees',
      parentCategory: 'Vehicle',
      displayName: 'PUC, Registration & Challans',
      permittedTypes: {TransactionType.expense, TransactionType.refund},
      icon: Icons.article_rounded,
      color: Color(0xFFEF5350),
    ),
    'vehicle_parking_tolls': FinancialCategory(
      id: 'vehicle_parking_tolls',
      parentCategory: 'Vehicle',
      displayName: 'Fastag & Parking',
      permittedTypes: {TransactionType.expense, TransactionType.refund},
      icon: Icons.toll_rounded,
      color: Color(0xFFE57373),
    ),
    'vehicle_other': FinancialCategory(
      id: 'vehicle_other',
      parentCategory: 'Vehicle',
      displayName: 'Other Vehicle Expenses',
      permittedTypes: {TransactionType.expense, TransactionType.refund},
      icon: Icons.directions_car_rounded,
      color: Color(0xFF880E4F),
    ),

    // --- Property Categories ---
    'property_tax': FinancialCategory(
      id: 'property_tax',
      parentCategory: 'Property',
      displayName: 'Property Tax',
      permittedTypes: {TransactionType.expense, TransactionType.refund},
      icon: Icons.account_balance_wallet_rounded,
      color: Color(0xFFE65100),
    ),
    'property_maintenance': FinancialCategory(
      id: 'property_maintenance',
      parentCategory: 'Property',
      displayName: 'Society Maintenance & Water',
      permittedTypes: {TransactionType.expense, TransactionType.refund},
      icon: Icons.apartment_rounded,
      color: Color(0xFFEF6C00),
    ),
    'property_repairs': FinancialCategory(
      id: 'property_repairs',
      parentCategory: 'Property',
      displayName: 'Renovations & Repairs',
      permittedTypes: {TransactionType.expense, TransactionType.refund},
      icon: Icons.format_paint_rounded,
      color: Color(0xFFF57C00),
    ),
    'property_insurance': FinancialCategory(
      id: 'property_insurance',
      parentCategory: 'Property',
      displayName: 'Home Insurance',
      permittedTypes: {TransactionType.expense, TransactionType.refund},
      icon: Icons.shield_rounded,
      color: Color(0xFFFB8C00),
    ),
    'property_other': FinancialCategory(
      id: 'property_other',
      parentCategory: 'Property',
      displayName: 'Other Property Costs',
      permittedTypes: {TransactionType.expense, TransactionType.refund},
      icon: Icons.holiday_village_rounded,
      color: Color(0xFFFF9800),
    ),

    // --- Financial Categories ---
    'financial_loan_emi': FinancialCategory(
      id: 'financial_loan_emi',
      parentCategory: 'Financial',
      displayName: 'Loan EMIs',
      permittedTypes: {TransactionType.expense, TransactionType.refund},
      icon: Icons.payments_rounded,
      color: Color(0xFF1565C0),
    ),
    'financial_insurance_premium': FinancialCategory(
      id: 'financial_insurance_premium',
      parentCategory: 'Financial',
      displayName: 'Life & Term Insurance',
      permittedTypes: {TransactionType.expense, TransactionType.refund},
      icon: Icons.health_and_safety_rounded,
      color: Color(0xFF1976D2),
    ),
    'financial_bank_charges': FinancialCategory(
      id: 'financial_bank_charges',
      parentCategory: 'Financial',
      displayName: 'Bank Fees & Charges',
      permittedTypes: {TransactionType.expense, TransactionType.refund},
      icon: Icons.credit_card_off_rounded,
      color: Color(0xFF1E88E5),
    ),
    'financial_savings_transfer': FinancialCategory(
      id: 'financial_savings_transfer',
      parentCategory: 'Financial',
      displayName: 'Savings Transfer',
      permittedTypes: {TransactionType.transfer},
      icon: Icons.account_balance_rounded,
      color: Color(0xFF0D47A1),
      isTransferOrBalanceMovement: true,
    ),
    'financial_investment_transfer': FinancialCategory(
      id: 'financial_investment_transfer',
      parentCategory: 'Financial',
      displayName: 'Investment Contribution (SIP/FD)',
      permittedTypes: {TransactionType.transfer},
      icon: Icons.trending_up_rounded,
      color: Color(0xFF004D40),
      isTransferOrBalanceMovement: true,
    ),
    'financial_other': FinancialCategory(
      id: 'financial_other',
      parentCategory: 'Financial',
      displayName: 'Other Financial Services',
      permittedTypes: {TransactionType.expense, TransactionType.transfer, TransactionType.refund},
      icon: Icons.account_balance_rounded,
      color: Color(0xFF2196F3),
    ),

    // --- Healthcare Categories ---
    'healthcare_consultations': FinancialCategory(
      id: 'healthcare_consultations',
      parentCategory: 'Healthcare',
      displayName: 'Doctor Consultations',
      permittedTypes: {TransactionType.expense, TransactionType.refund},
      icon: Icons.medical_services_rounded,
      color: Color(0xFF00838F),
    ),
    'healthcare_medicines': FinancialCategory(
      id: 'healthcare_medicines',
      parentCategory: 'Healthcare',
      displayName: 'Medicines & Pharmacy',
      permittedTypes: {TransactionType.expense, TransactionType.refund},
      icon: Icons.medication_rounded,
      color: Color(0xFF0097A7),
    ),
    'healthcare_tests': FinancialCategory(
      id: 'healthcare_tests',
      parentCategory: 'Healthcare',
      displayName: 'Lab Tests & Scans',
      permittedTypes: {TransactionType.expense, TransactionType.refund},
      icon: Icons.biotech_rounded,
      color: Color(0xFF00ACC1),
    ),
    'healthcare_insurance': FinancialCategory(
      id: 'healthcare_insurance',
      parentCategory: 'Healthcare',
      displayName: 'Health Insurance Premium',
      permittedTypes: {TransactionType.expense, TransactionType.refund},
      icon: Icons.healing_rounded,
      color: Color(0xFF006064),
    ),

    // --- Lifestyle Categories ---
    'lifestyle_shopping': FinancialCategory(
      id: 'lifestyle_shopping',
      parentCategory: 'Lifestyle',
      displayName: 'Shopping & Apparel',
      permittedTypes: {TransactionType.expense, TransactionType.refund},
      icon: Icons.shopping_bag_rounded,
      color: Color(0xFFAD1457),
    ),
    'lifestyle_dining': FinancialCategory(
      id: 'lifestyle_dining',
      parentCategory: 'Lifestyle',
      displayName: 'Dining & Restaurants',
      permittedTypes: {TransactionType.expense, TransactionType.refund},
      icon: Icons.restaurant_rounded,
      color: Color(0xFFC2185B),
    ),
    'lifestyle_entertainment': FinancialCategory(
      id: 'lifestyle_entertainment',
      parentCategory: 'Lifestyle',
      displayName: 'Entertainment & Movies',
      permittedTypes: {TransactionType.expense, TransactionType.refund},
      icon: Icons.movie_rounded,
      color: Color(0xFFD81B60),
    ),
    'lifestyle_travel': FinancialCategory(
      id: 'lifestyle_travel',
      parentCategory: 'Lifestyle',
      displayName: 'Travel & Vacations',
      permittedTypes: {TransactionType.expense, TransactionType.refund},
      icon: Icons.flight_takeoff_rounded,
      color: Color(0xFFE91E63),
    ),
    'lifestyle_subscriptions': FinancialCategory(
      id: 'lifestyle_subscriptions',
      parentCategory: 'Lifestyle',
      displayName: 'OTT & Subscriptions',
      permittedTypes: {TransactionType.expense, TransactionType.refund},
      icon: Icons.subscriptions_rounded,
      color: Color(0xFF880E4F),
    ),

    // --- Other Categories ---
    'other_miscellaneous': FinancialCategory(
      id: 'other_miscellaneous',
      parentCategory: 'Other',
      displayName: 'Miscellaneous',
      permittedTypes: {TransactionType.expense, TransactionType.income, TransactionType.refund, TransactionType.adjustment},
      icon: Icons.category_rounded,
      color: Color(0xFF455A64),
    ),
  };

  /// Retrieve a category by its unique ID, fallback to sensible default if unknown
  static FinancialCategory getCategory(String? categoryId) {
    if (categoryId != null && _categories.containsKey(categoryId)) {
      return _categories[categoryId]!;
    }
    // Attempt mapping from legacy display string if needed
    final mappedId = mapLegacyToCategoryId(categoryId ?? '');
    return _categories[mappedId] ?? _categories['other_miscellaneous']!;
  }

  /// All registered categories
  static List<FinancialCategory> getAllCategories() => _categories.values.toList();

  /// Categories filtered by parent group
  static List<FinancialCategory> getByParent(String parent) =>
      _categories.values.where((c) => c.parentCategory.toLowerCase() == parent.toLowerCase()).toList();

  /// Resolve a legacy string or module free-form text to a canonical category ID
  static String mapLegacyToCategoryId(String rawText, [String? subcategory]) {
    final lower = '$rawText ${subcategory ?? ""}'.toLowerCase().trim();

    if (lower.contains('salary')) return 'income_salary';
    if (lower.contains('freelance') || lower.contains('consulting')) return 'income_freelance';
    if (lower.contains('business')) return 'income_business';
    if (lower.contains('dividend') || lower.contains('interest')) return 'income_interest_dividend';
    if (lower.contains('refund') || lower.contains('reimbursement')) return 'income_refund';
    if (lower.contains('rent received') || lower.contains('rental income')) return 'income_rental';

    if (lower.contains('electric')) return 'household_electricity';
    if (lower.contains('water')) return 'household_water';
    if (lower.contains('gas') || lower.contains('cylinder')) return 'household_gas';
    if (lower.contains('internet') || lower.contains('broadband') || lower.contains('wifi') || lower.contains('mobile') || lower.contains('telecom')) {
      return 'household_internet_mobile';
    }
    if (lower.contains('grocer') || lower.contains('supermarket')) return 'household_groceries';
    if (lower.contains('house rent') || lower.contains('flat rent') || lower == 'rent') return 'household_rent';
    if (lower.contains('maid') || lower.contains('cook') || lower.contains('domestic help')) return 'household_domestic_help';

    if (lower.contains('school fee') || lower.contains('school fees') || lower.contains('admission')) return 'education_school_fees';
    if (lower.contains('tuition') || lower.contains('coaching')) return 'education_tuition';
    if (lower.contains('book') || lower.contains('stationery')) return 'education_books';
    if (lower.contains('uniform')) return 'education_uniforms';
    if (lower.contains('school bus') || lower.contains('school transport')) return 'education_transport';
    if (lower.contains('exam')) return 'education_exams';

    if (lower.contains('fuel') || lower.contains('petrol') || lower.contains('diesel') || lower.contains('cng')) return 'vehicle_fuel';
    if (lower.contains('vehicle service') || lower.contains('periodic service') || lower.contains('servicing')) return 'vehicle_servicing';
    if (lower.contains('tyre') || lower.contains('battery') || lower.contains('vehicle repair')) return 'vehicle_repairs';
    if (lower.contains('vehicle insurance') || lower.contains('car insurance') || lower.contains('bike insurance')) return 'vehicle_insurance';
    if (lower.contains('puc') || lower.contains('challan') || lower.contains('rto')) return 'vehicle_statutory_fees';
    if (lower.contains('fastag') || lower.contains('toll') || lower.contains('parking')) return 'vehicle_parking_tolls';

    if (lower.contains('property tax') || lower.contains('house tax') || lower.contains('municipal tax')) return 'property_tax';
    if (lower.contains('society maintenance') || lower.contains('apartment maintenance')) return 'property_maintenance';
    if (lower.contains('property repair') || lower.contains('painting') || lower.contains('plumbing')) return 'property_repairs';

    if (lower.contains('emi') || lower.contains('home loan') || lower.contains('car loan') || lower.contains('personal loan')) return 'financial_loan_emi';
    if (lower.contains('term insurance') || lower.contains('life insurance')) return 'financial_insurance_premium';
    if (lower.contains('sip') || lower.contains('mutual fund') || lower.contains('stocks') || lower.contains('fixed deposit') || lower.contains('fd')) {
      return 'financial_investment_transfer';
    }
    if (lower.contains('savings transfer') || lower.contains('account transfer')) return 'financial_savings_transfer';
    if (lower.contains('bank charge') || lower.contains('atm fee') || lower.contains('annual fee')) return 'financial_bank_charges';

    if (lower.contains('doctor') || lower.contains('consultation') || lower.contains('clinic')) return 'healthcare_consultations';
    if (lower.contains('medicine') || lower.contains('pharmacy')) return 'healthcare_medicines';
    if (lower.contains('health insurance') || lower.contains('mediclaim')) return 'healthcare_insurance';
    if (lower.contains('lab test') || lower.contains('blood test') || lower.contains('scan')) return 'healthcare_tests';

    if (lower.contains('shopping') || lower.contains('clothes') || lower.contains('mall')) return 'lifestyle_shopping';
    if (lower.contains('dining') || lower.contains('restaurant') || lower.contains('cafe') || lower.contains('food delivery') || lower.contains('zomato') || lower.contains('swiggy')) {
      return 'lifestyle_dining';
    }
    if (lower.contains('movie') || lower.contains('cinema') || lower.contains('game')) return 'lifestyle_entertainment';
    if (lower.contains('flight') || lower.contains('hotel') || lower.contains('vacation') || lower.contains('trip')) return 'lifestyle_travel';
    if (lower.contains('netflix') || lower.contains('prime') || lower.contains('spotify') || lower.contains('subscription') || lower.contains('ott')) {
      return 'lifestyle_subscriptions';
    }

    if (lower.contains('income')) return 'income_other';
    return 'other_miscellaneous';
  }
}
