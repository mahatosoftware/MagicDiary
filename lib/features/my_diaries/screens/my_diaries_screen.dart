import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/diary_registry/diary_category.dart';
import '../../../core/diary_registry/diary_definition.dart';
import '../../../core/diary_registry/diary_registry.dart';
import '../../../core/diary_registry/diary_preferences_service.dart';
import '../../../core/providers/app_providers.dart';

class MyDiariesScreen extends ConsumerStatefulWidget {
  const MyDiariesScreen({super.key});

  @override
  ConsumerState<MyDiariesScreen> createState() => _MyDiariesScreenState();
}

class _MyDiariesScreenState extends ConsumerState<MyDiariesScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  int _viewIndex = 0; // 0 = Explore Diaries, 1 = My Active Diaries

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _openDiary(DiaryDefinition diary) {
    ref.read(diaryPreferencesProvider.notifier).recordDiaryAccessed(diary.id);
    if (diary.hasDedicatedRoute) {
      context.push(diary.dedicatedRoute!);
    } else {
      context.push('/diary-records/${diary.id}');
    }
  }

  @override
  Widget build(BuildContext context) {
    final prefs = ref.watch(diaryPreferencesProvider);
    final reminders = ref.watch(remindersProvider).value ?? const [];
    final pendingRemindersCount = reminders.where((r) => r.isPending).length;

    // Global search results across all 45 diaries
    final isSearching = _searchQuery.isNotEmpty;
    final searchResults = isSearching ? DiaryRegistry.searchDiaries(_searchQuery) : const <DiaryDefinition>[];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Explore Diaries 📔'),
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_month_rounded),
            tooltip: 'Universal Calendar',
            onPressed: () => context.push('/calendar'),
          ),
          IconButton(
            icon: const Icon(Icons.alarm_rounded),
            tooltip: 'My Reminders',
            onPressed: () => context.push('/reminders'),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showQuickAddOptions(context),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Quick Record', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: CustomScrollView(
        slivers: [
          // 1. Header Overview & Mode Switcher
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: Card(
                elevation: 0,
                color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.35),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 26,
                        backgroundColor: Theme.of(context).primaryColor,
                        child: const Icon(Icons.auto_stories_rounded, color: Colors.white, size: 26),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Personal Life OS',
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '45 Predefined Diaries Across 8 Major Categories',
                              style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.green.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    '${prefs.activeDiaryCount} Active Diaries',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.green.shade800,
                                    ),
                                  ),
                                ),
                                if (pendingRemindersCount > 0) ...[
                                  const SizedBox(width: 8),
                                  Icon(Icons.notifications_active_outlined, size: 14, color: Colors.red.shade700),
                                  const SizedBox(width: 4),
                                  Text(
                                    '$pendingRemindersCount Pending',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.red.shade700,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // 2. Global Search Bar
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search diaries (e.g. electricity, car, school, warranty)...',
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _searchQuery = '');
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                  contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                ),
                onChanged: (val) {
                  setState(() => _searchQuery = val.trim());
                  if (val.trim().isNotEmpty) {
                    ref.read(diaryPreferencesProvider.notifier).addRecentSearch(val.trim());
                  }
                },
              ),
            ),
          ),

          // 3. Conditional Content: If Searching -> Show Global Search Results
          if (isSearching)
            ..._buildSearchResultsSlivers(searchResults)
          else ...[
            // View Switcher: Explore Categories vs My Active Diaries
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
                child: SegmentedButton<int>(
                  segments: [
                    const ButtonSegment<int>(
                      value: 0,
                      icon: Icon(Icons.grid_view_rounded, size: 18),
                      label: Text('Explore Categories'),
                    ),
                    ButtonSegment<int>(
                      value: 1,
                      icon: const Icon(Icons.checklist_rounded, size: 18),
                      label: Text('My Active (${prefs.activeDiaryCount})'),
                    ),
                  ],
                  selected: {_viewIndex},
                  onSelectionChanged: (set) => setState(() => _viewIndex = set.first),
                ),
              ),
            ),

            if (_viewIndex == 0) ...[
              // Quick Access 1: Favorites Strip
              if (prefs.favoriteDiaryIds.isNotEmpty)
                _buildQuickAccessSection(
                  title: 'Favorite Diaries',
                  icon: Icons.star_rounded,
                  iconColor: Colors.amber.shade700,
                  diaryIds: prefs.favoriteDiaryIds.toList(),
                ),

              // Quick Access 2: Recently Used Strip
              if (prefs.recentDiaryIds.isNotEmpty)
                _buildQuickAccessSection(
                  title: 'Recently Used',
                  icon: Icons.history_rounded,
                  iconColor: Colors.blue.shade700,
                  diaryIds: prefs.recentDiaryIds,
                ),

              // 8 Category Cards Section Header
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Row(
                    children: [
                      const Icon(Icons.category_rounded, size: 18, color: Colors.indigo),
                      const SizedBox(width: 8),
                      Text(
                        '8 Main Diary Categories',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                      ),
                      const Spacer(),
                      Text(
                        'Tap category to view',
                        style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                ),
              ),

              // Eight Category Cards Grid (Responsive)
              _buildCategoryGrid(context, prefs),
            ] else ...[
              // View 2: My Active Diaries – Categorized Display with Expand / Collapse
              _buildActiveDiariesCategorizedView(context, prefs),
            ],
          ],

          const SliverToBoxAdapter(child: SizedBox(height: 88)),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // GLOBAL SEARCH RESULTS SLIVERS
  // ---------------------------------------------------------------------------
  List<Widget> _buildSearchResultsSlivers(List<DiaryDefinition> results) {
    if (results.isEmpty) {
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.search_off_rounded, size: 64, color: Colors.grey.shade400),
                  const SizedBox(height: 16),
                  Text(
                    'No diaries found for "$_searchQuery"',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Try searching for "bills", "electricity", "car", "warranty", "school", "health" or "tax".',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey, fontSize: 13),
                  ),
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.clear_rounded),
                    label: const Text('Clear Search'),
                    onPressed: () {
                      _searchController.clear();
                      setState(() => _searchQuery = '');
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ];
    }

    return [
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Row(
            children: [
              Text(
                'Found ${results.length} diaries for "$_searchQuery"',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              const Spacer(),
              TextButton(
                onPressed: () {
                  _searchController.clear();
                  setState(() => _searchQuery = '');
                },
                child: const Text('Clear', style: TextStyle(fontSize: 12)),
              ),
            ],
          ),
        ),
      ),
      SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        sliver: SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) {
              final diary = results[index];
              final category = DiaryCategory.fromType(diary.categoryType);
              final prefs = ref.watch(diaryPreferencesProvider);
              final isActive = prefs.isDiaryActive(diary.id);
              final isFavorite = prefs.isDiaryFavorite(diary.id);

              return Card(
                elevation: 1,
                margin: const EdgeInsets.only(bottom: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  leading: CircleAvatar(
                    backgroundColor: diary.color.withValues(alpha: 0.15),
                    child: Icon(diary.icon, color: diary.color),
                  ),
                  title: Row(
                    children: [
                      Expanded(
                        child: Text(
                          diary.name,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: category.color.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(category.icon, size: 10, color: category.color),
                            const SizedBox(width: 4),
                            Text(
                              category.name,
                              style: TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.bold,
                                color: category.color,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 4),
                      Text(
                        diary.description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: isActive ? Colors.green.withValues(alpha: 0.12) : Colors.grey.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              isActive ? 'Active' : 'Inactive',
                              style: TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.bold,
                                color: isActive ? Colors.green.shade800 : Colors.grey.shade700,
                              ),
                            ),
                          ),
                          const Spacer(),
                          IconButton(
                            icon: Icon(
                              isFavorite ? Icons.star_rounded : Icons.star_outline_rounded,
                              color: isFavorite ? Colors.amber.shade700 : Colors.grey.shade400,
                              size: 20,
                            ),
                            visualDensity: VisualDensity.compact,
                            onPressed: () => ref
                                .read(diaryPreferencesProvider.notifier)
                                .toggleFavoriteDiary(diary.id),
                          ),
                          TextButton.icon(
                            icon: const Icon(Icons.arrow_forward_rounded, size: 14),
                            label: const Text('Open', style: TextStyle(fontSize: 12)),
                            style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                            onPressed: () => _openDiary(diary),
                          ),
                        ],
                      ),
                    ],
                  ),
                  onTap: () => _openDiary(diary),
                ),
              );
            },
            childCount: results.length,
          ),
        ),
      ),
    ];
  }

  // ---------------------------------------------------------------------------
  // QUICK ACCESS STRIP (Favorites & Recently Used)
  // ---------------------------------------------------------------------------
  Widget _buildQuickAccessSection({
    required String title,
    required IconData icon,
    required Color iconColor,
    required List<String> diaryIds,
  }) {
    final validDiaries = diaryIds
        .map((id) => DiaryRegistry.getDiaryById(id))
        .whereType<DiaryDefinition>()
        .take(6)
        .toList();

    if (validDiaries.isEmpty) return const SliverToBoxAdapter(child: SizedBox.shrink());

    return SliverToBoxAdapter(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
            child: Row(
              children: [
                Icon(icon, size: 16, color: iconColor),
                const SizedBox(width: 6),
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                ),
              ],
            ),
          ),
          SizedBox(
            height: 72,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: validDiaries.length,
              itemBuilder: (context, index) {
                final diary = validDiaries[index];
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4.0),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: () => _openDiary(diary),
                    child: Container(
                      width: 160,
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Theme.of(context).cardColor,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.grey.withValues(alpha: 0.15)),
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 18,
                            backgroundColor: diary.color.withValues(alpha: 0.15),
                            child: Icon(diary.icon, color: diary.color, size: 18),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  diary.name,
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  DiaryCategory.fromType(diary.categoryType).name,
                                  style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 8 CATEGORY CARDS GRID
  // ---------------------------------------------------------------------------
  Widget _buildCategoryGrid(BuildContext context, DiaryPreferencesState prefs) {
    final width = MediaQuery.of(context).size.width;
    final int crossAxisCount = width >= 1000
        ? 4
        : width >= 650
            ? 3
            : 2;

    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      sliver: SliverGrid(
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: crossAxisCount,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 1.05,
        ),
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final category = DiaryCategory.allCategories[index];
            final totalDiaries = DiaryRegistry.getDiariesByCategory(category.type).length;
            final activeCount = prefs.getActiveCountForCategory(category);

            return Card(
              elevation: 1.5,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
                side: BorderSide(color: category.color.withValues(alpha: 0.2)),
              ),
              child: InkWell(
                borderRadius: BorderRadius.circular(18),
                onTap: () => context.push('/diaries/category/${category.id}'),
                child: Padding(
                  padding: const EdgeInsets.all(14.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 20,
                            backgroundColor: category.color.withValues(alpha: 0.15),
                            child: Icon(category.icon, color: category.color, size: 22),
                          ),
                          const Spacer(),
                          Icon(Icons.chevron_right_rounded, color: Colors.grey.shade400, size: 20),
                        ],
                      ),
                      const Spacer(),
                      Text(
                        category.name,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        category.description,
                        style: TextStyle(fontSize: 10.5, color: Colors.grey.shade600, height: 1.2),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              '$totalDiaries Diaries',
                              style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: category.color),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: activeCount > 0
                                  ? Colors.green.withValues(alpha: 0.12)
                                  : Colors.grey.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '$activeCount Active',
                              style: TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.bold,
                                color: activeCount > 0 ? Colors.green.shade800 : Colors.grey.shade700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
          childCount: DiaryCategory.allCategories.length,
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // MY ACTIVE DIARIES – CATEGORIZED DISPLAY WITH EXPAND / COLLAPSE
  // ---------------------------------------------------------------------------
  Widget _buildActiveDiariesCategorizedView(BuildContext context, DiaryPreferencesState prefs) {
    if (prefs.activeDiaryIds.isEmpty) {
      return SliverFillRemaining(
        hasScrollBody: false,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.auto_stories_outlined, size: 64, color: Colors.grey.shade400),
                const SizedBox(height: 16),
                const Text('No Active Diaries', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 8),
                const Text(
                  'Switch to "Explore Categories" to browse and activate diaries for your personal life OS.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey, fontSize: 13),
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  icon: const Icon(Icons.explore_rounded),
                  label: const Text('Explore Categories'),
                  onPressed: () => setState(() => _viewIndex = 0),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      sliver: SliverList(
        delegate: SliverChildListDelegate([
          // Expand All / Collapse All Controls
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4.0),
            child: Row(
              children: [
                Text(
                  'Active Diaries Grouped by Category',
                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Colors.grey.shade700),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () => ref.read(diaryPreferencesProvider.notifier).expandAllCategories(),
                  child: const Text('Expand All', style: TextStyle(fontSize: 11.5)),
                ),
                const Text('•', style: TextStyle(color: Colors.grey)),
                TextButton(
                  onPressed: () => ref.read(diaryPreferencesProvider.notifier).collapseAllCategories(),
                  child: const Text('Collapse All', style: TextStyle(fontSize: 11.5)),
                ),
              ],
            ),
          ),

          // Categories with their active diaries
          ...DiaryCategory.allCategories.map((category) {
            final categoryDiaries = DiaryRegistry.getDiariesByCategory(category.type);
            final activeDiaries = categoryDiaries.where((d) => prefs.isDiaryActive(d.id)).toList();

            if (activeDiaries.isEmpty) return const SizedBox.shrink();

            final isExpanded = prefs.isCategoryExpanded(category.id);

            return Card(
              elevation: 1,
              margin: const EdgeInsets.only(bottom: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: ExpansionTile(
                initiallyExpanded: isExpanded,
                key: PageStorageKey('category_${category.id}_$isExpanded'),
                leading: CircleAvatar(
                  radius: 18,
                  backgroundColor: category.color.withValues(alpha: 0.15),
                  child: Icon(category.icon, color: category.color, size: 18),
                ),
                title: Text(
                  category.name,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5),
                ),
                subtitle: Text(
                  '${activeDiaries.length} of ${categoryDiaries.length} active',
                  style: TextStyle(fontSize: 11.5, color: Colors.grey.shade600),
                ),
                onExpansionChanged: (_) =>
                    ref.read(diaryPreferencesProvider.notifier).toggleCategoryExpanded(category.id),
                children: activeDiaries.map((diary) {
                  final isFav = prefs.isDiaryFavorite(diary.id);
                  return ListTile(
                    dense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                    leading: Icon(diary.icon, color: diary.color, size: 20),
                    title: Text(diary.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5)),
                    subtitle: Text(diary.description, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11)),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: Icon(
                            isFav ? Icons.star_rounded : Icons.star_outline_rounded,
                            color: isFav ? Colors.amber.shade700 : Colors.grey.shade400,
                            size: 20,
                          ),
                          onPressed: () => ref
                              .read(diaryPreferencesProvider.notifier)
                              .toggleFavoriteDiary(diary.id),
                        ),
                        const Icon(Icons.chevron_right_rounded, size: 18, color: Colors.grey),
                      ],
                    ),
                    onTap: () => _openDiary(diary),
                  );
                }).toList(),
              ),
            );
          }),
        ]),
      ),
    );
  }

  void _showQuickAddOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Quick Add to Diary',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            const SizedBox(height: 12),
            ListTile(
              leading: const Icon(Icons.directions_car_rounded, color: Colors.blue),
              title: const Text('Add Vehicle / Service'),
              onTap: () {
                Navigator.pop(ctx);
                context.push('/vehicle/add');
              },
            ),
            ListTile(
              leading: const Icon(Icons.receipt_long_rounded, color: Colors.teal),
              title: const Text('Record Bill Payment'),
              onTap: () {
                Navigator.pop(ctx);
                context.push('/bills/record-payment');
              },
            ),
            ListTile(
              leading: const Icon(Icons.school_rounded, color: Colors.deepOrange),
              title: const Text('Add School Fee Payment'),
              onTap: () {
                Navigator.pop(ctx);
                context.push('/school-fees');
              },
            ),
            ListTile(
              leading: const Icon(Icons.verified_rounded, color: Colors.indigo),
              title: const Text('Add Warranty / Product'),
              onTap: () {
                Navigator.pop(ctx);
                context.push('/warranty/add');
              },
            ),
            ListTile(
              leading: const Icon(Icons.account_balance_wallet_rounded, color: Colors.green),
              title: const Text('Add Financial Transaction'),
              onTap: () {
                Navigator.pop(ctx);
                context.push('/finance');
              },
            ),
          ],
        ),
      ),
    );
  }
}
