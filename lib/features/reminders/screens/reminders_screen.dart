import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/date_calculators.dart';
import '../models/reminder.dart';
import '../services/reminder_action_resolver.dart';
import '../widgets/completion_details_dialog.dart';
import '../widgets/payment_confirmation_dialog.dart';
import '../../../core/ads/admob_config.dart';
import '../../../core/ads/widgets/native_ad_card_widget.dart';

class RemindersScreen extends ConsumerStatefulWidget {
  const RemindersScreen({super.key});

  @override
  ConsumerState<RemindersScreen> createState() => _RemindersScreenState();
}

class _RemindersScreenState extends ConsumerState<RemindersScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _selectedModuleFilter = 'All';
  bool _isSyncing = false;

  final List<Map<String, dynamic>> _modules = [
    {'id': 'All', 'label': 'All Diaries', 'icon': Icons.all_inclusive},
    {'id': 'SchoolFees', 'label': 'School Fees', 'icon': Icons.school, 'color': Colors.purple},
    {'id': 'Bills', 'label': 'Bills & Utilities', 'icon': Icons.receipt_long, 'color': Colors.orange},
    {'id': 'Vehicle', 'label': 'Vehicle', 'icon': Icons.directions_car, 'color': Colors.blue},
    {'id': 'Household', 'label': 'Household', 'icon': Icons.home_work, 'color': Colors.teal},
    {'id': 'Property', 'label': 'Property', 'icon': Icons.apartment, 'color': Colors.indigo},
    {'id': 'Warranty', 'label': 'Warranty', 'icon': Icons.verified_outlined, 'color': Colors.cyan},
    {'id': 'Personal', 'label': 'Personal', 'icon': Icons.event, 'color': Colors.deepOrange},
    {'id': 'Finance', 'label': 'Finance', 'icon': Icons.account_balance_wallet, 'color': Colors.green},
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _syncAllDiariesSilently();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _syncAllDiariesSilently() async {
    final user = ref.read(userProfileProvider);
    if (user == null) return;
    try {
      final syncService = ref.read(reminderSyncServiceProvider);
      await syncService.syncAllDiaries(user.uid);
      if (mounted) {
        ref.invalidate(remindersProvider);
      }
    } catch (_) {}
  }

  Future<void> _syncAllDiaries() async {
    final user = ref.read(userProfileProvider);
    if (user == null) return;

    setState(() => _isSyncing = true);
    try {
      final syncService = ref.read(reminderSyncServiceProvider);
      final count = await syncService.syncAllDiaries(user.uid);
      ref.invalidate(remindersProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$count reminders synchronized across all your diaries!'),
            backgroundColor: Colors.teal.shade800,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Sync failed: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSyncing = false);
    }
  }

  void _showDeferDialog(BuildContext context, Reminder reminder) {
    final user = ref.read(userProfileProvider);
    if (user == null) return;
    final repo = ref.read(reminderRepositoryProvider);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Snooze / Defer "${reminder.title}"'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Choose deferral duration:'),
            const SizedBox(height: 12),
            ListTile(
              leading: const Icon(Icons.today, color: Colors.blue),
              title: const Text('Defer +1 Day'),
              onTap: () async {
                Navigator.pop(context);
                await repo.deferReminder(user.uid, reminder.id, DeferOption.plus1Day);
                ref.invalidate(remindersProvider);
              },
            ),
            ListTile(
              leading: const Icon(Icons.date_range, color: Colors.purple),
              title: const Text('Defer +1 Week'),
              onTap: () async {
                Navigator.pop(context);
                await repo.deferReminder(user.uid, reminder.id, DeferOption.plus1Week);
                ref.invalidate(remindersProvider);
              },
            ),
            ListTile(
              leading: const Icon(Icons.calendar_month, color: Colors.orange),
              title: const Text('Defer +1 Month'),
              onTap: () async {
                Navigator.pop(context);
                await repo.deferReminder(user.uid, reminder.id, DeferOption.plus1Month);
                ref.invalidate(remindersProvider);
              },
            ),
            ListTile(
              leading: const Icon(Icons.edit_calendar, color: Colors.teal),
              title: const Text('Custom Date...'),
              onTap: () async {
                Navigator.pop(context);
                final picked = await showDatePicker(
                  context: context,
                  initialDate: reminder.dueDate.add(const Duration(days: 3)),
                  firstDate: DateTime.now(),
                  lastDate: DateTime.now().add(const Duration(days: 365)),
                );
                if (picked != null) {
                  final days = picked.difference(DateTime.now()).inDays + 1;
                  await repo.deferReminder(user.uid, reminder.id, DeferOption.customDays, customDays: days);
                  ref.invalidate(remindersProvider);
                }
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  void _showDeleteDialog(BuildContext context, Reminder reminder) {
    final user = ref.read(userProfileProvider);
    if (user == null) return;
    final repo = ref.read(reminderRepositoryProvider);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Reminder?'),
        content: Text('Are you sure you want to delete "${reminder.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(context);
              await repo.deleteReminder(user.uid, reminder.id);
              ref.invalidate(remindersProvider);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Reminder deleted')),
                );
              }
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Color _getModuleColor(String module) {
    switch (module) {
      case 'SchoolFees':
        return Colors.purple;
      case 'Bills':
        return Colors.orange;
      case 'Vehicle':
        return Colors.blue;
      case 'Household':
        return Colors.teal;
      case 'Property':
        return Colors.indigo;
      case 'Warranty':
        return Colors.cyan;
      case 'Personal':
        return Colors.deepOrange;
      case 'Finance':
        return Colors.green;
      default:
        return Colors.blueGrey;
    }
  }

  IconData _getModuleIcon(String module) {
    switch (module) {
      case 'SchoolFees':
        return Icons.school;
      case 'Bills':
        return Icons.receipt_long;
      case 'Vehicle':
        return Icons.directions_car;
      case 'Household':
        return Icons.home_work;
      case 'Property':
        return Icons.apartment;
      case 'Warranty':
        return Icons.verified_outlined;
      case 'Personal':
        return Icons.event;
      case 'Finance':
        return Icons.account_balance_wallet;
      default:
        return Icons.notifications;
    }
  }

  Widget _buildSummaryCard(String title, String count, IconData icon, Color color, {VoidCallback? onTap}) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: color.withValues(alpha: 0.2)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(height: 3),
              Text(
                count,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: color,
                ),
              ),
              const SizedBox(height: 1),
              Text(
                title,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade700,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Reminder> _deduplicateReminders(List<Reminder> reminders) {
    final Map<String, Reminder> uniqueMap = {};
    for (final r in reminders) {
      final cleanTitle = r.title.toLowerCase().replaceAll(RegExp(r'^(event|special event|reminder|payment due|bill|birthday|anniversary):\s*'), '').trim();
      final dateKey = '${r.dueDate.year}-${r.dueDate.month.toString().padLeft(2, '0')}-${r.dueDate.day.toString().padLeft(2, '0')}';
      final key = (r.relatedId != null && r.relatedId!.isNotEmpty)
          ? 'rel_${r.relatedId}_$dateKey'
          : 'sig_${r.module.toLowerCase()}_${cleanTitle}_$dateKey';

      if (!uniqueMap.containsKey(key)) {
        uniqueMap[key] = r;
      } else {
        final existing = uniqueMap[key]!;
        if (existing.isCompleted && !r.isCompleted) {
          uniqueMap[key] = r;
        } else if ((existing.amount == null && r.amount != null) ||
                   ((existing.actionRoute == null || existing.actionRoute!.isEmpty) && (r.actionRoute != null && r.actionRoute!.isNotEmpty))) {
          uniqueMap[key] = r;
        }
      }
    }
    return uniqueMap.values.toList();
  }

  Widget _buildReminderCard(BuildContext context, Reminder r, DateTime now) {
    final moduleColor = _getModuleColor(r.module);
    final moduleIcon = _getModuleIcon(r.module);
    final isOverdue = r.isOverdue(now);
    final isToday = r.isToday(now);
    final daysUntil = r.daysUntil(now);
    final resolvedAction = ReminderActionResolver.resolve(r);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: isToday ? 2.5 : 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isOverdue
              ? Colors.red.shade300
              : isToday
                  ? Colors.amber.shade500
                  : Colors.grey.shade200,
          width: (isOverdue || isToday) ? 1.4 : 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Row: Module Badge, Due Pill, and Context Actions
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: moduleColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(moduleIcon, size: 14, color: moduleColor),
                            const SizedBox(width: 4),
                            Text(
                              r.module,
                              style: TextStyle(
                                color: moduleColor,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Status indicator pill
                      if (r.isCompleted)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.green.shade50,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: Colors.green.shade300),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.check_circle, size: 12, color: Colors.green),
                              const SizedBox(width: 4),
                              Text(
                                r.isPaid
                                    ? 'Paid ${r.completedAt != null ? DateFormat('dd MMM').format(r.completedAt!) : ''}'
                                    : 'Completed ${r.completedAt != null ? DateFormat('dd MMM').format(r.completedAt!) : ''}',
                                style: TextStyle(color: Colors.green.shade900, fontSize: 11, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        )
                      else if (isOverdue)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.red.shade50,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: Colors.red.shade400),
                          ),
                          child: Text(
                            'Overdue by ${daysUntil.abs()}d',
                            style: TextStyle(color: Colors.red.shade900, fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                        )
                      else if (isToday)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.amber.shade100,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: Colors.amber.shade600),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.star, size: 12, color: Colors.amber.shade900),
                              const SizedBox(width: 4),
                              Text(
                                'Due Today',
                                style: TextStyle(color: Colors.amber.shade900, fontSize: 11, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        )
                      else if (daysUntil == 1)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            'Due Tomorrow',
                            style: TextStyle(color: Colors.blue, fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                        )
                      else
                        Text(
                          'In $daysUntil days',
                          style: TextStyle(color: Colors.grey.shade700, fontSize: 11, fontWeight: FontWeight.w600),
                        ),
                    ],
                  ),
                ),

                // Amount Pill (if this reminder has a scheduled payment)
                if (r.amount != null && r.amount! > 0) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.teal.shade50,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.teal.shade200),
                    ),
                    child: Text(
                      AppFormatters.currency(r.amount!),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: Colors.teal.shade900,
                      ),
                    ),
                  ),
                ],
              ],
            ),

            const SizedBox(height: 10),

            // Title & Description
            Text(
              r.title,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 15,
                decoration: r.isCompleted ? TextDecoration.lineThrough : null,
                color: r.isCompleted ? Colors.grey : Colors.black87,
              ),
            ),
            if (r.description.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                r.description,
                style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
              ),
            ],

            const SizedBox(height: 8),

            // Due Date & Snooze Information
            Wrap(
              spacing: 12,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.calendar_today, size: 14, color: Colors.grey),
                    const SizedBox(width: 4),
                    Text(
                      'Due: ${AppFormatters.date(r.dueDate)}',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade800, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
                if (r.isSnoozed && r.snoozedUntil != null)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.snooze, size: 14, color: Colors.orange),
                      const SizedBox(width: 4),
                      Text(
                        'Snoozed until: ${AppFormatters.date(r.snoozedUntil!)}',
                        style: const TextStyle(fontSize: 12, color: Colors.orange, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
              ],
            ),

            const Divider(height: 18),

            // Action Buttons Row (Same compact look & feel as before)
            Row(
              children: [
                // Direct Pay / Open in Diary Module Button
                if (r.actionRoute != null)
                  ElevatedButton.icon(
                    onPressed: () => context.push(r.actionRoute!),
                    icon: Icon(
                      r.amount != null ? Icons.payment : Icons.open_in_new,
                      size: 14,
                    ),
                    label: Text(
                      r.amount != null ? 'Pay / View' : 'Open in Diary',
                      style: const TextStyle(fontSize: 12),
                    ),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      visualDensity: VisualDensity.compact,
                      backgroundColor: moduleColor,
                    ),
                  ),

                const Spacer(),

                if (!r.isCompleted) ...[
                  // Snooze / Defer Button
                  IconButton(
                    icon: const Icon(Icons.snooze_outlined, size: 20, color: Colors.orange),
                    tooltip: 'Snooze / Defer',
                    visualDensity: VisualDensity.compact,
                    onPressed: () => _showDeferDialog(context, r),
                  ),
                  // Mark Completed / Paid Button
                  IconButton(
                    icon: const Icon(Icons.check_circle_outline, size: 20, color: Colors.green),
                    tooltip: resolvedAction == ReminderActionType.markPaid ? 'Mark as Paid' : 'Mark Done',
                    visualDensity: VisualDensity.compact,
                    onPressed: () async {
                      final user = ref.read(userProfileProvider);
                      if (user == null) return;

                      if (resolvedAction == ReminderActionType.markPaid) {
                        await PaymentConfirmationDialog.show(
                          context,
                          reminder: r,
                          onConfirm: (details) async {
                            final repo = ref.read(reminderRepositoryProvider);
                            await repo.markAsPaid(
                              userId: user.uid,
                              reminderId: r.id,
                              paymentDetails: details,
                            );

                            final txId = r.effectiveLinkedRecordId;
                            if (txId.isNotEmpty &&
                                (r.module.toLowerCase() == 'finance' || r.id.startsWith('reminder_tx_'))) {
                              try {
                                await ref.read(financeRepositoryProvider).markTransactionAsPaid(
                                  user.uid,
                                  txId,
                                  paidAt: details.paidAt,
                                  paymentMethod: details.paymentMethod,
                                );
                                ref.invalidate(financialTransactionsProvider);
                              } catch (_) {}
                            }

                            ref.invalidate(remindersProvider);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Marked as paid: "${r.title}" (₹${details.amount.toStringAsFixed(0)})'),
                                  backgroundColor: Colors.green.shade800,
                                ),
                              );
                            }
                          },
                        );
                      } else {
                        await CompletionDetailsDialog.show(
                          context,
                          reminder: r,
                          actionType: resolvedAction,
                          onConfirm: (details) async {
                            final repo = ref.read(reminderRepositoryProvider);
                            await repo.markAsComplete(
                              userId: user.uid,
                              reminderId: r.id,
                              completionDetails: details,
                              actionType: resolvedAction,
                            );
                            ref.invalidate(remindersProvider);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Completed: "${r.title}"'),
                                  backgroundColor: Colors.blue.shade800,
                                ),
                              );
                            }
                          },
                        );
                      }
                    },
                  ),
                ],

                // Delete Button
                IconButton(
                  icon: const Icon(Icons.delete_outline, size: 20, color: Colors.grey),
                  tooltip: 'Delete Reminder',
                  visualDensity: VisualDensity.compact,
                  onPressed: () => _showDeleteDialog(context, r),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(String message, IconData icon) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 40, color: Colors.blue.shade700),
            ),
            const SizedBox(height: 14),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 6),
            const Text(
              'Reminders from your School Fees, Bills, Vehicles, Household, Property & Personal (Birthdays & Anniversaries) diaries are synchronized here.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final remindersAsync = ref.watch(remindersProvider);
    final theme = Theme.of(context);
    final now = DateTime.now();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Reminders & Alerts', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: _isSyncing
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.sync),
            tooltip: 'Sync All Diaries',
            onPressed: _isSyncing ? null : _syncAllDiaries,
          ),
        ],
      ),
      body: remindersAsync.when(
        data: (allReminders) {
          // Deduplicate reminders by relatedId or unique signature
          final dedupedReminders = _deduplicateReminders(allReminders);

          // Apply module filter
          final filtered = _selectedModuleFilter == 'All'
              ? dedupedReminders
              : dedupedReminders.where((r) => r.module == _selectedModuleFilter).toList();

          // Slices
          final todayReminders = filtered.where((r) => r.isToday(now) && !r.isCompleted).toList();
          final upcomingReminders = filtered.where((r) => r.isUpcoming(now) && !r.isCompleted).toList();
          final overdueReminders = filtered.where((r) => r.isOverdue(now) && !r.isCompleted).toList();
          final completedReminders = filtered.where((r) => r.isCompleted).toList();

          return Column(
            children: [
              // Top Metrics Bar (Same 4 summary cards as before)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
                child: Row(
                  children: [
                    _buildSummaryCard(
                      'Due Today',
                      '${todayReminders.length}',
                      Icons.star,
                      Colors.amber.shade800,
                      onTap: () => _tabController.animateTo(1),
                    ),
                    const SizedBox(width: 8),
                    _buildSummaryCard(
                      'Overdue',
                      '${overdueReminders.length}',
                      Icons.error_outline,
                      Colors.red.shade700,
                      onTap: () => _tabController.animateTo(2),
                    ),
                    const SizedBox(width: 8),
                    _buildSummaryCard(
                      'Upcoming',
                      '${upcomingReminders.length}',
                      Icons.calendar_month,
                      Colors.blue.shade700,
                      onTap: () => _tabController.animateTo(0),
                    ),
                    const SizedBox(width: 8),
                    _buildSummaryCard(
                      'Done',
                      '${completedReminders.length}',
                      Icons.check_circle_outline,
                      Colors.green.shade700,
                      onTap: () => _tabController.animateTo(3),
                    ),
                  ],
                ),
              ),

              // Filter Chips Carousel
              SizedBox(
                height: 48,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  itemCount: _modules.length,
                  itemBuilder: (context, index) {
                    final mod = _modules[index];
                    final isSelected = _selectedModuleFilter == mod['id'];
                    final color = mod['color'] as Color? ?? Colors.blueGrey;

                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4.0),
                      child: FilterChip(
                        selected: isSelected,
                        showCheckmark: false,
                        avatar: Icon(
                          mod['icon'] as IconData,
                          size: 14,
                          color: isSelected ? Colors.white : color,
                        ),
                        label: Text(
                          mod['label'] as String,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            color: isSelected ? Colors.white : Colors.black87,
                          ),
                        ),
                        selectedColor: color,
                        backgroundColor: color.withValues(alpha: 0.08),
                        side: BorderSide(
                          color: isSelected ? color : color.withValues(alpha: 0.25),
                        ),
                        onSelected: (selected) {
                          setState(() {
                            _selectedModuleFilter = mod['id'] as String;
                          });
                        },
                      ),
                    );
                  },
                ),
              ),

              const Divider(height: 1),

              // Tabs Row (Exact 4 tabs as before)
              TabBar(
                controller: _tabController,
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                labelColor: theme.colorScheme.primary,
                unselectedLabelColor: Colors.grey.shade600,
                indicatorColor: theme.colorScheme.primary,
                indicatorWeight: 3,
                tabs: const [
                  Tab(text: 'Today & Upcoming'),
                  Tab(text: 'Due Today ⭐'),
                  Tab(text: 'Overdue 🚨'),
                  Tab(text: 'Completed ✅'),
                ],
              ),

              // Tab Views
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    // TAB 0: TODAY & UPCOMING COMBINED
                    RefreshIndicator(
                      onRefresh: _syncAllDiaries,
                      child: SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 88.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // 1. OVERDUE ALERT SECTION (IF ANY)
                            if (overdueReminders.isNotEmpty) ...[
                              Container(
                                padding: const EdgeInsets.all(12),
                                margin: const EdgeInsets.only(bottom: 16),
                                decoration: BoxDecoration(
                                  color: Colors.red.shade50,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: Colors.red.shade200),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 28),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            '${overdueReminders.length} Overdue Reminder${overdueReminders.length > 1 ? 's' : ''}',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: Colors.red,
                                              fontSize: 14,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            'Action required to avoid late fees or disruptions.',
                                            style: TextStyle(color: Colors.red.shade800, fontSize: 11),
                                          ),
                                        ],
                                      ),
                                    ),
                                    TextButton(
                                      onPressed: () => _tabController.animateTo(2),
                                      child: const Text('View All', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
                                    ),
                                  ],
                                ),
                              ),
                              ...overdueReminders.take(3).map((r) => _buildReminderCard(context, r, now)),
                              const SizedBox(height: 16),
                            ],

                            // 2. DUE TODAY SECTION
                            Row(
                              children: [
                                const Icon(Icons.star, color: Colors.amber, size: 18),
                                const SizedBox(width: 8),
                                Text(
                                  "Due Today (${todayReminders.length})",
                                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),

                            if (todayReminders.isEmpty)
                              Card(
                                elevation: 0,
                                color: Colors.amber.shade50,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  side: BorderSide(color: Colors.amber.shade200),
                                ),
                                child: const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 16.0, horizontal: 16.0),
                                  child: Row(
                                    children: [
                                      Icon(Icons.celebration_outlined, color: Colors.amber, size: 24),
                                      SizedBox(width: 12),
                                      Expanded(
                                        child: Text(
                                          'No reminders due today. You are all caught up!',
                                          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              )
                            else
                              ...todayReminders.map((r) => _buildReminderCard(context, r, now)),

                            const SizedBox(height: 16),
                            const NativeAdCardWidget(
                              placement: AdMobConfig.placementRemindersNative,
                            ),
                            const SizedBox(height: 20),

                            // 3. UPCOMING REMINDERS SECTION
                            Row(
                              children: [
                                const Icon(Icons.calendar_today, color: Colors.blue, size: 18),
                                const SizedBox(width: 8),
                                Text(
                                  "Upcoming Reminders (${upcomingReminders.length})",
                                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),

                            if (upcomingReminders.isEmpty)
                              _buildEmptyState('No upcoming reminders scheduled.', Icons.calendar_today)
                            else
                              ...upcomingReminders.map((r) => _buildReminderCard(context, r, now)),

                            const SizedBox(height: 40),
                          ],
                        ),
                      ),
                    ),

                    // TAB 1: DUE TODAY ONLY
                    RefreshIndicator(
                      onRefresh: _syncAllDiaries,
                      child: todayReminders.isEmpty
                          ? _buildEmptyState('No reminders due today!', Icons.event_available)
                          : ListView.builder(
                              padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 88.0),
                              itemCount: todayReminders.length,
                              itemBuilder: (ctx, i) => _buildReminderCard(ctx, todayReminders[i], now),
                            ),
                    ),

                    // TAB 2: OVERDUE ONLY
                    RefreshIndicator(
                      onRefresh: _syncAllDiaries,
                      child: overdueReminders.isEmpty
                          ? _buildEmptyState('Great! No overdue reminders.', Icons.thumb_up_alt_outlined)
                          : ListView.builder(
                              padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 88.0),
                              itemCount: overdueReminders.length,
                              itemBuilder: (ctx, i) => _buildReminderCard(ctx, overdueReminders[i], now),
                            ),
                    ),

                    // TAB 3: COMPLETED HISTORY
                    RefreshIndicator(
                      onRefresh: _syncAllDiaries,
                      child: completedReminders.isEmpty
                          ? _buildEmptyState('No completed reminders yet.', Icons.check_circle_outline)
                          : ListView.builder(
                              padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 88.0),
                              itemCount: completedReminders.length,
                              itemBuilder: (ctx, i) => _buildReminderCard(ctx, completedReminders[i], now),
                            ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error loading reminders: $err')),
      ),
    );
  }
}
