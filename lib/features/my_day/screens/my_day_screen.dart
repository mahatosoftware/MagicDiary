import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/utils/formatters.dart';
import '../../reminders/models/reminder.dart';
import '../widgets/quick_add_sheet.dart';
import '../widgets/setup_checklist_card.dart';
import '../widgets/magic_insights_carousel.dart';
import '../widgets/reminder_action_tile.dart';
import '../widgets/calendar_agenda_view.dart';

enum AgendaTab { overdue, today, upcoming, completed }

class MyDayScreen extends ConsumerStatefulWidget {
  const MyDayScreen({super.key});

  @override
  ConsumerState<MyDayScreen> createState() => _MyDayScreenState();
}

class _MyDayScreenState extends ConsumerState<MyDayScreen> {
  final TextEditingController _searchController = TextEditingController();
  AgendaTab _selectedTab = AgendaTab.today;
  String _selectedModule = 'All';
  bool _isCalendarMode = false;
  DateTime _calendarDate = DateTime.now();

  final List<String> _moduleFilters = [
    'All',
    'Bills',
    'SchoolFees',
    'Vehicle',
    'Household',
    'Property',
    'Warranty',
    'Personal',
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final todayStr = AppFormatters.date(now);

    final remindersAsync = ref.watch(remindersProvider);
    final bills = ref.watch(billsProvider).value ?? const [];
    final journals = ref.watch(journalEntriesProvider).value ?? const [];
    final vehicles = ref.watch(vehiclesProvider).value ?? const [];
    final products = ref.watch(productsProvider).value ?? const [];
    final documents = ref.watch(documentsProvider).value ?? const [];
    final searchQuery = ref.watch(searchQueryProvider);
    final searchResults = ref.watch(globalSearchResultsProvider);

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => QuickAddSheet.show(context),
        icon: const Icon(Icons.add),
        label: const Text('Quick Add', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(remindersProvider);
          ref.invalidate(billsProvider);
          ref.invalidate(journalEntriesProvider);
          ref.invalidate(vehiclesProvider);
          ref.invalidate(productsProvider);
          ref.invalidate(documentsProvider);
          ref.invalidate(householdExpensesProvider);
        },
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16.0, 12.0, 16.0, 88.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Global Search Bar
              TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search diaries, bills, vehicles, vaults...',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _searchController.clear();
                            ref.read(searchQueryProvider.notifier).state = '';
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                ),
                onChanged: (val) {
                  ref.read(searchQueryProvider.notifier).state = val;
                },
              ),

              // If Searching: Render Live Search Results Dropdown
              if (searchQuery.isNotEmpty) ...[
                const SizedBox(height: 12),
                _buildSearchResults(context, searchResults),
              ] else ...[
                const SizedBox(height: 14),

                // 2. Greeting Header with View Toggle
                Card(
                  elevation: 0,
                  color: Colors.blue.shade50,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'My Day ☀️',
                                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.blue.shade900,
                                      ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  todayStr,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: Colors.blue.shade800,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                            // Agenda vs Calendar Toggle Button
                            SegmentedButton<bool>(
                              segments: const [
                                ButtonSegment(
                                  value: false,
                                  icon: Icon(Icons.view_agenda_outlined, size: 16),
                                  label: Text('Agenda', style: TextStyle(fontSize: 11)),
                                ),
                                ButtonSegment(
                                  value: true,
                                  icon: Icon(Icons.calendar_month_outlined, size: 16),
                                  label: Text('Calendar', style: TextStyle(fontSize: 11)),
                                ),
                              ],
                              selected: {_isCalendarMode},
                              onSelectionChanged: (val) {
                                setState(() => _isCalendarMode = val.first);
                              },
                              style: const ButtonStyle(
                                visualDensity: VisualDensity.compact,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 14),

                // 3. New User Setup Checklist
                SetupChecklistCard(
                  hasBills: bills.isNotEmpty,
                  hasDiaries: journals.isNotEmpty,
                  hasAssets: vehicles.isNotEmpty || products.isNotEmpty,
                  hasDocuments: documents.isNotEmpty,
                ),

                const SizedBox(height: 14),

                // 4. Magic Assistant Proactive Insights Carousel
                const MagicInsightsCarousel(),

                const SizedBox(height: 16),

                // 5. Calendar View (if active)
                remindersAsync.when(
                  data: (allReminders) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (_isCalendarMode) ...[
                          CalendarAgendaView(
                            selectedDate: _calendarDate,
                            reminders: allReminders,
                            onDateSelected: (date) {
                              setState(() => _calendarDate = date);
                            },
                          ),
                          const SizedBox(height: 14),
                        ],

                        // 6. Agenda Status Tabs (Overdue, Due Today, Due Soon, Completed)
                        if (!_isCalendarMode) _buildStatusTabs(context, allReminders, now),

                        const SizedBox(height: 12),

                        // 7. Module Filter Chips
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: _moduleFilters.map((mod) {
                              final isSelected = _selectedModule == mod;
                              return Padding(
                                padding: const EdgeInsets.only(right: 6.0),
                                child: FilterChip(
                                  label: Text(mod == 'SchoolFees' ? 'School' : mod, style: const TextStyle(fontSize: 12)),
                                  selected: isSelected,
                                  onSelected: (val) {
                                    setState(() => _selectedModule = mod);
                                  },
                                  visualDensity: VisualDensity.compact,
                                ),
                              );
                            }).toList(),
                          ),
                        ),

                        const SizedBox(height: 14),

                        // 8. Filtered Action Tiles List
                        _buildAgendaItemsList(context, allReminders, now),
                      ],
                    );
                  },
                  loading: () => const Center(child: Padding(
                    padding: EdgeInsets.all(32.0),
                    child: CircularProgressIndicator(),
                  )),
                  error: (err, _) => Text('Error loading schedule: $err'),
                ),

                // Extra bottom padding so FAB does not block cards
                const SizedBox(height: 80),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSearchResults(BuildContext context, List<dynamic> results) {
    if (results.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Center(
            child: Column(
              children: [
                const Icon(Icons.search_off, size: 36, color: Colors.grey),
                const SizedBox(height: 8),
                Text(
                  'No matching records found across your diaries.',
                  style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Found ${results.length} result${results.length == 1 ? "" : "s"}',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
        ),
        const SizedBox(height: 8),
        ...results.map((res) {
          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                child: Icon(res.icon, color: Theme.of(context).colorScheme.primary, size: 20),
              ),
              title: Text(res.title, style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text(res.subtitle),
              trailing: const Icon(Icons.arrow_forward_ios, size: 14),
              onTap: () => context.push(res.route),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildStatusTabs(BuildContext context, List<Reminder> reminders, DateTime now) {
    final overdueCount = reminders.where((r) => r.isOverdue(now)).length;
    final todayCount = reminders.where((r) => r.isToday(now)).length;
    final upcomingCount = reminders.where((r) => r.isUpcoming(now)).length;
    final completedCount = reminders.where((r) => r.isCompleted).length;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _buildTabPill('Overdue', overdueCount, AgendaTab.overdue, Colors.red),
          _buildTabPill('Due Today', todayCount, AgendaTab.today, Colors.blue),
          _buildTabPill('Due Soon', upcomingCount, AgendaTab.upcoming, Colors.orange),
          _buildTabPill('Completed', completedCount, AgendaTab.completed, Colors.green),
        ],
      ),
    );
  }

  Widget _buildTabPill(String label, int count, AgendaTab tab, MaterialColor color) {
    final isSelected = _selectedTab == tab;

    return Padding(
      padding: const EdgeInsets.only(right: 8.0),
      child: InkWell(
        onTap: () => setState(() => _selectedTab = tab),
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? color.shade700 : color.shade50,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isSelected ? color.shade800 : color.shade200,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: isSelected ? Colors.white : color.shade900,
                ),
              ),
              if (count > 0) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: isSelected ? Colors.white.withValues(alpha: 0.25) : color.shade100,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '$count',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: isSelected ? Colors.white : color.shade900,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAgendaItemsList(BuildContext context, List<Reminder> allReminders, DateTime now) {
    List<Reminder> filtered;

    if (_isCalendarMode) {
      // Filter for specific calendar date
      filtered = allReminders.where((r) {
        return r.dueDate.year == _calendarDate.year &&
            r.dueDate.month == _calendarDate.month &&
            r.dueDate.day == _calendarDate.day;
      }).toList();
    } else {
      switch (_selectedTab) {
        case AgendaTab.overdue:
          filtered = allReminders.where((r) => r.isOverdue(now)).toList();
          break;
        case AgendaTab.today:
          filtered = allReminders.where((r) => r.isToday(now)).toList();
          break;
        case AgendaTab.upcoming:
          filtered = allReminders.where((r) => r.isUpcoming(now)).toList();
          break;
        case AgendaTab.completed:
          filtered = allReminders.where((r) => r.isCompleted).toList();
          break;
      }
    }

    if (_selectedModule != 'All') {
      filtered = filtered.where((r) => r.module.toLowerCase() == _selectedModule.toLowerCase()).toList();
    }

    if (filtered.isEmpty) {
      String message;
      if (_isCalendarMode) {
        message = 'No reminders scheduled for ${AppFormatters.date(_calendarDate)}.';
      } else if (_selectedTab == AgendaTab.overdue) {
        message = 'Great job! You have zero overdue items. 🎉';
      } else if (_selectedTab == AgendaTab.today) {
        message = 'No tasks or payments due today. Enjoy your day! ☀️';
      } else if (_selectedTab == AgendaTab.upcoming) {
        message = 'No upcoming obligations found in this category.';
      } else {
        message = 'No completed activities yet.';
      }

      return Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.4)),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 28.0, horizontal: 20.0),
          child: Center(
            child: Column(
              children: [
                Icon(
                  _selectedTab == AgendaTab.today ? Icons.sunny : Icons.task_alt,
                  size: 38,
                  color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.6),
                ),
                const SizedBox(height: 10),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Column(
      children: filtered.map((rem) => ReminderActionTile(reminder: rem)).toList(),
    );
  }
}
