import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/utils/formatters.dart';
import '../../reminders/models/reminder.dart';
import '../widgets/daily_dock.dart';
import '../widgets/quick_add_sheet.dart';
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

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final todayStr = AppFormatters.date(now);

    final user = ref.watch(userProfileProvider);
    final remindersAsync = ref.watch(remindersProvider);
    final allReminders = remindersAsync.value ?? const <Reminder>[];
    final searchQuery = ref.watch(searchQueryProvider);
    final searchResults = ref.watch(globalSearchResultsProvider);

    // Compute Greeting & Time Context
    final hour = now.hour;
    final String timeGreeting;
    final String timeEmoji;
    if (hour < 12) {
      timeGreeting = 'Good morning';
      timeEmoji = '☀️';
    } else if (hour < 17) {
      timeGreeting = 'Good afternoon';
      timeEmoji = '🌤️';
    } else {
      timeGreeting = 'Good evening';
      timeEmoji = '🌙';
    }

    final displayName = user?.displayName.trim();
    final firstName = (displayName != null && displayName.isNotEmpty)
        ? displayName.split(' ').first
        : null;
    final fullGreeting = (firstName != null && firstName.isNotEmpty)
        ? '$timeGreeting, $firstName $timeEmoji'
        : 'My Day $timeEmoji';

    // Compute Today's Completion Progress
    final todayDueReminders = allReminders.where((r) => r.isToday(now)).toList();
    final todayCompletedReminders = allReminders.where((r) {
      if (!r.isCompleted) return false;
      final comp = r.completedAt;
      if (comp == null) return false;
      return comp.year == now.year && comp.month == now.month && comp.day == now.day;
    }).toList();

    final todayDueCount = todayDueReminders.length;
    final todayDoneCount = todayCompletedReminders.length;
    final totalToday = todayDueCount + todayDoneCount;
    final todayProgress = totalToday > 0 ? (todayDoneCount / totalToday) : 0.0;

    // Financial Dues
    final financialDueToday = todayDueReminders.where((r) => r.isFinancial == true);
    final dueTodayAmount = financialDueToday.fold<double>(0.0, (sum, r) => sum + (r.amount ?? 0.0));

    final financialOverdue = allReminders.where((r) => r.isOverdue(now) && r.isFinancial == true);
    final overdueAmount = financialOverdue.fold<double>(0.0, (sum, r) => sum + (r.amount ?? 0.0));

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

                // 2. Greeting Header with View Toggle & Daily Progress Pulse
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
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    fullGreeting,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
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
                            ),
                            const SizedBox(width: 8),
                            // Agenda vs Calendar Toggle Button
                            SegmentedButton<bool>(
                              showSelectedIcon: false,
                              segments: const [
                                ButtonSegment(
                                  value: false,
                                  icon: Icon(Icons.view_agenda_outlined, size: 15),
                                  label: Text(
                                    'Agenda',
                                    style: TextStyle(fontSize: 11),
                                    softWrap: false,
                                  ),
                                ),
                                ButtonSegment(
                                  value: true,
                                  icon: Icon(Icons.calendar_month_outlined, size: 15),
                                  label: Text(
                                    'Calendar',
                                    style: TextStyle(fontSize: 11),
                                    softWrap: false,
                                  ),
                                ),
                              ],
                              selected: {_isCalendarMode},
                              onSelectionChanged: (val) {
                                setState(() => _isCalendarMode = val.first);
                              },
                              style: ButtonStyle(
                                visualDensity: VisualDensity.compact,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                padding: WidgetStateProperty.all(
                                  const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                                ),
                              ),
                            ),
                          ],
                        ),

                        // Today's Progress Bar (when tasks exist for today)
                        if (totalToday > 0) ...[
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                todayProgress >= 1.0
                                    ? 'All tasks completed today! 🎉'
                                    : '$todayDoneCount of $totalToday tasks completed',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.bold,
                                  color: todayProgress >= 1.0 ? Colors.green.shade800 : Colors.blue.shade900,
                                ),
                              ),
                              Text(
                                '${(todayProgress * 100).toInt()}%',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.bold,
                                  color: todayProgress >= 1.0 ? Colors.green.shade800 : Colors.blue.shade900,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: todayProgress,
                              minHeight: 5,
                              backgroundColor: Colors.blue.shade100,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                todayProgress >= 1.0 ? Colors.green.shade600 : Colors.blue.shade700,
                              ),
                            ),
                          ),
                        ],

                        // Financial Dues Summary Strip
                        if (dueTodayAmount > 0 || overdueAmount > 0) ...[
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 8,
                            runSpacing: 6,
                            children: [
                              if (dueTodayAmount > 0)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.blue.shade100.withValues(alpha: 0.7),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.payment_rounded, size: 14, color: Colors.blue),
                                      const SizedBox(width: 5),
                                      Text(
                                        '₹${AppFormatters.currency(dueTodayAmount)} due today',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.blue.shade900,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              if (overdueAmount > 0)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.red.shade100.withValues(alpha: 0.7),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.warning_amber_rounded, size: 14, color: Colors.red),
                                      const SizedBox(width: 5),
                                      Text(
                                        '₹${AppFormatters.currency(overdueAmount)} overdue',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.red.shade900,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 14),

                // 3. Fast-Action Daily Dock
                const DailyDock(),

                const SizedBox(height: 16),

                // 4. Calendar View (if active)
                remindersAsync.when(
                  data: (remindersList) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (_isCalendarMode) ...[
                          CalendarAgendaView(
                            selectedDate: _calendarDate,
                            reminders: remindersList,
                            onDateSelected: (date) {
                              setState(() => _calendarDate = date);
                            },
                          ),
                          const SizedBox(height: 14),
                        ],

                        // 7. Agenda Status Tabs (Overdue, Due Today, Due Soon, Completed)
                        if (!_isCalendarMode) _buildStatusTabs(context, remindersList, now),

                        const SizedBox(height: 12),

                        // 8. Dynamic Module Filter Chips with Count Badges
                        _buildDynamicModuleChips(remindersList, now),

                        const SizedBox(height: 14),

                        // 9. Filtered Action Tiles List
                        _buildAgendaItemsList(context, remindersList, now, todayDoneCount),
                      ],
                    );
                  },
                  loading: () => const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32.0),
                      child: CircularProgressIndicator(),
                    ),
                  ),
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
        onTap: () => setState(() {
          _selectedTab = tab;
          _selectedModule = 'All';
        }),
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

  Widget _buildDynamicModuleChips(List<Reminder> allReminders, DateTime now) {
    List<Reminder> tabReminders;
    if (_isCalendarMode) {
      tabReminders = allReminders.where((r) {
        return r.dueDate.year == _calendarDate.year &&
            r.dueDate.month == _calendarDate.month &&
            r.dueDate.day == _calendarDate.day;
      }).toList();
    } else {
      switch (_selectedTab) {
        case AgendaTab.overdue:
          tabReminders = allReminders.where((r) => r.isOverdue(now)).toList();
          break;
        case AgendaTab.today:
          tabReminders = allReminders.where((r) => r.isToday(now)).toList();
          break;
        case AgendaTab.upcoming:
          tabReminders = allReminders.where((r) => r.isUpcoming(now)).toList();
          break;
        case AgendaTab.completed:
          tabReminders = allReminders.where((r) => r.isCompleted).toList();
          break;
      }
    }

    final Map<String, int> moduleCounts = {};
    for (final r in tabReminders) {
      final mod = r.module.trim().isEmpty ? 'General' : r.module.trim();
      moduleCounts[mod] = (moduleCounts[mod] ?? 0) + 1;
    }

    // Fallback if currently selected module no longer exists in this tab
    if (_selectedModule != 'All' && !moduleCounts.containsKey(_selectedModule)) {
      _selectedModule = 'All';
    }

    final availableModules = ['All', ...moduleCounts.keys];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: availableModules.map((mod) {
          final isSelected = _selectedModule == mod;
          final count = mod == 'All' ? tabReminders.length : (moduleCounts[mod] ?? 0);
          final label = mod == 'SchoolFees' ? 'School' : mod;

          return Padding(
            padding: const EdgeInsets.only(right: 6.0),
            child: FilterChip(
              label: Text(
                count > 0 ? '$label ($count)' : label,
                style: const TextStyle(fontSize: 12),
              ),
              selected: isSelected,
              onSelected: (_) {
                setState(() => _selectedModule = mod);
              },
              visualDensity: VisualDensity.compact,
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildAgendaItemsList(
    BuildContext context,
    List<Reminder> allReminders,
    DateTime now,
    int todayDoneCount,
  ) {
    List<Reminder> filtered;

    if (_isCalendarMode) {
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

    // Sort by priority (high priority first) then due date
    filtered.sort((a, b) {
      final aHigh = a.priority.toLowerCase() == 'high';
      final bHigh = b.priority.toLowerCase() == 'high';
      if (aHigh && !bHigh) return -1;
      if (!aHigh && bHigh) return 1;
      return a.dueDate.compareTo(b.dueDate);
    });

    if (filtered.isEmpty) {
      // Special Celebration state if user cleared all tasks for today
      if (!_isCalendarMode && _selectedTab == AgendaTab.today && todayDoneCount > 0 && _selectedModule == 'All') {
        return Card(
          elevation: 0,
          color: Colors.green.shade50,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: Colors.green.shade200),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 24.0, horizontal: 20.0),
            child: Center(
              child: Column(
                children: [
                  const Icon(Icons.stars_rounded, size: 48, color: Colors.green),
                  const SizedBox(height: 10),
                  Text(
                    'All Caught Up for Today! 🎉',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.green.shade900,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'You have completed all $todayDoneCount tasks scheduled for today. Zero pending obligations remaining.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.green.shade800,
                    ),
                  ),
                  const SizedBox(height: 14),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.check_circle_outline, size: 16),
                    label: const Text('View Completed Tasks'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.green.shade900,
                      side: BorderSide(color: Colors.green.shade400),
                    ),
                    onPressed: () => setState(() => _selectedTab = AgendaTab.completed),
                  ),
                ],
              ),
            ),
          ),
        );
      }

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
