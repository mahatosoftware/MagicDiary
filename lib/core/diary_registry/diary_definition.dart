import 'package:flutter/material.dart';
import 'diary_category.dart';
import '../diary_engine/models/custom_field_definition.dart';

enum DefaultSharingClassification {
  sharedByNature,
  selectiveSharing,
  privateByDefault,
}

extension DefaultSharingClassificationX on DefaultSharingClassification {
  String get label {
    switch (this) {
      case DefaultSharingClassification.sharedByNature:
        return 'Shared by Nature';
      case DefaultSharingClassification.selectiveSharing:
        return 'Selective Sharing';
      case DefaultSharingClassification.privateByDefault:
        return 'Private by Default';
    }
  }

  Color get badgeColor {
    switch (this) {
      case DefaultSharingClassification.sharedByNature:
        return Colors.teal;
      case DefaultSharingClassification.selectiveSharing:
        return Colors.blue;
      case DefaultSharingClassification.privateByDefault:
        return Colors.purple;
    }
  }

  IconData get icon {
    switch (this) {
      case DefaultSharingClassification.sharedByNature:
        return Icons.group_outlined;
      case DefaultSharingClassification.selectiveSharing:
        return Icons.share_outlined;
      case DefaultSharingClassification.privateByDefault:
        return Icons.lock_outline_rounded;
    }
  }
}

class DiaryDefinition {
  final String id;
  final String name;
  final String description;
  final DiaryCategoryType categoryType;
  final String categoryId;
  final IconData icon;
  final Color color;
  final DefaultSharingClassification defaultSharingClassification;
  final String? dedicatedRoute;
  final bool supportsReminders;
  final bool supportsAttachments;
  final bool supportsExpenses;
  final bool supportsCalendar;
  final List<CustomFieldDefinition> suggestedFields;
  final List<String> keywords;
  final bool isCustom;
  final DateTime createdAt;

  const DiaryDefinition({
    required this.id,
    required this.name,
    required this.description,
    required this.categoryType,
    required this.categoryId,
    required this.icon,
    required this.color,
    required this.defaultSharingClassification,
    this.dedicatedRoute,
    this.supportsReminders = true,
    this.supportsAttachments = true,
    this.supportsExpenses = true,
    this.supportsCalendar = true,
    this.suggestedFields = const [],
    this.keywords = const [],
    this.isCustom = false,
    required this.createdAt,
  });

  bool get hasDedicatedRoute => dedicatedRoute != null && dedicatedRoute!.isNotEmpty;

  /// Global search matcher: searches across diary name, description,
  /// category name, category ID, and specific keywords.
  bool matchesQuery(String query) {
    final q = query.toLowerCase().trim();
    if (q.isEmpty) return true;

    if (name.toLowerCase().contains(q)) return true;
    if (description.toLowerCase().contains(q)) return true;
    if (categoryId.toLowerCase().contains(q)) return true;

    final cat = DiaryCategory.fromType(categoryType);
    if (cat.name.toLowerCase().contains(q)) return true;

    for (final kw in keywords) {
      final normalizedKw = kw.toLowerCase();
      if (normalizedKw.contains(q) || q.contains(normalizedKw)) {
        return true;
      }
    }
    return false;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'description': description,
        'categoryType': categoryType.name,
        'categoryId': categoryId,
        'colorValue': color.toARGB32(),
        'defaultSharingClassification': defaultSharingClassification.name,
        'dedicatedRoute': dedicatedRoute,
        'supportsReminders': supportsReminders,
        'supportsAttachments': supportsAttachments,
        'supportsExpenses': supportsExpenses,
        'supportsCalendar': supportsCalendar,
        'suggestedFields': suggestedFields.map((f) => f.toJson()).toList(),
        'keywords': keywords,
        'isCustom': isCustom,
        'createdAt': createdAt.toIso8601String(),
      };
}
