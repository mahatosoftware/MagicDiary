import 'package:flutter/material.dart';
import '../../reminders/models/reminder.dart';

enum CalendarMode { day, week, month }

class CalendarAgendaView extends StatefulWidget {
  final DateTime selectedDate;
  final ValueChanged<DateTime> onDateSelected;
  final List<Reminder> reminders;

  const CalendarAgendaView({
    super.key,
    required this.selectedDate,
    required this.onDateSelected,
    required this.reminders,
  });

  @override
  State<CalendarAgendaView> createState() => _CalendarAgendaViewState();
}

class _CalendarAgendaViewState extends State<CalendarAgendaView> {
  CalendarMode _mode = CalendarMode.week;
  late DateTime _focusedMonth;

  @override
  void initState() {
    super.initState();
    _focusedMonth = DateTime(widget.selectedDate.year, widget.selectedDate.month, 1);
  }

  bool _hasItemsOnDate(DateTime date) {
    return widget.reminders.any((r) =>
        r.dueDate.year == date.year &&
        r.dueDate.month == date.month &&
        r.dueDate.day == date.day &&
        !r.isCompleted);
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          children: [
            // Top Bar: View Mode Switcher + Month/Day Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.chevron_left, size: 20),
                      onPressed: () {
                        setState(() {
                          if (_mode == CalendarMode.day) {
                            widget.onDateSelected(widget.selectedDate.subtract(const Duration(days: 1)));
                          } else if (_mode == CalendarMode.week) {
                            widget.onDateSelected(widget.selectedDate.subtract(const Duration(days: 7)));
                          } else {
                            _focusedMonth = DateTime(_focusedMonth.year, _focusedMonth.month - 1, 1);
                          }
                        });
                      },
                    ),
                    Text(
                      _mode == CalendarMode.day
                          ? '${widget.selectedDate.day}/${widget.selectedDate.month}/${widget.selectedDate.year}'
                          : '${_monthName(_focusedMonth.month)} ${_focusedMonth.year}',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    IconButton(
                      icon: const Icon(Icons.chevron_right, size: 20),
                      onPressed: () {
                        setState(() {
                          if (_mode == CalendarMode.day) {
                            widget.onDateSelected(widget.selectedDate.add(const Duration(days: 1)));
                          } else if (_mode == CalendarMode.week) {
                            widget.onDateSelected(widget.selectedDate.add(const Duration(days: 7)));
                          } else {
                            _focusedMonth = DateTime(_focusedMonth.year, _focusedMonth.month + 1, 1);
                          }
                        });
                      },
                    ),
                  ],
                ),
                SegmentedButton<CalendarMode>(
                  segments: const [
                    ButtonSegment(value: CalendarMode.day, label: Text('Day', style: TextStyle(fontSize: 11))),
                    ButtonSegment(value: CalendarMode.week, label: Text('Week', style: TextStyle(fontSize: 11))),
                    ButtonSegment(value: CalendarMode.month, label: Text('Month', style: TextStyle(fontSize: 11))),
                  ],
                  selected: {_mode},
                  onSelectionChanged: (val) {
                    setState(() => _mode = val.first);
                  },
                  style: const ButtonStyle(
                    visualDensity: VisualDensity.compact,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              ],
            ),
            const Divider(height: 16),

            // Mode Views
            if (_mode == CalendarMode.week) _buildWeekView(context),
            if (_mode == CalendarMode.month) _buildMonthView(context),
            if (_mode == CalendarMode.day) _buildDaySummary(context),
          ],
        ),
      ),
    );
  }

  Widget _buildWeekView(BuildContext context) {
    // Current week: find start of week (Monday)
    final startOfWeek = widget.selectedDate.subtract(Duration(days: widget.selectedDate.weekday - 1));
    final weekDays = List.generate(7, (i) => startOfWeek.add(Duration(days: i)));

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: weekDays.map((d) {
        final isSelected = d.year == widget.selectedDate.year &&
            d.month == widget.selectedDate.month &&
            d.day == widget.selectedDate.day;
        final isToday = d.year == DateTime.now().year &&
            d.month == DateTime.now().month &&
            d.day == DateTime.now().day;
        final hasItems = _hasItemsOnDate(d);

        return InkWell(
          onTap: () => widget.onDateSelected(d),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            width: 42,
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: isSelected
                  ? Theme.of(context).colorScheme.primary
                  : (isToday ? Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.4) : Colors.transparent),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                Text(
                  _weekdayName(d.weekday),
                  style: TextStyle(
                    fontSize: 11,
                    color: isSelected ? Colors.white : Colors.grey,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${d.day}',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: isSelected ? Colors.white : null,
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  width: 5,
                  height: 5,
                  decoration: BoxDecoration(
                    color: hasItems ? (isSelected ? Colors.white : Colors.blueAccent) : Colors.transparent,
                    shape: BoxShape.circle,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildMonthView(BuildContext context) {
    final daysInMonth = DateUtils.getDaysInMonth(_focusedMonth.year, _focusedMonth.month);
    final firstWeekday = DateTime(_focusedMonth.year, _focusedMonth.month, 1).weekday; // 1 = Mon, 7 = Sun
    final totalCells = ((daysInMonth + firstWeekday - 1) / 7).ceil() * 7;

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: ['M', 'T', 'W', 'T', 'F', 'S', 'S'].map((day) {
            return SizedBox(
              width: 32,
              child: Text(
                day,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 6),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: totalCells,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
            mainAxisSpacing: 4,
            crossAxisSpacing: 4,
            childAspectRatio: 1.1,
          ),
          itemBuilder: (ctx, i) {
            final dayNumber = i - (firstWeekday - 1) + 1;
            if (dayNumber < 1 || dayNumber > daysInMonth) {
              return const SizedBox.shrink();
            }

            final cellDate = DateTime(_focusedMonth.year, _focusedMonth.month, dayNumber);
            final isSelected = cellDate.year == widget.selectedDate.year &&
                cellDate.month == widget.selectedDate.month &&
                cellDate.day == widget.selectedDate.day;
            final isToday = cellDate.year == DateTime.now().year &&
                cellDate.month == DateTime.now().month &&
                cellDate.day == DateTime.now().day;
            final hasItems = _hasItemsOnDate(cellDate);

            return InkWell(
              onTap: () => widget.onDateSelected(cellDate),
              borderRadius: BorderRadius.circular(8),
              child: Container(
                decoration: BoxDecoration(
                  color: isSelected
                      ? Theme.of(context).colorScheme.primary
                      : (isToday ? Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.4) : Colors.transparent),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '$dayNumber',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: isSelected ? Colors.white : null,
                      ),
                    ),
                    Container(
                      width: 4,
                      height: 4,
                      decoration: BoxDecoration(
                        color: hasItems ? (isSelected ? Colors.white : Colors.blueAccent) : Colors.transparent,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildDaySummary(BuildContext context) {
    final dayReminders = widget.reminders.where((r) =>
        r.dueDate.year == widget.selectedDate.year &&
        r.dueDate.month == widget.selectedDate.month &&
        r.dueDate.day == widget.selectedDate.day).toList();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.event_note, size: 16, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 8),
          Text(
            '${dayReminders.length} item${dayReminders.length == 1 ? "" : "s"} scheduled for today',
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  String _weekdayName(int weekday) {
    switch (weekday) {
      case 1:
        return 'Mon';
      case 2:
        return 'Tue';
      case 3:
        return 'Wed';
      case 4:
        return 'Thu';
      case 5:
        return 'Fri';
      case 6:
        return 'Sat';
      case 7:
      default:
        return 'Sun';
    }
  }

  String _monthName(int month) {
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December'
    ];
    return months[month - 1];
  }
}
