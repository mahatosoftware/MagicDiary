import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'diary_category.dart';
import 'diary_registry.dart';

class DiaryPreferencesState {
  final Set<String> activeDiaryIds;
  final Set<String> favoriteDiaryIds;
  final List<String> recentDiaryIds;
  final Set<String> expandedCategoryIds;
  final List<String> recentSearches;
  final bool isLoaded;

  const DiaryPreferencesState({
    required this.activeDiaryIds,
    required this.favoriteDiaryIds,
    required this.recentDiaryIds,
    required this.expandedCategoryIds,
    required this.recentSearches,
    this.isLoaded = false,
  });

  bool isDiaryActive(String diaryId) => activeDiaryIds.contains(diaryId);
  bool isDiaryFavorite(String diaryId) => favoriteDiaryIds.contains(diaryId);
  bool isCategoryExpanded(String categoryId) => expandedCategoryIds.contains(categoryId);

  int get activeDiaryCount => activeDiaryIds.length;

  int getActiveCountForCategory(DiaryCategory category) {
    final diaries = DiaryRegistry.getDiariesByCategory(category.type);
    return diaries.where((d) => activeDiaryIds.contains(d.id)).length;
  }

  DiaryPreferencesState copyWith({
    Set<String>? activeDiaryIds,
    Set<String>? favoriteDiaryIds,
    List<String>? recentDiaryIds,
    Set<String>? expandedCategoryIds,
    List<String>? recentSearches,
    bool? isLoaded,
  }) {
    return DiaryPreferencesState(
      activeDiaryIds: activeDiaryIds ?? this.activeDiaryIds,
      favoriteDiaryIds: favoriteDiaryIds ?? this.favoriteDiaryIds,
      recentDiaryIds: recentDiaryIds ?? this.recentDiaryIds,
      expandedCategoryIds: expandedCategoryIds ?? this.expandedCategoryIds,
      recentSearches: recentSearches ?? this.recentSearches,
      isLoaded: isLoaded ?? this.isLoaded,
    );
  }
}

class DiaryPreferencesNotifier extends StateNotifier<DiaryPreferencesState> {
  static const _keyActiveDiaries = 'magic_diary_active_diary_ids';
  static const _keyFavoriteDiaries = 'magic_diary_favorite_diary_ids';
  static const _keyRecentDiaries = 'magic_diary_recent_diary_ids';
  static const _keyExpandedCategories = 'magic_diary_expanded_category_ids';
  static const _keyRecentSearches = 'magic_diary_recent_searches';

  static final Set<String> defaultActiveDiaries = {
    'personal_finance',
    'bill_payment',
    'property',
    'vehicle',
    'fuel_mileage',
    'family',
    'warranty_amc',
    'health',
    'subscription',
    'personal_journal',
  };

  static final Set<String> defaultFavoriteDiaries = {
    'personal_finance',
    'bill_payment',
    'vehicle',
    'health',
  };

  static final List<String> defaultRecentDiaries = [
    'personal_finance',
    'bill_payment',
    'vehicle',
  ];

  Future<void>? _loadFuture;

  DiaryPreferencesNotifier()
      : super(DiaryPreferencesState(
          activeDiaryIds: defaultActiveDiaries,
          favoriteDiaryIds: defaultFavoriteDiaries,
          recentDiaryIds: defaultRecentDiaries,
          expandedCategoryIds: DiaryCategory.allCategories.map((c) => c.id).toSet(),
          recentSearches: const [],
          isLoaded: false,
        )) {
    loadPreferences();
  }

  Future<void> loadPreferences() {
    _loadFuture ??= _performLoad();
    return _loadFuture!;
  }

  Future<void> _performLoad() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      final savedActive = prefs.getStringList(_keyActiveDiaries);
      final savedFavorites = prefs.getStringList(_keyFavoriteDiaries);
      final savedRecents = prefs.getStringList(_keyRecentDiaries);
      final savedExpanded = prefs.getStringList(_keyExpandedCategories);
      final savedSearches = prefs.getStringList(_keyRecentSearches);

      state = state.copyWith(
        activeDiaryIds: savedActive != null ? savedActive.toSet() : defaultActiveDiaries,
        favoriteDiaryIds: savedFavorites != null ? savedFavorites.toSet() : defaultFavoriteDiaries,
        recentDiaryIds: savedRecents ?? defaultRecentDiaries,
        expandedCategoryIds: savedExpanded != null
            ? savedExpanded.toSet()
            : DiaryCategory.allCategories.map((c) => c.id).toSet(),
        recentSearches: savedSearches ?? const [],
        isLoaded: true,
      );
    } catch (_) {
      state = state.copyWith(isLoaded: true);
    }
  }

  Future<void> toggleActiveDiary(String diaryId) async {
    await loadPreferences();
    final updated = Set<String>.from(state.activeDiaryIds);
    if (updated.contains(diaryId)) {
      updated.remove(diaryId);
    } else {
      updated.add(diaryId);
    }
    state = state.copyWith(activeDiaryIds: updated);
    _persistStringList(_keyActiveDiaries, updated.toList());
  }

  Future<void> setDiaryActive(String diaryId, bool active) async {
    await loadPreferences();
    final updated = Set<String>.from(state.activeDiaryIds);
    if (active) {
      updated.add(diaryId);
    } else {
      updated.remove(diaryId);
    }
    state = state.copyWith(activeDiaryIds: updated);
    _persistStringList(_keyActiveDiaries, updated.toList());
  }

  Future<void> toggleFavoriteDiary(String diaryId) async {
    await loadPreferences();
    final updated = Set<String>.from(state.favoriteDiaryIds);
    if (updated.contains(diaryId)) {
      updated.remove(diaryId);
    } else {
      updated.add(diaryId);
    }
    state = state.copyWith(favoriteDiaryIds: updated);
    _persistStringList(_keyFavoriteDiaries, updated.toList());
  }

  Future<void> recordDiaryAccessed(String diaryId) async {
    await loadPreferences();
    final updated = List<String>.from(state.recentDiaryIds);
    updated.remove(diaryId);
    updated.insert(0, diaryId);
    if (updated.length > 8) {
      updated.removeRange(8, updated.length);
    }
    state = state.copyWith(recentDiaryIds: updated);
    _persistStringList(_keyRecentDiaries, updated);
  }

  Future<void> toggleCategoryExpanded(String categoryId) async {
    await loadPreferences();
    final updated = Set<String>.from(state.expandedCategoryIds);
    if (updated.contains(categoryId)) {
      updated.remove(categoryId);
    } else {
      updated.add(categoryId);
    }
    state = state.copyWith(expandedCategoryIds: updated);
    _persistStringList(_keyExpandedCategories, updated.toList());
  }

  Future<void> expandAllCategories() async {
    await loadPreferences();
    final allIds = DiaryCategory.allCategories.map((c) => c.id).toSet();
    state = state.copyWith(expandedCategoryIds: allIds);
    _persistStringList(_keyExpandedCategories, allIds.toList());
  }

  Future<void> collapseAllCategories() async {
    await loadPreferences();
    state = state.copyWith(expandedCategoryIds: <String>{});
    _persistStringList(_keyExpandedCategories, const []);
  }

  Future<void> addRecentSearch(String query) async {
    await loadPreferences();
    final trimmed = query.trim();
    if (trimmed.isEmpty) return;
    final updated = List<String>.from(state.recentSearches);
    updated.remove(trimmed);
    updated.insert(0, trimmed);
    if (updated.length > 6) {
      updated.removeRange(6, updated.length);
    }
    state = state.copyWith(recentSearches: updated);
    _persistStringList(_keyRecentSearches, updated);
  }

  Future<void> clearRecentSearches() async {
    await loadPreferences();
    state = state.copyWith(recentSearches: const []);
    _persistStringList(_keyRecentSearches, const []);
  }

  Future<void> _persistStringList(String key, List<String> list) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(key, list);
    } catch (_) {}
  }
}

final diaryPreferencesProvider =
    StateNotifierProvider<DiaryPreferencesNotifier, DiaryPreferencesState>((ref) {
  return DiaryPreferencesNotifier();
});
