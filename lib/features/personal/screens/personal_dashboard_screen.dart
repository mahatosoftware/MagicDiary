import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/utils/formatters.dart';
import '../models/personal_models.dart';

class PersonalDashboardScreen extends ConsumerWidget {
  const PersonalDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final journalsAsync = ref.watch(journalEntriesProvider);
    final goalsAsync = ref.watch(personalGoalsProvider);
    final eventsAsync = ref.watch(specialEventsProvider);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/diaries');
            }
          },
        ),
        title: const Text('Personal Life & Memory Diary'),
        actions: [
          PopupMenuButton<String>(
            tooltip: 'Add New Record',
            icon: const Icon(Icons.add_circle_outline_rounded),
            onSelected: (val) {
              if (val == 'event') _showNewEventDialog(context, ref);
              if (val == 'goal') _showNewGoalDialog(context, ref);
              if (val == 'journal') _showNewJournalDialog(context, ref);
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'event',
                child: Row(
                  children: [
                    Icon(Icons.cake_rounded, color: Colors.pink, size: 20),
                    SizedBox(width: 10),
                    Text('Add Life Event / Birthday'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'goal',
                child: Row(
                  children: [
                    Icon(Icons.flag_rounded, color: Colors.blue, size: 20),
                    SizedBox(width: 10),
                    Text('Add Personal Goal'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'journal',
                child: Row(
                  children: [
                    Icon(Icons.edit_note_rounded, color: Colors.amber, size: 20),
                    SizedBox(width: 10),
                    Text('Write Journal Entry'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddOptionsSheet(context, ref),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add to Diary'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Life Events & Birthdays Section
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    'Upcoming Birthdays & Life Events',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold, fontSize: 18),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                TextButton.icon(
                  onPressed: () => _showNewEventDialog(context, ref),
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Add Event'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            eventsAsync.when(
              data: (events) {
                if (events.isEmpty) {
                  return Card(
                    color: Colors.pink.shade50.withValues(alpha: 0.5),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(color: Colors.pink.shade100),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 20.0),
                      child: Row(
                        children: [
                          const Icon(Icons.cake_outlined, color: Colors.pink, size: 28),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Text(
                              'No upcoming birthdays or anniversaries.\nTap "Add Event" to track milestones.',
                              style: TextStyle(color: Colors.black87, fontSize: 13),
                            ),
                          ),
                          ElevatedButton(
                            onPressed: () => _showNewEventDialog(context, ref),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.pink,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            ),
                            child: const Text('Add'),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return SizedBox(
                  height: 125,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: events.length,
                    itemBuilder: (context, index) {
                      final e = events[index];
                      final daysAway = e.date.difference(DateTime.now()).inDays;
                      String timeLabel;
                      if (daysAway == 0) {
                        timeLabel = 'Today! 🎉';
                      } else if (daysAway > 0) {
                        timeLabel = 'in $daysAway days';
                      } else {
                        timeLabel = '${-daysAway}d ago';
                      }

                      IconData eventIcon = Icons.cake_rounded;
                      if (e.eventType.toLowerCase().contains('anniversary')) {
                        eventIcon = Icons.favorite_rounded;
                      } else if (e.eventType.toLowerCase().contains('milestone')) {
                        eventIcon = Icons.emoji_events_rounded;
                      }

                      return Container(
                        width: 250,
                        margin: const EdgeInsets.only(right: 12),
                        child: Card(
                          color: Colors.pink.shade50,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                            side: BorderSide(color: Colors.pink.shade100),
                          ),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(14),
                            onLongPress: () => _confirmDeleteEvent(context, ref, e),
                            child: Padding(
                              padding: const EdgeInsets.all(12.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(eventIcon, color: Colors.pink.shade700, size: 20),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Text(
                                          e.title,
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.delete_outline, size: 16, color: Colors.grey),
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(),
                                        tooltip: 'Delete Event',
                                        onPressed: () => _confirmDeleteEvent(context, ref, e),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        DateFormat('dd MMM yyyy').format(e.date),
                                        style: TextStyle(fontSize: 12, color: Colors.pink.shade900, fontWeight: FontWeight.w500),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(color: Colors.pink.shade200),
                                        ),
                                        child: Text(
                                          timeLabel,
                                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.pink.shade800),
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (e.giftIdeas != null && e.giftIdeas!.isNotEmpty) ...[
                                    const SizedBox(height: 6),
                                    Text(
                                      '🎁 ${e.giftIdeas}',
                                      style: const TextStyle(fontSize: 11, color: Colors.purple, fontWeight: FontWeight.w500),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, stack) => Text('Error loading events: $err'),
            ),

            const SizedBox(height: 24),

            // 2. Personal Goals & Habits Section
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    'Personal Goals & Habits',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold, fontSize: 18),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                TextButton.icon(
                  onPressed: () => _showNewGoalDialog(context, ref),
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Add Goal'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            goalsAsync.when(
              data: (goals) {
                if (goals.isEmpty) {
                  return Card(
                    color: Colors.blue.shade50.withValues(alpha: 0.5),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(color: Colors.blue.shade100),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 20.0),
                      child: Row(
                        children: [
                          const Icon(Icons.flag_outlined, color: Colors.blue, size: 28),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Text(
                              'No active personal goals.\nTrack fitness, savings, career, or reading targets.',
                              style: TextStyle(color: Colors.black87, fontSize: 13),
                            ),
                          ),
                          ElevatedButton(
                            onPressed: () => _showNewGoalDialog(context, ref),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            ),
                            child: const Text('Add Goal'),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return Column(
                  children: goals.map((g) {
                    final pct = (g.progressPercentage * 100).toInt();
                    final isDone = g.isCompleted || g.progressPercentage >= 1.0;

                    Color catColor = Colors.blue;
                    if (g.category.toLowerCase().contains('health')) catColor = Colors.green;
                    if (g.category.toLowerCase().contains('finance')) catColor = Colors.teal;
                    if (g.category.toLowerCase().contains('career')) catColor = Colors.indigo;
                    if (g.category.toLowerCase().contains('travel')) catColor = Colors.orange;

                    return Card(
                      elevation: 0,
                      margin: const EdgeInsets.only(bottom: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                        side: BorderSide(color: isDone ? Colors.green.shade200 : Colors.grey.shade300),
                      ),
                      color: isDone ? Colors.green.shade50.withValues(alpha: 0.4) : Colors.white,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: () => _showUpdateGoalDialog(context, ref, g),
                        child: Padding(
                          padding: const EdgeInsets.all(14.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: catColor.withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      g.category,
                                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: catColor),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      g.title,
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15,
                                        decoration: isDone ? TextDecoration.lineThrough : null,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  Text(
                                    isDone ? 'Completed ✓' : '$pct%',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                      color: isDone ? Colors.green.shade800 : Colors.blue.shade800,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              LinearProgressIndicator(
                                value: g.progressPercentage.clamp(0.0, 1.0),
                                backgroundColor: Colors.grey.shade200,
                                color: isDone ? Colors.green : Colors.blue,
                                minHeight: 7,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              const SizedBox(height: 6),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Target: ${DateFormat('dd MMM yyyy').format(g.targetDate)}',
                                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                                  ),
                                  const Text(
                                    'Tap to update progress',
                                    style: TextStyle(fontSize: 11, color: Colors.blueGrey, fontStyle: FontStyle.italic),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, stack) => Text('Error loading goals: $err'),
            ),

            const SizedBox(height: 24),

            // 3. Daily Journal & Reflections Section
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    'Daily Journal & Reflections',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold, fontSize: 18),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                TextButton.icon(
                  onPressed: () => _showNewJournalDialog(context, ref),
                  icon: const Icon(Icons.edit_note, size: 18),
                  label: const Text('Write Entry'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            journalsAsync.when(
              data: (journals) {
                if (journals.isEmpty) {
                  return Card(
                    color: Colors.amber.shade50.withValues(alpha: 0.5),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(color: Colors.amber.shade200),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 20.0),
                      child: Row(
                        children: [
                          const Icon(Icons.menu_book_rounded, color: Colors.amber, size: 28),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Text(
                              'No journal entries written yet.\nCapture daily thoughts, feelings & gratitude.',
                              style: TextStyle(color: Colors.black87, fontSize: 13),
                            ),
                          ),
                          ElevatedButton(
                            onPressed: () => _showNewJournalDialog(context, ref),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.amber.shade800,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            ),
                            child: const Text('Write'),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return Column(
                  children: journals.map((j) {
                    return Card(
                      elevation: 0,
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                        side: BorderSide(color: Colors.grey.shade300),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    j.title,
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.amber.shade100,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(j.mood, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                ),
                                const SizedBox(width: 6),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline, size: 16, color: Colors.grey),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                  tooltip: 'Delete Journal',
                                  onPressed: () => _confirmDeleteJournal(context, ref, j),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              AppFormatters.date(j.date),
                              style: const TextStyle(fontSize: 12, color: Colors.grey),
                            ),
                            const SizedBox(height: 8),
                            Text(j.content),
                            if (j.gratitudeNote != null && j.gratitudeNote!.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: Colors.lightGreen.shade50,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  '✨ Gratitude: ${j.gratitudeNote}',
                                  style: TextStyle(color: Colors.green.shade900, fontSize: 12, fontStyle: FontStyle.italic),
                                ),
                              ),
                            ]
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, stack) => Text('Error loading journals: $err'),
            ),

            const SizedBox(height: 60),
          ],
        ),
      ),
    );
  }

  // --- Add Options Bottom Sheet ---

  void _showAddOptionsSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Add to Personal Diary', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            const SizedBox(height: 16),
            ListTile(
              leading: const CircleAvatar(backgroundColor: Color(0xFFFCE4EC), child: Icon(Icons.cake_rounded, color: Colors.pink)),
              title: const Text('Add Birthday / Life Event', style: TextStyle(fontWeight: FontWeight.bold)),
              subtitle: const Text('Track birthdays, anniversaries, graduations & milestones'),
              onTap: () {
                Navigator.pop(ctx);
                _showNewEventDialog(context, ref);
              },
            ),
            const Divider(),
            ListTile(
              leading: const CircleAvatar(backgroundColor: Color(0xFFE3F2FD), child: Icon(Icons.flag_rounded, color: Colors.blue)),
              title: const Text('Add Personal Goal', style: TextStyle(fontWeight: FontWeight.bold)),
              subtitle: const Text('Set targets for fitness, savings, reading, or career'),
              onTap: () {
                Navigator.pop(ctx);
                _showNewGoalDialog(context, ref);
              },
            ),
            const Divider(),
            ListTile(
              leading: const CircleAvatar(backgroundColor: Color(0xFFFFF8E1), child: Icon(Icons.edit_note_rounded, color: Colors.amber)),
              title: const Text('Write Daily Journal Entry', style: TextStyle(fontWeight: FontWeight.bold)),
              subtitle: const Text('Log your thoughts, moods, reflections & gratitude'),
              onTap: () {
                Navigator.pop(ctx);
                _showNewJournalDialog(context, ref);
              },
            ),
          ],
        ),
      ),
    );
  }

  // --- Life Events Dialog ---

  void _showNewEventDialog(BuildContext context, WidgetRef ref) {
    final titleController = TextEditingController();
    final giftController = TextEditingController();
    DateTime selectedDate = DateTime.now().add(const Duration(days: 7));
    String selectedType = 'Birthday';

    final types = ['Birthday', 'Anniversary', 'Milestone', 'Holiday', 'Celebration'];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
            top: 20,
            left: 20,
            right: 20,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('New Life Event 🎂', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                    IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                  ],
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: titleController,
                  decoration: const InputDecoration(
                    labelText: 'Event Title (e.g. Mom\'s Birthday, Wedding Anniversary)',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.cake_outlined),
                  ),
                ),
                const SizedBox(height: 14),
                const Text('Event Type', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                const SizedBox(height: 6),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: types.map((type) {
                      final isSelected = selectedType == type;
                      return Padding(
                        padding: const EdgeInsets.only(right: 6.0),
                        child: ChoiceChip(
                          label: Text(type),
                          selected: isSelected,
                          selectedColor: Colors.pink.shade100,
                          onSelected: (val) {
                            if (val) setModalState(() => selectedType = type);
                          },
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 14),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.calendar_month_rounded, color: Colors.pink),
                  title: const Text('Event Date', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  subtitle: Text(DateFormat('dd MMMM yyyy').format(selectedDate)),
                  trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: ctx,
                      initialDate: selectedDate,
                      firstDate: DateTime(1900),
                      lastDate: DateTime(2100),
                    );
                    if (picked != null) {
                      setModalState(() => selectedDate = picked);
                    }
                  },
                ),
                const Divider(),
                TextField(
                  controller: giftController,
                  decoration: const InputDecoration(
                    labelText: 'Gift Ideas / Celebration Notes (Optional)',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.card_giftcard_rounded),
                  ),
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.save_rounded),
                    label: const Text('Save Event', style: TextStyle(fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.pink,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: () {
                      if (titleController.text.trim().isEmpty) return;
                      final user = ref.read(userProfileProvider);
                      if (user == null) return;
                      final repo = ref.read(personalRepositoryProvider);

                      repo.addEvent(
                        user.uid,
                        SpecialEvent(
                          id: DateTime.now().millisecondsSinceEpoch.toString(),
                          title: titleController.text.trim(),
                          eventType: selectedType,
                          date: selectedDate,
                          giftIdeas: giftController.text.trim().isNotEmpty ? giftController.text.trim() : null,
                        ),
                      );
                      ref.invalidate(specialEventsProvider);
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Life event "${titleController.text.trim()}" added!')),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _confirmDeleteEvent(BuildContext context, WidgetRef ref, SpecialEvent event) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Event?'),
        content: Text('Are you sure you want to delete "${event.title}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () {
              final user = ref.read(userProfileProvider);
              if (user != null) {
                final repo = ref.read(personalRepositoryProvider);
                repo.deleteEvent(user.uid, event.id);
                ref.invalidate(specialEventsProvider);
              }
              Navigator.pop(ctx);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  // --- Personal Goals Dialogs ---

  void _showNewGoalDialog(BuildContext context, WidgetRef ref) {
    final titleController = TextEditingController();
    DateTime targetDate = DateTime.now().add(const Duration(days: 90));
    String selectedCategory = 'Personal Growth';
    double progress = 0.0;

    final categories = ['Health & Fitness', 'Career & Study', 'Finance', 'Travel', 'Personal Growth', 'Habit'];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
            top: 20,
            left: 20,
            right: 20,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('New Personal Goal 🎯', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                    IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                  ],
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: titleController,
                  decoration: const InputDecoration(
                    labelText: 'Goal Title (e.g. Run 5km weekly, Save ₹50,000)',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.flag_rounded),
                  ),
                ),
                const SizedBox(height: 14),
                const Text('Category', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                const SizedBox(height: 6),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: categories.map((cat) {
                      final isSelected = selectedCategory == cat;
                      return Padding(
                        padding: const EdgeInsets.only(right: 6.0),
                        child: ChoiceChip(
                          label: Text(cat),
                          selected: isSelected,
                          selectedColor: Colors.blue.shade100,
                          onSelected: (val) {
                            if (val) setModalState(() => selectedCategory = cat);
                          },
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 14),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.event_available_rounded, color: Colors.blue),
                  title: const Text('Target Completion Date', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  subtitle: Text(DateFormat('dd MMMM yyyy').format(targetDate)),
                  trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: ctx,
                      initialDate: targetDate,
                      firstDate: DateTime.now(),
                      lastDate: DateTime(2100),
                    );
                    if (picked != null) {
                      setModalState(() => targetDate = picked);
                    }
                  },
                ),
                const Divider(),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Starting Progress', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    Text('${(progress * 100).toInt()}%', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
                  ],
                ),
                Slider(
                  value: progress,
                  min: 0.0,
                  max: 1.0,
                  divisions: 20,
                  label: '${(progress * 100).toInt()}%',
                  onChanged: (val) => setModalState(() => progress = val),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.save_rounded),
                    label: const Text('Save Goal', style: TextStyle(fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: () {
                      if (titleController.text.trim().isEmpty) return;
                      final user = ref.read(userProfileProvider);
                      if (user == null) return;
                      final repo = ref.read(personalRepositoryProvider);

                      repo.addGoal(
                        user.uid,
                        PersonalGoal(
                          id: DateTime.now().millisecondsSinceEpoch.toString(),
                          title: titleController.text.trim(),
                          category: selectedCategory,
                          targetDate: targetDate,
                          progressPercentage: progress,
                          isCompleted: progress >= 1.0,
                        ),
                      );
                      ref.invalidate(personalGoalsProvider);
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Goal "${titleController.text.trim()}" created!')),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showUpdateGoalDialog(BuildContext context, WidgetRef ref, PersonalGoal goal) {
    double currentProgress = goal.progressPercentage;
    bool isCompleted = goal.isCompleted || currentProgress >= 1.0;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      goal.title,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                    tooltip: 'Delete Goal',
                    onPressed: () {
                      final user = ref.read(userProfileProvider);
                      if (user != null) {
                        final repo = ref.read(personalRepositoryProvider);
                        repo.deleteGoal(user.uid, goal.id);
                        ref.invalidate(personalGoalsProvider);
                      }
                      Navigator.pop(ctx);
                    },
                  ),
                ],
              ),
              Text(
                'Category: ${goal.category} • Target: ${DateFormat('dd MMM yyyy').format(goal.targetDate)}',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Update Progress', style: TextStyle(fontWeight: FontWeight.bold)),
                  Text(
                    '${(currentProgress * 100).toInt()}%',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: isCompleted ? Colors.green : Colors.blue,
                    ),
                  ),
                ],
              ),
              Slider(
                value: currentProgress,
                min: 0.0,
                max: 1.0,
                divisions: 20,
                label: '${(currentProgress * 100).toInt()}%',
                activeColor: isCompleted ? Colors.green : Colors.blue,
                onChanged: (val) {
                  setModalState(() {
                    currentProgress = val;
                    isCompleted = currentProgress >= 1.0;
                  });
                },
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  OutlinedButton(
                    onPressed: () {
                      setModalState(() {
                        currentProgress = (currentProgress + 0.1).clamp(0.0, 1.0);
                        isCompleted = currentProgress >= 1.0;
                      });
                    },
                    child: const Text('+10%'),
                  ),
                  OutlinedButton(
                    onPressed: () {
                      setModalState(() {
                        currentProgress = (currentProgress + 0.25).clamp(0.0, 1.0);
                        isCompleted = currentProgress >= 1.0;
                      });
                    },
                    child: const Text('+25%'),
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () {
                      setModalState(() {
                        currentProgress = 1.0;
                        isCompleted = true;
                      });
                    },
                    child: const Text('Mark Done ✓'),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () {
                    final user = ref.read(userProfileProvider);
                    if (user != null) {
                      final repo = ref.read(personalRepositoryProvider);
                      repo.updateGoalProgress(user.uid, goal.id, currentProgress, isCompleted);
                      ref.invalidate(personalGoalsProvider);
                    }
                    Navigator.pop(ctx);
                  },
                  child: const Text('Save Progress', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- Daily Journal Dialog ---

  void _showNewJournalDialog(BuildContext context, WidgetRef ref) {
    final titleController = TextEditingController();
    final contentController = TextEditingController();
    final gratitudeController = TextEditingController();
    String selectedMood = '😌 Calm';

    final moods = ['😊 Happy', '😌 Calm', '🤩 Excited', '🤯 Stressed', '😔 Sad'];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
            top: 20,
            left: 20,
            right: 20,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Write Journal Entry 📝', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                    IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                  ],
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: titleController,
                  decoration: const InputDecoration(labelText: 'Title', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                const Text('How are you feeling today?', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                const SizedBox(height: 6),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: moods.map((m) {
                      final isSelected = selectedMood == m;
                      return Padding(
                        padding: const EdgeInsets.only(right: 6.0),
                        child: ChoiceChip(
                          label: Text(m),
                          selected: isSelected,
                          selectedColor: Colors.amber.shade200,
                          onSelected: (val) {
                            if (val) setModalState(() => selectedMood = m);
                          },
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: contentController,
                  maxLines: 3,
                  decoration: const InputDecoration(labelText: 'What\'s on your mind today?', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: gratitudeController,
                  decoration: const InputDecoration(labelText: 'Daily Gratitude Note ✨', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.amber.shade800,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () {
                      if (titleController.text.trim().isEmpty) return;
                      final user = ref.read(userProfileProvider);
                      if (user == null) return;
                      final repo = ref.read(personalRepositoryProvider);

                      repo.addJournal(
                        user.uid,
                        JournalEntry(
                          id: DateTime.now().millisecondsSinceEpoch.toString(),
                          title: titleController.text.trim(),
                          content: contentController.text.trim(),
                          date: DateTime.now(),
                          mood: selectedMood,
                          gratitudeNote: gratitudeController.text.trim().isNotEmpty ? gratitudeController.text.trim() : null,
                          tags: ['Daily'],
                        ),
                      );
                      ref.invalidate(journalEntriesProvider);
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Journal entry "${titleController.text.trim()}" saved!')),
                      );
                    },
                    child: const Text('Save Entry', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _confirmDeleteJournal(BuildContext context, WidgetRef ref, JournalEntry journal) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Journal Entry?'),
        content: Text('Are you sure you want to delete "${journal.title}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () {
              final user = ref.read(userProfileProvider);
              if (user != null) {
                final repo = ref.read(personalRepositoryProvider);
                repo.deleteJournal(user.uid, journal.id);
                ref.invalidate(journalEntriesProvider);
              }
              Navigator.pop(ctx);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
