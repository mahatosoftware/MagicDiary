class JournalEntry {
  final String id;
  final String title;
  final String content;
  final DateTime date;
  final String mood; // "😊 Happy", "😌 Calm", "🤩 Excited", "🤯 Stressed", "😔 Sad"
  final String? gratitudeNote;
  final List<String>? photoUrls;
  final List<String> tags;

  JournalEntry({
    required this.id,
    required this.title,
    required this.content,
    required this.date,
    required this.mood,
    this.gratitudeNote,
    this.photoUrls,
    required this.tags,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'content': content,
        'date': date.toIso8601String(),
        'mood': mood,
        'gratitudeNote': gratitudeNote,
        'photoUrls': photoUrls,
        'tags': tags,
      };

  factory JournalEntry.fromJson(Map<String, dynamic> json) => JournalEntry(
        id: json['id'] as String,
        title: json['title'] as String,
        content: json['content'] as String,
        date: DateTime.parse(json['date'] as String),
        mood: json['mood'] as String,
        gratitudeNote: json['gratitudeNote'] as String?,
        photoUrls: (json['photoUrls'] as List<dynamic>?)?.map((e) => e as String).toList(),
        tags: (json['tags'] as List<dynamic>).map((e) => e as String).toList(),
      );
}

class PersonalGoal {
  final String id;
  final String title;
  final String category; // "Health", "Career", "Finance", "Travel", "Personal Growth"
  final DateTime targetDate;
  final double progressPercentage; // 0.0 to 1.0
  final bool isCompleted;

  PersonalGoal({
    required this.id,
    required this.title,
    required this.category,
    required this.targetDate,
    required this.progressPercentage,
    required this.isCompleted,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'category': category,
        'targetDate': targetDate.toIso8601String(),
        'progressPercentage': progressPercentage,
        'isCompleted': isCompleted,
      };

  factory PersonalGoal.fromJson(Map<String, dynamic> json) => PersonalGoal(
        id: json['id'] as String,
        title: json['title'] as String,
        category: json['category'] as String,
        targetDate: DateTime.parse(json['targetDate'] as String),
        progressPercentage: (json['progressPercentage'] as num).toDouble(),
        isCompleted: json['isCompleted'] as bool,
      );
}

class SpecialEvent {
  final String id;
  final String title; // "Mom's Birthday", "Wedding Anniversary"
  final String eventType; // "Birthday", "Anniversary", "Milestone"
  final DateTime date;
  final String? giftIdeas;

  SpecialEvent({
    required this.id,
    required this.title,
    required this.eventType,
    required this.date,
    this.giftIdeas,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'eventType': eventType,
        'date': date.toIso8601String(),
        'giftIdeas': giftIdeas,
      };

  factory SpecialEvent.fromJson(Map<String, dynamic> json) => SpecialEvent(
        id: json['id'] as String,
        title: json['title'] as String,
        eventType: json['eventType'] as String,
        date: DateTime.parse(json['date'] as String),
        giftIdeas: json['giftIdeas'] as String?,
      );
}
