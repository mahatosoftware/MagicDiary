import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../models/magic_circle_models.dart';
import '../repositories/magic_circle_repository.dart';
import '../../../core/providers/app_providers.dart';

final magicCircleRepositoryProvider = Provider<MagicCircleRepository>((ref) => MagicCircleRepository());

final userCirclesStreamProvider = StreamProvider<List<MagicCircle>>((ref) {
  final user = ref.watch(userProfileProvider);
  if (user == null) return const Stream.empty();
  final repo = ref.read(magicCircleRepositoryProvider);
  return repo.watchUserCircles(user.uid);
});

class MagicCirclesScreen extends ConsumerStatefulWidget {
  const MagicCirclesScreen({super.key});

  @override
  ConsumerState<MagicCirclesScreen> createState() => _MagicCirclesScreenState();
}

class _MagicCirclesScreenState extends ConsumerState<MagicCirclesScreen> {
  CircleCategory? _selectedCategory;

  @override
  Widget build(BuildContext context) {
    final circlesAsync = ref.watch(userCirclesStreamProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Magic Circles ⭕'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline_rounded),
            tooltip: 'Create Circle',
            onPressed: () => context.push('/circles/create'),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/circles/create'),
        icon: const Icon(Icons.group_add_rounded),
        label: const Text('Create Circle', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: CustomScrollView(
        slivers: [
          // 1. Hero Description Card
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Card(
                elevation: 0,
                color: Colors.deepPurple.shade50,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 26,
                        backgroundColor: Colors.deepPurple.shade700,
                        child: const Icon(Icons.groups_rounded, color: Colors.white, size: 28),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Coordinate with Your Circles',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Coordinate shared diaries, responsibilities, split expenses & reminders with Family, Travel or Business groups.',
                              style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
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

          // 2. Category Filter Pills
          SliverToBoxAdapter(
            child: SizedBox(
              height: 48,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  ChoiceChip(
                    label: const Text('All Circles'),
                    selected: _selectedCategory == null,
                    onSelected: (_) => setState(() => _selectedCategory = null),
                  ),
                  const SizedBox(width: 8),
                  ...CircleCategory.values.map((cat) {
                    final isSelected = _selectedCategory == cat;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: ChoiceChip(
                        label: Text(cat.label),
                        selected: isSelected,
                        onSelected: (_) => setState(() {
                          _selectedCategory = isSelected ? null : cat;
                        }),
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 12)),

          // 3. Circles List
          circlesAsync.when(
            loading: () => const SliverFillRemaining(child: Center(child: CircularProgressIndicator())),
            error: (err, stack) => SliverFillRemaining(child: Center(child: Text('Error loading circles: $err'))),
            data: (circles) {
              var list = circles;
              if (_selectedCategory != null) {
                list = list.where((c) => c.category == _selectedCategory).toList();
              }

              if (list.isEmpty) {
                return SliverFillRemaining(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.diversity_3_rounded, size: 64, color: Colors.grey.shade400),
                          const SizedBox(height: 16),
                          const Text(
                            'No Magic Circles Yet',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Create a Family, Household, Travel or Senior Care Circle to organize responsibilities and share diaries.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                          ),
                          const SizedBox(height: 20),
                          ElevatedButton.icon(
                            onPressed: () => context.push('/circles/create'),
                            icon: const Icon(Icons.add),
                            label: const Text('Create Your First Circle'),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }

              return SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 88),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final circle = list[index];
                      return Card(
                        elevation: 1.5,
                        margin: const EdgeInsets.only(bottom: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: () {
                            context.push('/circles/${circle.id}', extra: circle);
                          },
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 22,
                                      backgroundColor: Colors.deepPurple.shade100,
                                      child: Icon(
                                        _getCircleIcon(circle.category),
                                        color: Colors.deepPurple.shade800,
                                        size: 24,
                                      ),
                                    ),
                                    const SizedBox(width: 14),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            circle.name,
                                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            circle.category.label,
                                            style: TextStyle(fontSize: 12, color: Colors.deepPurple.shade700, fontWeight: FontWeight.w500),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: Colors.grey.shade100,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(Icons.person, size: 14, color: Colors.grey),
                                          const SizedBox(width: 4),
                                          Text(
                                            '${circle.members.length}',
                                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                if (circle.description.isNotEmpty) ...[
                                  const SizedBox(height: 10),
                                  Text(
                                    circle.description,
                                    style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                                const Divider(height: 20),
                                Row(
                                  children: [
                                    Icon(Icons.auto_stories_outlined, size: 14, color: Colors.grey.shade600),
                                    const SizedBox(width: 4),
                                    Text(
                                      '${circle.sharedDiaryIds.length} Shared Diaries',
                                      style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                                    ),
                                    const Spacer(),
                                    const Text(
                                      'Open Circle',
                                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.deepPurple),
                                    ),
                                    const Icon(Icons.chevron_right, size: 18, color: Colors.deepPurple),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                    childCount: list.length,
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  IconData _getCircleIcon(CircleCategory category) {
    switch (category) {
      case CircleCategory.family:
        return Icons.family_restroom_rounded;
      case CircleCategory.household:
        return Icons.home_rounded;
      case CircleCategory.travel:
        return Icons.flight_rounded;
      case CircleCategory.business:
        return Icons.business_center_rounded;
      case CircleCategory.education:
        return Icons.school_rounded;
      case CircleCategory.seniorCare:
        return Icons.elderly_rounded;
      case CircleCategory.propertyManagement:
        return Icons.apartment_rounded;
      case CircleCategory.friends:
        return Icons.celebration_rounded;
      case CircleCategory.custom:
        return Icons.stars_rounded;
    }
  }
}
