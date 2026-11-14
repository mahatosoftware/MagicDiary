import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/diary_registry/diary_category.dart';
import '../../../core/diary_registry/diary_definition.dart';
import '../../../core/diary_registry/diary_registry.dart';
import '../../../core/diary_registry/diary_preferences_service.dart';

class DiaryCategoryDetailScreen extends ConsumerStatefulWidget {
  final String categoryId;

  const DiaryCategoryDetailScreen({
    super.key,
    required this.categoryId,
  });

  @override
  ConsumerState<DiaryCategoryDetailScreen> createState() => _DiaryCategoryDetailScreenState();
}

class _DiaryCategoryDetailScreenState extends ConsumerState<DiaryCategoryDetailScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

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

  void _showConfigurePreviewModal(BuildContext context, DiaryDefinition diary) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (modalContext, setModalState) {
            final currentPrefs = ref.watch(diaryPreferencesProvider);
            final currentActive = currentPrefs.isDiaryActive(diary.id);
            final currentFav = currentPrefs.isDiaryFavorite(diary.id);

            return DraggableScrollableSheet(
              initialChildSize: 0.75,
              minChildSize: 0.5,
              maxChildSize: 0.95,
              expand: false,
              builder: (_, scrollController) {
                return SingleChildScrollView(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 48,
                          height: 5,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade300,
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      // Header
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 28,
                            backgroundColor: diary.color.withValues(alpha: 0.15),
                            child: Icon(diary.icon, color: diary.color, size: 30),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  diary.name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: diary.defaultSharingClassification.badgeColor.withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        diary.defaultSharingClassification.label,
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: diary.defaultSharingClassification.badgeColor,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: currentActive
                                            ? Colors.green.withValues(alpha: 0.15)
                                            : Colors.grey.withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        currentActive ? 'Active' : 'Inactive',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: currentActive ? Colors.green.shade800 : Colors.grey.shade700,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: Icon(
                              currentFav ? Icons.star_rounded : Icons.star_outline_rounded,
                              color: currentFav ? Colors.amber.shade700 : Colors.grey,
                              size: 28,
                            ),
                            tooltip: currentFav ? 'Remove from favorites' : 'Add to favorites',
                            onPressed: () {
                              ref.read(diaryPreferencesProvider.notifier).toggleFavoriteDiary(diary.id);
                              setModalState(() {});
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        diary.description,
                        style: TextStyle(fontSize: 14, color: Colors.grey.shade700, height: 1.4),
                      ),
                      const Divider(height: 32),

                      // Supported Capabilities
                      const Text(
                        'Diary Capabilities',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _buildCapabilityChip('Reminders', diary.supportsReminders, Icons.alarm_rounded),
                          _buildCapabilityChip('Attachments & Bills', diary.supportsAttachments, Icons.attach_file_rounded),
                          _buildCapabilityChip('Expense Tracking', diary.supportsExpenses, Icons.payments_outlined),
                          _buildCapabilityChip('Universal Calendar', diary.supportsCalendar, Icons.calendar_today_rounded),
                        ],
                      ),

                      if (diary.suggestedFields.isNotEmpty) ...[
                        const Divider(height: 32),
                        const Text(
                          'Standard Tracked Fields',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                        const SizedBox(height: 10),
                        ...diary.suggestedFields.map(
                          (field) => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4.0),
                            child: Row(
                              children: [
                                Icon(Icons.check_circle_outline_rounded, size: 16, color: diary.color),
                                const SizedBox(width: 8),
                                Text(
                                  field.label,
                                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                                ),
                                if (field.isRequired)
                                  const Text(
                                    ' *',
                                    style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                                  ),
                                const Spacer(),
                                Text(
                                  field.type.name,
                                  style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],

                      const Divider(height: 32),
                      // Actions
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              icon: Icon(currentActive ? Icons.cancel_outlined : Icons.check_circle_outline_rounded),
                              label: Text(currentActive ? 'Deactivate' : 'Activate Diary'),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              onPressed: () {
                                ref.read(diaryPreferencesProvider.notifier).toggleActiveDiary(diary.id);
                                setModalState(() {});
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: FilledButton.icon(
                              icon: const Icon(Icons.arrow_forward_rounded),
                              label: const Text('Open Diary'),
                              style: FilledButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              onPressed: () {
                                Navigator.pop(ctx);
                                _openDiary(diary);
                              },
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildCapabilityChip(String label, bool supported, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: supported ? Colors.green.withValues(alpha: 0.1) : Colors.grey.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: supported ? Colors.green.withValues(alpha: 0.3) : Colors.grey.withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: supported ? Colors.green.shade700 : Colors.grey),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: supported ? Colors.green.shade800 : Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final category = DiaryCategory.fromId(widget.categoryId);
    final allCategoryDiaries = DiaryRegistry.getDiariesByCategory(category.type);
    final prefs = ref.watch(diaryPreferencesProvider);

    final activeInThisCategory = allCategoryDiaries.where((d) => prefs.isDiaryActive(d.id)).length;

    // Filter within category
    final displayedDiaries = _searchQuery.isEmpty
        ? allCategoryDiaries
        : allCategoryDiaries.where((d) => d.matchesQuery(_searchQuery)).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(category.name),
        actions: [
          Center(
            child: Padding(
              padding: const EdgeInsets.only(right: 16.0),
              child: Chip(
                avatar: const Icon(Icons.check_circle_rounded, size: 14, color: Colors.green),
                label: Text(
                  '$activeInThisCategory / ${allCategoryDiaries.length} Active',
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 4),
                visualDensity: VisualDensity.compact,
              ),
            ),
          ),
        ],
      ),
      body: CustomScrollView(
        slivers: [
          // 1. Category Header Banner
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Card(
                elevation: 0,
                color: category.color.withValues(alpha: 0.12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                  side: BorderSide(color: category.color.withValues(alpha: 0.25)),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 28,
                        backgroundColor: category.color,
                        child: Icon(category.icon, color: Colors.white, size: 30),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              category.name,
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              category.description,
                              style: TextStyle(fontSize: 12.5, color: Colors.grey.shade700, height: 1.3),
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              children: [
                                Text(
                                  '${allCategoryDiaries.length} Diaries Available',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w600,
                                    color: category.color,
                                  ),
                                ),
                                const Text('•', style: TextStyle(color: Colors.grey)),
                                Text(
                                  '$activeInThisCategory Activated',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.green.shade700,
                                  ),
                                ),
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

          // 2. Search Within Category
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search within ${category.name}...',
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
                onChanged: (val) => setState(() => _searchQuery = val.trim()),
              ),
            ),
          ),

          // 3. Diaries List / Empty State
          if (displayedDiaries.isEmpty)
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
                      Text(
                        'Try searching for other keywords within ${category.name}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.grey, fontSize: 13),
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
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 88),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final diary = displayedDiaries[index];
                    final isActive = prefs.isDiaryActive(diary.id);
                    final isFavorite = prefs.isDiaryFavorite(diary.id);

                    return Card(
                      elevation: 1.5,
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: isActive
                            ? BorderSide(color: Colors.green.withValues(alpha: 0.4), width: 1.5)
                            : BorderSide(color: Colors.grey.withValues(alpha: 0.15)),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Card Top Row
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                CircleAvatar(
                                  radius: 22,
                                  backgroundColor: diary.color.withValues(alpha: 0.15),
                                  child: Icon(diary.icon, color: diary.color, size: 24),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        diary.name,
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15.5),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        diary.description,
                                        style: TextStyle(fontSize: 12, color: Colors.grey.shade600, height: 1.3),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  icon: Icon(
                                    isFavorite ? Icons.star_rounded : Icons.star_outline_rounded,
                                    color: isFavorite ? Colors.amber.shade700 : Colors.grey.shade400,
                                    size: 26,
                                  ),
                                  tooltip: isFavorite ? 'Remove from favorites' : 'Add to favorites',
                                  onPressed: () => ref
                                      .read(diaryPreferencesProvider.notifier)
                                      .toggleFavoriteDiary(diary.id),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),

                            // Card Meta Tags Row
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                                  decoration: BoxDecoration(
                                    color: diary.defaultSharingClassification.badgeColor.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    diary.defaultSharingClassification.label,
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: diary.defaultSharingClassification.badgeColor,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                                  decoration: BoxDecoration(
                                    color: isActive
                                        ? Colors.green.withValues(alpha: 0.12)
                                        : Colors.grey.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    isActive ? 'Active' : 'Inactive',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: isActive ? Colors.green.shade800 : Colors.grey.shade700,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),

                            // Actions Bar: Activate / Configure / Open
                            Row(
                              children: [
                                OutlinedButton.icon(
                                  icon: Icon(
                                    isActive ? Icons.check_circle_rounded : Icons.add_circle_outline_rounded,
                                    size: 16,
                                    color: isActive ? Colors.green.shade700 : null,
                                  ),
                                  label: Text(
                                    isActive ? 'Active' : 'Activate',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: isActive ? Colors.green.shade800 : null,
                                    ),
                                  ),
                                  style: OutlinedButton.styleFrom(
                                    visualDensity: VisualDensity.compact,
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  ),
                                  onPressed: () => ref
                                      .read(diaryPreferencesProvider.notifier)
                                      .toggleActiveDiary(diary.id),
                                ),
                                const SizedBox(width: 8),
                                OutlinedButton.icon(
                                  icon: const Icon(Icons.info_outline_rounded, size: 16),
                                  label: const Text('Configure', style: TextStyle(fontSize: 12)),
                                  style: OutlinedButton.styleFrom(
                                    visualDensity: VisualDensity.compact,
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  ),
                                  onPressed: () => _showConfigurePreviewModal(context, diary),
                                ),
                                const Spacer(),
                                FilledButton.icon(
                                  icon: const Icon(Icons.arrow_forward_rounded, size: 16),
                                  label: const Text('Open', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                  style: FilledButton.styleFrom(
                                    visualDensity: VisualDensity.compact,
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  ),
                                  onPressed: () => _openDiary(diary),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                  childCount: displayedDiaries.length,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
