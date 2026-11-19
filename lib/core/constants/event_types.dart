import 'package:flutter/material.dart';

class EventCategory {
  final String id;
  final String title;
  final IconData icon;
  final List<String> types;

  const EventCategory({
    required this.id,
    required this.title,
    required this.icon,
    required this.types,
  });
}

class EventTypeRegistry {
  static const List<EventCategory> categories = [
    EventCategory(
      id: 'personal_family',
      title: '1. Personal & family',
      icon: Icons.family_restroom_rounded,
      types: [
        'Birthday',
        'Wedding Anniversary',
        'Engagement Anniversary',
        'Relationship Anniversary',
        'Naming Ceremony',
        'Graduation Anniversary',
        'Retirement Anniversary',
        'Family Reunion',
      ],
    ),
    EventCategory(
      id: 'religious_cultural',
      title: '2. Religious & cultural occasions',
      icon: Icons.temple_hindu_rounded,
      types: [
        'Festival',
        'Religious Ceremony',
        'Puja / Prayer',
        'Housewarming / Griha Pravesh',
        'Naming Ceremony (Religious)',
        'Thread Ceremony',
        'Traditional Family Function',
        'Other Cultural Occasion',
      ],
    ),
    EventCategory(
      id: 'relationships_social',
      title: '3. Relationships & social',
      icon: Icons.people_alt_rounded,
      types: [
        'Friendship Anniversary',
        'First Meeting Anniversary',
        'Special Day',
        'Reunion',
        'Family Celebration',
        'Memorial Day',
        'Remembrance Day',
      ],
    ),
    EventCategory(
      id: 'professional_education',
      title: '4. Professional & education',
      icon: Icons.school_rounded,
      types: [
        'Work Anniversary',
        'Joining Anniversary',
        'Business Anniversary',
        'Company Foundation Day',
        'School / College Anniversary',
        'Exam Date',
        'Certification Anniversary',
      ],
    ),
    EventCategory(
      id: 'property_milestones',
      title: '5. Property & important milestones',
      icon: Icons.home_work_rounded,
      types: [
        'House Purchase Anniversary',
        'Property Registration Date',
        'Vehicle Purchase Anniversary',
        'Loan Closure Anniversary',
        'Important Milestone',
        'Other Important Date',
      ],
    ),
    EventCategory(
      id: 'custom',
      title: '6. Custom',
      icon: Icons.more_horiz_rounded,
      types: [
        'Other',
      ],
    ),
  ];

  /// Flat list of all unique event types
  static List<String> get allTypes {
    final list = <String>[];
    for (final cat in categories) {
      for (final type in cat.types) {
        if (!list.contains(type)) {
          list.add(type);
        }
      }
    }
    return list;
  }

  /// Finds the category for a given event type
  static EventCategory? getCategoryForType(String type) {
    for (final cat in categories) {
      if (cat.types.contains(type)) return cat;
    }
    return null;
  }

  /// Appropriate icon for an event type
  static IconData getIconForType(String type) {
    final lower = type.toLowerCase();
    if (lower.contains('birthday') || lower.contains('birth')) {
      return Icons.cake_rounded;
    }
    if (lower.contains('wedding') || lower.contains('marriage') || lower.contains('engagement') || lower.contains('relationship')) {
      return Icons.favorite_rounded;
    }
    if (lower.contains('work') || lower.contains('business') || lower.contains('joining') || lower.contains('foundation')) {
      return Icons.business_center_rounded;
    }
    if (lower.contains('graduation') || lower.contains('school') || lower.contains('college') || lower.contains('exam') || lower.contains('certification')) {
      return Icons.school_rounded;
    }
    if (lower.contains('house') || lower.contains('property') || lower.contains('griha')) {
      return Icons.home_rounded;
    }
    if (lower.contains('vehicle')) {
      return Icons.directions_car_rounded;
    }
    if (lower.contains('loan')) {
      return Icons.account_balance_wallet_rounded;
    }
    if (lower.contains('anniversary')) {
      return Icons.favorite_border_rounded;
    }
    if (lower.contains('ceremony') || lower.contains('puja') || lower.contains('festival') || lower.contains('prayer')) {
      return Icons.celebration_rounded;
    }
    if (lower.contains('milestone')) {
      return Icons.emoji_events_rounded;
    }
    if (lower.contains('memorial') || lower.contains('remembrance')) {
      return Icons.spa_rounded;
    }
    if (lower.contains('reunion') || lower.contains('friendship') || lower.contains('meeting')) {
      return Icons.people_alt_rounded;
    }
    return Icons.event_rounded;
  }
}
