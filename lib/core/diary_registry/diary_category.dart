import 'package:flutter/material.dart';

enum DiaryCategoryType {
  financial,
  homeAndProperty,
  vehicleAndTravel,
  familyAndEducation,
  assetsAndProtection,
  healthAndWellbeing,
  lifestyleAndOrganization,
  specialPurpose;

  // Convenient modern aliases
  static const DiaryCategoryType moneyAndFinance = DiaryCategoryType.financial;
  static const DiaryCategoryType vehiclesAndTravel = DiaryCategoryType.vehicleAndTravel;
  static const DiaryCategoryType healthAndWellness = DiaryCategoryType.healthAndWellbeing;
  static const DiaryCategoryType lifestyleAndPersonal = DiaryCategoryType.lifestyleAndOrganization;
}

class DiaryCategory {
  final DiaryCategoryType type;
  final String id;
  final String name;
  final String description;
  final IconData icon;
  final Color color;
  final int order;

  const DiaryCategory({
    required this.type,
    required this.id,
    required this.name,
    required this.description,
    required this.icon,
    required this.color,
    required this.order,
  });

  static const List<DiaryCategory> allCategories = [
    // 1. Money & Finance – 6 diaries (Icon: wallet)
    DiaryCategory(
      type: DiaryCategoryType.financial,
      id: 'financial',
      name: 'Money & Finance',
      description: 'Income, bills, loans, investments, savings & taxes',
      icon: Icons.account_balance_wallet_rounded,
      color: Colors.green,
      order: 1,
    ),
    // 2. Home & Property – 4 diaries (Icon: house)
    DiaryCategory(
      type: DiaryCategoryType.homeAndProperty,
      id: 'home_property',
      name: 'Home & Property',
      description: 'Properties, maintenance, inventory & groceries',
      icon: Icons.home_rounded,
      color: Colors.teal,
      order: 2,
    ),
    // 3. Vehicles & Travel – 3 diaries (Icon: car)
    DiaryCategory(
      type: DiaryCategoryType.vehicleAndTravel,
      id: 'vehicle_travel',
      name: 'Vehicles & Travel',
      description: 'Vehicles, trips, fuel tracking & mileage',
      icon: Icons.directions_car_rounded,
      color: Colors.blue,
      order: 3,
    ),
    // 4. Family & Education – 4 diaries (Icon: users)
    DiaryCategory(
      type: DiaryCategoryType.familyAndEducation,
      id: 'family_education',
      name: 'Family & Education',
      description: 'Family members, school, child milestones & pet care',
      icon: Icons.groups_rounded,
      color: Colors.deepOrange,
      order: 4,
    ),
    // 5. Assets & Protection – 3 diaries (Icon: shield-check)
    DiaryCategory(
      type: DiaryCategoryType.assetsAndProtection,
      id: 'assets_protection',
      name: 'Assets & Protection',
      description: 'Insurance, warranties, AMC contracts & valuables',
      icon: Icons.verified_user_rounded,
      color: Colors.indigo,
      order: 5,
    ),
    // 6. Health & Wellness – 6 diaries (Icon: heart-pulse)
    DiaryCategory(
      type: DiaryCategoryType.healthAndWellbeing,
      id: 'health_wellness',
      name: 'Health & Wellness',
      description: 'Health records, medications, fitness, meals & sleep',
      icon: Icons.monitor_heart_rounded,
      color: Colors.pink,
      order: 6,
    ),
    // 7. Lifestyle & Personal – 9 diaries (Icon: sparkles)
    DiaryCategory(
      type: DiaryCategoryType.lifestyleAndOrganization,
      id: 'lifestyle_personal',
      name: 'Lifestyle & Personal',
      description: 'Subscriptions, events, habits, career & journal',
      icon: Icons.auto_awesome_rounded,
      color: Colors.purple,
      order: 7,
    ),
    // 8. Special Purpose – 10 diaries (Icon: layers)
    DiaryCategory(
      type: DiaryCategoryType.specialPurpose,
      id: 'special_purpose',
      name: 'Special Purpose',
      description: 'Rental management, legal, donations, freelance & business',
      icon: Icons.layers_rounded,
      color: Colors.blueGrey,
      order: 8,
    ),
  ];

  static DiaryCategory fromType(DiaryCategoryType type) {
    return allCategories.firstWhere(
      (c) => c.type == type,
      orElse: () => allCategories.first,
    );
  }

  static DiaryCategory fromId(String id) {
    final normalized = id.toLowerCase().trim();
    return allCategories.firstWhere(
      (c) =>
          c.id == normalized ||
          (normalized == 'money_finance' && c.id == 'financial') ||
          (normalized == 'financial' && c.id == 'financial') ||
          (normalized == 'health_wellbeing' && c.id == 'health_wellness') ||
          (normalized == 'health_wellness' && c.id == 'health_wellness') ||
          (normalized == 'lifestyle_organization' && c.id == 'lifestyle_personal') ||
          (normalized == 'lifestyle_personal' && c.id == 'lifestyle_personal') ||
          (normalized == 'vehicles_travel' && c.id == 'vehicle_travel'),
      orElse: () => allCategories.first,
    );
  }
}
