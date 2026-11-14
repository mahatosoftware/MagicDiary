import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../models/calendar_event.dart';
import '../services/calendar_service.dart';
import '../../providers/app_providers.dart';

class UniversalCalendarScreen extends ConsumerStatefulWidget {
  const UniversalCalendarScreen({super.key});

  @override
  ConsumerState<UniversalCalendarScreen> createState() => _UniversalCalendarScreenState();
}

class _UniversalCalendarScreenState extends ConsumerState<UniversalCalendarScreen> {
  DateTime _selectedDate = DateTime.now();
  CalendarSourceType? _filterSource;
  String _viewMode = 'Month'; // 'Month', 'Agenda'

  @override
  Widget build(BuildContext context) {
    final reminders = ref.watch(remindersProvider).value ?? const [];
    final bills = ref.watch(billsProvider).value ?? const [];
    final feeInstallments = ref.watch(feeInstallmentsProvider).value ?? const [];
    final vehicles = ref.watch(vehiclesProvider).value ?? const [];
    final properties = ref.watch(propertiesProvider).value ?? const [];
    final products = ref.watch(productsProvider).value ?? const [];
    final specialEvents = ref.watch(specialEventsProvider).value ?? const [];
    final personalGoals = ref.watch(personalGoalsProvider).value ?? const [];
    final tasks = ref.watch(activeHouseholdTasksProvider).value ?? const [];

    final allEvents = CalendarService.aggregateEvents(
      reminders: reminders,
      bills: bills,
      feeInstallments: feeInstallments,
      vehicles: vehicles,
      properties: properties,
      products: products,
      specialEvents: specialEvents,
      personalGoals: personalGoals,
      circleTasks: tasks,
    );

    final filteredEvents = _filterSource == null
        ? allEvents
        : allEvents.where((e) => e.sourceType == _filterSource).toList();

    final selectedDayEvents = filteredEvents.where((e) => e.isSameDay(_selectedDate)).toList();

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
        title: const Text('Universal Calendar 📅'),
        actions: [
          IconButton(
            icon: Icon(_viewMode == 'Month' ? Icons.view_agenda_rounded : Icons.calendar_month_rounded),
            tooltip: _viewMode == 'Month' ? 'Switch to Agenda' : 'Switch to Month',
            onPressed: () {
              setState(() {
                _viewMode = _viewMode == 'Month' ? 'Agenda' : 'Month';
              });
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Filter Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Row(
              children: [
                FilterChip(
                  label: const Text('All Sources'),
                  selected: _filterSource == null,
                  onSelected: (_) => setState(() => _filterSource = null),
                ),
                const SizedBox(width: 8),
                FilterChip(
                  avatar: const Icon(Icons.person_rounded, size: 16),
                  label: const Text('My Diaries'),
                  selected: _filterSource == CalendarSourceType.personalDiary,
                  onSelected: (_) => setState(() => _filterSource = CalendarSourceType.personalDiary),
                ),
                const SizedBox(width: 8),
                FilterChip(
                  avatar: const Icon(Icons.groups_rounded, size: 16),
                  label: const Text('Magic Circles'),
                  selected: _filterSource == CalendarSourceType.circleDiary,
                  onSelected: (_) => setState(() => _filterSource = CalendarSourceType.circleDiary),
                ),
                const SizedBox(width: 8),
                FilterChip(
                  avatar: const Icon(Icons.alarm_rounded, size: 16),
                  label: const Text('Reminders'),
                  selected: _filterSource == CalendarSourceType.systemReminder,
                  onSelected: (_) => setState(() => _filterSource = CalendarSourceType.systemReminder),
                ),
              ],
            ),
          ),

          // Date Selector Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left),
                  onPressed: () {
                    setState(() {
                      _selectedDate = _selectedDate.subtract(const Duration(days: 1));
                    });
                  },
                ),
                InkWell(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _selectedDate,
                      firstDate: DateTime(1900),
                      lastDate: DateTime(2200),
                    );
                    if (picked != null) {
                      setState(() => _selectedDate = picked);
                    }
                  },
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_today, size: 16, color: Colors.blueAccent),
                      const SizedBox(width: 8),
                      Text(
                        DateFormat('EEE, d MMMM yyyy').format(_selectedDate),
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right),
                  onPressed: () {
                    setState(() {
                      _selectedDate = _selectedDate.add(const Duration(days: 1));
                    });
                  },
                ),
              ],
            ),
          ),

          // Events List
          Expanded(
            child: selectedDayEvents.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.event_available_rounded, size: 64, color: Colors.grey.shade400),
                        const SizedBox(height: 12),
                        Text(
                          'No events or deadlines for ${DateFormat('d MMM yyyy').format(_selectedDate)}',
                          style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    itemCount: selectedDayEvents.length,
                    itemBuilder: (context, index) {
                      final event = selectedDayEvents[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: event.color.withValues(alpha: 0.15),
                            child: Icon(
                              event.sourceType == CalendarSourceType.circleDiary
                                  ? Icons.groups_rounded
                                  : Icons.event_rounded,
                              color: event.color,
                            ),
                          ),
                          title: Text(
                            event.title,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text(
                            '${DateFormat('hh:mm a').format(event.startTime)} • ${event.subtitle ?? ""}',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () {
                            context.push(event.route);
                          },
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
