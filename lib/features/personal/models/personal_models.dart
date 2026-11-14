class JournalEntry {
  final String id;
  final String title;
  final String content;
  final DateTime date;
  final String mood; // "😊 Happy", "😌 Calm", "🤩 Excited", "🤯 Stressed", "😔 Sad"
  final String? gratitudeNote;
  final List<String>? photoUrls;
  final List<String> tags;
  final bool isPrivate; // Entry-level privacy: personal diary vs shared household
  final String? place;
  final String? person;
  final String? occasion;
  final String? audioUrl;

  JournalEntry({
    required this.id,
    required this.title,
    required this.content,
    required this.date,
    required this.mood,
    this.gratitudeNote,
    this.photoUrls,
    required this.tags,
    this.isPrivate = true,
    this.place,
    this.person,
    this.occasion,
    this.audioUrl,
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
        'isPrivate': isPrivate,
        'place': place,
        'person': person,
        'occasion': occasion,
        'audioUrl': audioUrl,
      };

  factory JournalEntry.fromJson(Map<String, dynamic> json) => JournalEntry(
        id: json['id'] as String,
        title: json['title'] as String,
        content: json['content'] as String,
        date: DateTime.parse(json['date'] as String),
        mood: json['mood'] as String,
        gratitudeNote: json['gratitudeNote'] as String?,
        photoUrls: (json['photoUrls'] as List<dynamic>?)?.map((e) => e as String).toList(),
        tags: (json['tags'] as List<dynamic>?)?.map((e) => e as String).toList() ?? [],
        isPrivate: json['isPrivate'] as bool? ?? true,
        place: json['place'] as String?,
        person: json['person'] as String?,
        occasion: json['occasion'] as String?,
        audioUrl: json['audioUrl'] as String?,
      );

  JournalEntry copyWith({
    String? id,
    String? title,
    String? content,
    DateTime? date,
    String? mood,
    String? gratitudeNote,
    List<String>? photoUrls,
    List<String>? tags,
    bool? isPrivate,
    String? place,
    String? person,
    String? occasion,
    String? audioUrl,
  }) {
    return JournalEntry(
      id: id ?? this.id,
      title: title ?? this.title,
      content: content ?? this.content,
      date: date ?? this.date,
      mood: mood ?? this.mood,
      gratitudeNote: gratitudeNote ?? this.gratitudeNote,
      photoUrls: photoUrls ?? this.photoUrls,
      tags: tags ?? this.tags,
      isPrivate: isPrivate ?? this.isPrivate,
      place: place ?? this.place,
      person: person ?? this.person,
      occasion: occasion ?? this.occasion,
      audioUrl: audioUrl ?? this.audioUrl,
    );
  }
}

class GoalMilestone {
  final String id;
  final String title;
  final DateTime? dueDate;
  final bool isCompleted;

  GoalMilestone({
    required this.id,
    required this.title,
    this.dueDate,
    this.isCompleted = false,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'dueDate': dueDate?.toIso8601String(),
        'isCompleted': isCompleted,
      };

  factory GoalMilestone.fromJson(Map<String, dynamic> json) => GoalMilestone(
        id: json['id'] as String,
        title: json['title'] as String,
        dueDate: json['dueDate'] != null ? DateTime.parse(json['dueDate'] as String) : null,
        isCompleted: json['isCompleted'] as bool? ?? false,
      );
}

class PersonalGoal {
  final String id;
  final String title;
  final String category; // "Health", "Career", "Finance", "Travel", "Personal Growth"
  final DateTime targetDate;
  final double progressPercentage; // 0.0 to 1.0
  final bool isCompleted;
  final List<GoalMilestone> milestones;
  final String? completionNotes;

  PersonalGoal({
    required this.id,
    required this.title,
    required this.category,
    required this.targetDate,
    required this.progressPercentage,
    required this.isCompleted,
    this.milestones = const [],
    this.completionNotes,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'category': category,
        'targetDate': targetDate.toIso8601String(),
        'progressPercentage': progressPercentage,
        'isCompleted': isCompleted,
        'milestones': milestones.map((m) => m.toJson()).toList(),
        'completionNotes': completionNotes,
      };

  factory PersonalGoal.fromJson(Map<String, dynamic> json) => PersonalGoal(
        id: json['id'] as String,
        title: json['title'] as String,
        category: json['category'] as String,
        targetDate: DateTime.parse(json['targetDate'] as String),
        progressPercentage: (json['progressPercentage'] as num).toDouble(),
        isCompleted: json['isCompleted'] as bool,
        milestones: (json['milestones'] as List<dynamic>?)
                ?.map((m) => GoalMilestone.fromJson(m as Map<String, dynamic>))
                .toList() ??
            const [],
        completionNotes: json['completionNotes'] as String?,
      );
}

class Habit {
  final String id;
  final String title;
  final String category; // "Health", "Mindfulness", "Productivity", "Fitness"
  final String frequency; // 'daily', 'weekdays', 'weekly'
  final int streakCount;
  final int bestStreak;
  final List<String> completedDates; // yyyy-MM-dd
  final DateTime createdAt;

  Habit({
    required this.id,
    required this.title,
    required this.category,
    this.frequency = 'daily',
    this.streakCount = 0,
    this.bestStreak = 0,
    this.completedDates = const [],
    required this.createdAt,
  });

  bool isCompletedOn(DateTime date) {
    final key = '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    return completedDates.contains(key);
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'category': category,
        'frequency': frequency,
        'streakCount': streakCount,
        'bestStreak': bestStreak,
        'completedDates': completedDates,
        'createdAt': createdAt.toIso8601String(),
      };

  factory Habit.fromJson(Map<String, dynamic> json) => Habit(
        id: json['id'] as String,
        title: json['title'] as String,
        category: json['category'] as String? ?? 'General',
        frequency: json['frequency'] as String? ?? 'daily',
        streakCount: (json['streakCount'] as num?)?.toInt() ?? 0,
        bestStreak: (json['bestStreak'] as num?)?.toInt() ?? 0,
        completedDates: (json['completedDates'] as List<dynamic>?)?.map((e) => e as String).toList() ?? [],
        createdAt: json['createdAt'] != null ? DateTime.parse(json['createdAt'] as String) : DateTime.now(),
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
