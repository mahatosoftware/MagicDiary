import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/notifications/models/notification_enums.dart';
import '../../../core/notifications/models/notification_preference.dart';
import '../../../core/notifications/models/reminder_interval.dart';
import '../../../core/notifications/models/time_of_day_dto.dart';
import '../../../core/notifications/services/notification_manager.dart';
import '../../../core/providers/app_providers.dart';

class NotificationSettingsScreen extends ConsumerStatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  ConsumerState<NotificationSettingsScreen> createState() => _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState extends ConsumerState<NotificationSettingsScreen> {
  bool _masterEnabled = true;
  TimeOfDayDto _preferredTime = TimeOfDayDto.defaultPreferred;
  bool _quietHoursEnabled = true;
  TimeOfDayDto _quietHoursStart = TimeOfDayDto.defaultQuietStart;
  TimeOfDayDto _quietHoursEnd = TimeOfDayDto.defaultQuietEnd;
  bool _allowWeekends = true;
  bool _soundEnabled = true;
  bool _vibrationEnabled = true;
  PrivacyMode _privacyMode = PrivacyMode.detailed;
  bool _overdueAlertsEnabled = true;
  List<int> _overdueDays = [0, 1, 3, 7];
  int _defaultSnoozeMinutes = 60;
  int _maxSnoozeCount = 5;
  List<ReminderInterval> _selectedIntervals = [ReminderInterval.oneDayBefore];

  // Preview Simulator
  DateTime _previewEventDate = DateTime.now().add(const Duration(days: 15));
  final String _previewModule = 'bills';
  List<DateTime> _previewSchedules = [];

  bool _isSaving = false;
  bool _isLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadInitialPreferences();
  }

  Future<void> _loadInitialPreferences() async {
    final user = ref.read(userProfileProvider);
    final uid = user?.uid ?? '';
    if (uid.isNotEmpty) {
      final manager = NotificationManager();
      final pref = await manager.repository.getGlobalPreference(uid);
      if (pref != null) {
        setState(() {
          _masterEnabled = pref.isEnabled ?? true;
          _preferredTime = pref.preferredNotificationTime ?? TimeOfDayDto.defaultPreferred;
          _quietHoursEnabled = pref.quietHoursEnabled ?? true;
          _quietHoursStart = pref.quietHoursStart ?? TimeOfDayDto.defaultQuietStart;
          _quietHoursEnd = pref.quietHoursEnd ?? TimeOfDayDto.defaultQuietEnd;
          _allowWeekends = pref.allowWeekendNotifications ?? true;
          _soundEnabled = pref.soundEnabled ?? true;
          _vibrationEnabled = pref.vibrationEnabled ?? true;
          _privacyMode = pref.privacyMode ?? PrivacyMode.detailed;
          _overdueAlertsEnabled = pref.overdueAlertsEnabled ?? true;
          _overdueDays = pref.overdueIntervalsDays ?? [0, 1, 3, 7];
          _defaultSnoozeMinutes = pref.defaultSnoozeMinutes ?? 60;
          _maxSnoozeCount = pref.maxSnoozeCount ?? 5;
          _selectedIntervals = pref.reminderIntervals ?? [ReminderInterval.oneDayBefore];
          _isLoaded = true;
        });
        await _calculatePreview();
        return;
      }
    }
    setState(() => _isLoaded = true);
    await _calculatePreview();
  }

  Future<void> _calculatePreview() async {
    final user = ref.read(userProfileProvider);
    final uid = user?.uid ?? '';
    final manager = NotificationManager();
    final dates = await manager.previewSchedule(
      userId: uid,
      eventDate: _previewEventDate,
      moduleId: _previewModule,
    );
    if (mounted) {
      setState(() => _previewSchedules = dates);
    }
  }

  Future<void> _saveSettings() async {
    setState(() => _isSaving = true);
    final user = ref.read(userProfileProvider);
    final uid = user?.uid ?? '';

    final updatedPref = NotificationPreference(
      id: 'global',
      userId: uid,
      level: 'global',
      isEnabled: _masterEnabled,
      preferredNotificationTime: _preferredTime,
      quietHoursEnabled: _quietHoursEnabled,
      quietHoursStart: _quietHoursStart,
      quietHoursEnd: _quietHoursEnd,
      allowWeekendNotifications: _allowWeekends,
      soundEnabled: _soundEnabled,
      vibrationEnabled: _vibrationEnabled,
      privacyMode: _privacyMode,
      overdueAlertsEnabled: _overdueAlertsEnabled,
      overdueIntervalsDays: _overdueDays,
      defaultSnoozeMinutes: _defaultSnoozeMinutes,
      maxSnoozeCount: _maxSnoozeCount,
      reminderIntervals: _selectedIntervals,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    final manager = NotificationManager();
    await manager.repository.saveGlobalPreference(updatedPref);

    if (mounted) {
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Notification preferences saved successfully!'),
          backgroundColor: Colors.teal,
        ),
      );
    }
  }

  Future<void> _restoreDefaults() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Restore Global Defaults?'),
        content: const Text(
          'This will reset your global reminder preferences to system defaults. Explicit individual record overrides will be preserved.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Restore'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final user = ref.read(userProfileProvider);
      final uid = user?.uid ?? '';
      final manager = NotificationManager();
      await manager.preferenceManager.restoreDefaults(uid);
      await _loadInitialPreferences();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Global defaults restored.')),
        );
      }
    }
  }

  Future<void> _resetModuleSettings() async {
    final user = ref.read(userProfileProvider);
    final uid = user?.uid ?? '';
    final manager = NotificationManager();

    final selected = await showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Select Module to Reset'),
        children: [
          'bills',
          'finance',
          'vehicle',
          'warranty',
          'household',
          'school_fees',
          'property',
          'domestic_help',
          'personal',
        ]
            .map(
              (mod) => SimpleDialogOption(
                child: Text(mod.toUpperCase()),
                onPressed: () => Navigator.pop(ctx, mod),
              ),
            )
            .toList(),
      ),
    );

    if (selected != null) {
      await manager.preferenceManager.resetModuleSettings(uid, selected);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Module settings for $selected reset to inherit global defaults.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (!_isLoaded) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notification Settings'),
        actions: [
          TextButton(
            onPressed: _isSaving ? null : _saveSettings,
            child: _isSaving
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('SAVE', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 1. MASTER TOGGLE
          SwitchListTile(
            title: const Text('Enable Notifications', style: TextStyle(fontWeight: FontWeight.bold)),
            subtitle: const Text('Allow Magic Diary to deliver advance reminders and alerts'),
            value: _masterEnabled,
            onChanged: (val) => setState(() => _masterEnabled = val),
          ),
          const Divider(),

          // 2. TIMING & PREFERRED TIME
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text('SCHEDULE & PREFERRED TIMING', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
          ),
          ListTile(
            title: const Text('Preferred Notification Time'),
            subtitle: Text('Notifications trigger at ${_preferredTime.format12Hour()} on reminder days'),
            trailing: ElevatedButton(
              onPressed: () async {
                final picked = await showTimePicker(
                  context: context,
                  initialTime: _preferredTime.toTimeOfDay(),
                );
                if (picked != null) {
                  setState(() => _preferredTime = TimeOfDayDto.fromTimeOfDay(picked));
                  _calculatePreview();
                }
              },
              child: Text(_preferredTime.format12Hour()),
            ),
          ),
          SwitchListTile(
            title: const Text('Quiet Hours'),
            subtitle: Text(
              _quietHoursEnabled
                  ? 'Notifications silenced between ${_quietHoursStart.format12Hour()} and ${_quietHoursEnd.format12Hour()}'
                  : 'Disabled',
            ),
            value: _quietHoursEnabled,
            onChanged: (val) => setState(() => _quietHoursEnabled = val),
          ),
          SwitchListTile(
            title: const Text('Weekend Notifications'),
            subtitle: const Text('If disabled, weekend alerts are shifted to Friday or Monday'),
            value: _allowWeekends,
            onChanged: (val) => setState(() => _allowWeekends = val),
          ),
          const Divider(),

          // 3. DEFAULT REMINDER INTERVALS
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text('DEFAULT REMINDER INTERVALS', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
          ),
          const Text(
            'Select when reminders fire before due dates for newly created commitments:',
            style: TextStyle(fontSize: 13, color: Colors.grey),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildIntervalChip(ReminderInterval.thirtyDaysBefore, '30 days before'),
              _buildIntervalChip(ReminderInterval.fifteenDaysBefore, '15 days before'),
              _buildIntervalChip(ReminderInterval.sevenDaysBefore, '7 days before'),
              _buildIntervalChip(ReminderInterval.fiveDaysBefore, '5 days before'),
              _buildIntervalChip(ReminderInterval.threeDaysBefore, '3 days before'),
              _buildIntervalChip(ReminderInterval.oneDayBefore, '1 day before'),
              _buildIntervalChip(ReminderInterval.onDueDate, 'On due date'),
            ],
          ),
          const Divider(),

          // 4. SNOOZE & DEFER SETTINGS
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text('SNOOZE & POSTPONEMENT CONTROLS', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
          ),
          ListTile(
            title: const Text('Default Snooze Duration'),
            trailing: DropdownButton<int>(
              value: _defaultSnoozeMinutes,
              items: const [
                DropdownMenuItem(value: 10, child: Text('10 minutes')),
                DropdownMenuItem(value: 30, child: Text('30 minutes')),
                DropdownMenuItem(value: 60, child: Text('1 hour')),
                DropdownMenuItem(value: 180, child: Text('3 hours')),
              ],
              onChanged: (val) {
                if (val != null) setState(() => _defaultSnoozeMinutes = val);
              },
            ),
          ),
          ListTile(
            title: const Text('Maximum Snooze Count'),
            subtitle: const Text('Prevents indefinite postponement of critical commitments'),
            trailing: DropdownButton<int>(
              value: _maxSnoozeCount,
              items: [1, 2, 3, 5, 10].map((c) => DropdownMenuItem(value: c, child: Text('$c times'))).toList(),
              onChanged: (val) {
                if (val != null) setState(() => _maxSnoozeCount = val);
              },
            ),
          ),
          const Divider(),

          // 5. OVERDUE REMINDERS
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text('OVERDUE COMMITMENT ALERTS', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
          ),
          SwitchListTile(
            title: const Text('Enable Overdue Reminders'),
            subtitle: const Text('Persistent alerts on due date, +1 day, +3 days, and +7 days until marked paid'),
            value: _overdueAlertsEnabled,
            onChanged: (val) => setState(() => _overdueAlertsEnabled = val),
          ),
          const Divider(),

          // 6. SOUND, VIBRATION & PRIVACY
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text('PRIVACY, SOUND & VIBRATION', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
          ),
          SwitchListTile(
            title: const Text('Play Sound'),
            value: _soundEnabled,
            onChanged: (val) => setState(() => _soundEnabled = val),
          ),
          SwitchListTile(
            title: const Text('Vibration'),
            value: _vibrationEnabled,
            onChanged: (val) => setState(() => _vibrationEnabled = val),
          ),
          ListTile(
            title: const Text('Lock Screen Privacy'),
            subtitle: Text(
              _privacyMode == PrivacyMode.detailed
                  ? 'Detailed (shows title and amount)'
                  : (_privacyMode == PrivacyMode.masked
                      ? 'Masked (hides amounts: ₹••••)'
                      : 'Generic (shows generic reminder only)'),
            ),
            trailing: DropdownButton<PrivacyMode>(
              value: _privacyMode,
              items: const [
                DropdownMenuItem(value: PrivacyMode.detailed, child: Text('Detailed')),
                DropdownMenuItem(value: PrivacyMode.masked, child: Text('Masked')),
                DropdownMenuItem(value: PrivacyMode.generic, child: Text('Generic')),
              ],
              onChanged: (val) {
                if (val != null) setState(() => _privacyMode = val);
              },
            ),
          ),
          const Divider(),

          // 7. INTERACTIVE SCHEDULE PREVIEW SIMULATOR
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text('PREVIEW EFFECTIVE SCHEDULE', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
          ),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Test Due Date:', style: TextStyle(fontSize: 12)),
                    TextButton(
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: _previewEventDate,
                          firstDate: DateTime.now(),
                          lastDate: DateTime.now().add(const Duration(days: 365)),
                        );
                        if (picked != null) {
                          setState(() => _previewEventDate = picked);
                          _calculatePreview();
                        }
                      },
                      child: Text(DateFormat('dd MMM yyyy').format(_previewEventDate)),
                    ),
                  ],
                ),
                const Text('Fires on:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                if (_previewSchedules.isEmpty)
                  const Text('No notifications will fire for this date.', style: TextStyle(fontSize: 12, color: Colors.grey))
                else
                  ..._previewSchedules.map(
                    (d) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Row(
                        children: [
                          const Icon(Icons.alarm, size: 14, color: Colors.teal),
                          const SizedBox(width: 6),
                          Text(
                            DateFormat('dd MMM yyyy, hh:mm a').format(d),
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // 8. RESET & RESTORE BUTTONS
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _restoreDefaults,
                  child: const Text('Restore Defaults'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton(
                  onPressed: _resetModuleSettings,
                  child: const Text('Reset Module Settings'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildIntervalChip(ReminderInterval interval, String label) {
    final isSelected = _selectedIntervals.any((i) => i.value == interval.value && i.unit == interval.unit);
    return FilterChip(
      label: Text(label, style: const TextStyle(fontSize: 12)),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          if (selected) {
            _selectedIntervals.add(interval);
          } else {
            _selectedIntervals.removeWhere((i) => i.value == interval.value && i.unit == interval.unit);
          }
        });
        _calculatePreview();
      },
    );
  }
}
