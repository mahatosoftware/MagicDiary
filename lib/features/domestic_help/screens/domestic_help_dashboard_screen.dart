import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/utils/pdf_exporter.dart';
import '../models/domestic_help_models.dart';

class DomesticHelpDashboardScreen extends ConsumerStatefulWidget {
  const DomesticHelpDashboardScreen({super.key});

  @override
  ConsumerState<DomesticHelpDashboardScreen> createState() => _DomesticHelpDashboardScreenState();
}

class _DomesticHelpDashboardScreenState extends ConsumerState<DomesticHelpDashboardScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final DateTime _selectedDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final workersAsync = ref.watch(domesticWorkersProvider);
    final attendanceAsync = ref.watch(todayWorkerAttendanceProvider);
    final servicesAsync = ref.watch(recurringServicesProvider);
    final serviceEntriesAsync = ref.watch(todayServiceEntriesProvider);
    final statementsAsync = ref.watch(salaryStatementsProvider);

    final dateStr = DateFormat('EEE, dd MMM yyyy').format(_selectedDate);

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
        title: const Text('Domestic Help & Services 🧹'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.people_outline), text: 'Staff & Attendance'),
            Tab(icon: Icon(Icons.local_shipping_outlined), text: 'Daily Services'),
            Tab(icon: Icon(Icons.payments_outlined), text: 'Salaries & Advances'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // TAB 1: Domestic Workers & Daily Attendance
          RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(domesticWorkersProvider);
              ref.invalidate(todayWorkerAttendanceProvider);
            },
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 88.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Fast Daily Attendance Card
                  _buildDailyAttendanceCard(context, dateStr, workersAsync, attendanceAsync),

                  const SizedBox(height: 24),

                  // Domestic Workers Registry Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Household Staff Profiles',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      FilledButton.icon(
                        icon: const Icon(Icons.add, size: 18),
                        label: const Text('Add Worker'),
                        onPressed: () => _showAddWorkerDialog(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  workersAsync.when(
                    data: (workers) {
                      if (workers.isEmpty) {
                        return Card(
                          child: Padding(
                            padding: const EdgeInsets.all(24.0),
                            child: Center(
                              child: Column(
                                children: [
                                  const Icon(Icons.person_add_outlined, size: 40, color: Colors.grey),
                                  const SizedBox(height: 10),
                                  const Text('No household staff registered yet.'),
                                  const SizedBox(height: 4),
                                  const Text(
                                    'Add your maid, cook, driver, or gardener to manage attendance and monthly salaries.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(fontSize: 12, color: Colors.grey),
                                  ),
                                  const SizedBox(height: 12),
                                  FilledButton(
                                    onPressed: () => _showAddWorkerDialog(context),
                                    child: const Text('Register First Worker'),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }

                      return Column(
                        children: workers.map((w) => _buildWorkerCard(context, w)).toList(),
                      );
                    },
                    loading: () => const Center(child: Padding(
                      padding: EdgeInsets.all(32.0),
                      child: CircularProgressIndicator(),
                    )),
                    error: (e, _) => Text('Error: $e'),
                  ),
                ],
              ),
            ),
          ),

          // TAB 2: Recurring Household Services (Milk, Newspaper, Water Cans)
          RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(recurringServicesProvider);
              ref.invalidate(todayServiceEntriesProvider);
            },
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 88.0),
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
                            'Daily Deliveries Log ($dateStr)',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          const Text(
                            'Record actual deliveries (milk, newspaper, water cans)',
                            style: TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                        ],
                      ),
                      IconButton(
                        icon: const Icon(Icons.add_circle, color: Colors.blueAccent),
                        tooltip: 'Add Service Provider',
                        onPressed: () => _showAddServiceDialog(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  servicesAsync.when(
                    data: (services) {
                      if (services.isEmpty) {
                        return Card(
                          child: Padding(
                            padding: const EdgeInsets.all(24.0),
                            child: Center(
                              child: Column(
                                children: [
                                  const Icon(Icons.local_shipping_outlined, size: 40, color: Colors.grey),
                                  const SizedBox(height: 10),
                                  const Text('No recurring household services configured.'),
                                  const SizedBox(height: 4),
                                  const Text(
                                    'Set up daily milk delivery, newspaper subscriptions, laundry, or water cans.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(fontSize: 12, color: Colors.grey),
                                  ),
                                  const SizedBox(height: 12),
                                  FilledButton(
                                    onPressed: () => _showAddServiceDialog(context),
                                    child: const Text('Add Service Provider'),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }

                      return Column(
                        children: services.map((s) => _buildServiceEntryCard(context, s, serviceEntriesAsync.value ?? const [])).toList(),
                      );
                    },
                    loading: () => const Center(child: CircularProgressIndicator()),
                    error: (e, _) => Text('Error: $e'),
                  ),
                ],
              ),
            ),
          ),

          // TAB 3: Salaries, Advances & Settlements
          RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(salaryStatementsProvider);
              ref.invalidate(domesticWorkersProvider);
            },
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 88.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Card(
                    color: Colors.green.shade50,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Row(
                        children: [
                          const Icon(Icons.calculate_outlined, color: Colors.green, size: 36),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Salary Settlement Formula',
                                  style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green.shade900),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Net Payable = Base Salary + Bonuses + Extra Work - Leave Deductions - Advance Recovery',
                                  style: TextStyle(fontSize: 11, color: Colors.green.shade800),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Monthly Salary Settlements',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      Row(
                        children: [
                          if (statementsAsync.value != null && statementsAsync.value!.isNotEmpty) ...[
                            IconButton(
                              icon: const Icon(Icons.picture_as_pdf_outlined, size: 20),
                              tooltip: 'Export Payroll Report (PDF)',
                              onPressed: () {
                                final list = statementsAsync.value!;
                                final now = DateTime.now();
                                PdfExporter.generateSalaryStatementsReport(list, now.month, now.year);
                              },
                            ),
                          ],
                          TextButton.icon(
                            icon: const Icon(Icons.add, size: 16),
                            label: const Text('Draft Settlement'),
                            onPressed: () => _showDraftSalaryDialog(context, workersAsync.value ?? const []),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  statementsAsync.when(
                    data: (statements) {
                      if (statements.isEmpty) {
                        return const Card(
                          child: Padding(
                            padding: EdgeInsets.all(20.0),
                            child: Center(
                              child: Text('No salary statements recorded yet. Tap "Draft Settlement" above to calculate.'),
                            ),
                          ),
                        );
                      }
                      return Column(
                        children: statements.map((s) => _buildSalaryStatementCard(context, s)).toList(),
                      );
                    },
                    loading: () => const Center(child: CircularProgressIndicator()),
                    error: (e, _) => Text('Error: $e'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- Fast Daily Attendance UI ---
  Widget _buildDailyAttendanceCard(
    BuildContext context,
    String dateStr,
    AsyncValue<List<DomesticWorker>> workersAsync,
    AsyncValue<List<WorkerAttendance>> attendanceAsync,
  ) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.6)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.calendar_today, size: 18, color: Colors.blueAccent),
                    const SizedBox(width: 8),
                    Text(
                      'Today\'s Attendance ($dateStr)',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '1-tap marking for staff. Prevents duplicate entries.',
              style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
            const Divider(height: 20),

            workersAsync.when(
              data: (workers) {
                final activeWorkers = workers.where((w) => w.isActive).toList();
                if (activeWorkers.isEmpty) {
                  return const Text('No active workers to mark attendance.');
                }

                final attList = attendanceAsync.value ?? const [];
                final attMap = {for (final a in attList) a.workerId: a};

                return Column(
                  children: activeWorkers.map((w) {
                    final currentAtt = attMap[w.id];
                    return _buildWorkerAttendanceRow(context, w, currentAtt);
                  }).toList(),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Text('Error: $e'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWorkerAttendanceRow(BuildContext context, DomesticWorker worker, WorkerAttendance? attendance) {
    final status = attendance?.status;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 14,
                backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                child: Text(worker.name[0], style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(worker.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    Text('${worker.role} • ₹${worker.baseSalary.toStringAsFixed(0)}/mo', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                  ],
                ),
              ),
              if (status != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: _getStatusColor(status).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    _getStatusLabel(status),
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: _getStatusColor(status)),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          // Attendance Action Buttons
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildAttendancePill(worker, AttendanceStatus.present, 'Present', Colors.green, status == AttendanceStatus.present),
                _buildAttendancePill(worker, AttendanceStatus.halfDay, 'Half-day', Colors.amber.shade800, status == AttendanceStatus.halfDay),
                _buildAttendancePill(worker, AttendanceStatus.absent, 'Absent', Colors.red, status == AttendanceStatus.absent),
                _buildAttendancePill(worker, AttendanceStatus.approvedLeave, 'Leave', Colors.blue, status == AttendanceStatus.approvedLeave),
                _buildAttendancePill(worker, AttendanceStatus.notScheduled, 'N/A', Colors.grey, status == AttendanceStatus.notScheduled),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAttendancePill(DomesticWorker worker, AttendanceStatus status, String label, Color color, bool isSelected) {
    return Padding(
      padding: const EdgeInsets.only(right: 6.0),
      child: ChoiceChip(
        label: Text(label, style: TextStyle(fontSize: 11, color: isSelected ? Colors.white : color, fontWeight: FontWeight.bold)),
        selected: isSelected,
        selectedColor: color,
        visualDensity: VisualDensity.compact,
        showCheckmark: false,
        onSelected: (val) async {
          if (!val) return;
          final user = ref.read(userProfileProvider);
          if (user == null) return;

          final repo = ref.read(domesticHelpRepositoryProvider);
          final dateStr = '${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}';
          await repo.recordAttendance(
            user.uid,
            WorkerAttendance(
              id: WorkerAttendance.generateId(worker.id, _selectedDate),
              workerId: worker.id,
              householdId: worker.householdId,
              date: dateStr,
              status: status,
              recordedByUid: user.uid,
              recordedByName: user.displayName,
              timestamp: DateTime.now(),
            ),
          );
          ref.invalidate(todayWorkerAttendanceProvider);
        },
      ),
    );
  }

  Color _getStatusColor(AttendanceStatus status) {
    switch (status) {
      case AttendanceStatus.present:
        return Colors.green;
      case AttendanceStatus.halfDay:
        return Colors.amber.shade800;
      case AttendanceStatus.absent:
      case AttendanceStatus.unpaidLeave:
        return Colors.red;
      case AttendanceStatus.approvedLeave:
        return Colors.blue;
      case AttendanceStatus.notScheduled:
        return Colors.grey;
    }
  }

  String _getStatusLabel(AttendanceStatus status) {
    switch (status) {
      case AttendanceStatus.present:
        return 'Present';
      case AttendanceStatus.halfDay:
        return 'Half-day';
      case AttendanceStatus.absent:
        return 'Absent';
      case AttendanceStatus.unpaidLeave:
        return 'Unpaid Leave';
      case AttendanceStatus.approvedLeave:
        return 'Approved Leave';
      case AttendanceStatus.notScheduled:
        return 'Off';
    }
  }

  // --- Worker Profiles List ---
  Widget _buildWorkerCard(BuildContext context, DomesticWorker w) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: Colors.teal.shade50,
                  child: const Icon(Icons.person, color: Colors.teal),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(w.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                      Text('${w.role} • Contact: ${w.phone}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                    ],
                  ),
                ),
                Text(
                  '₹${w.baseSalary.toStringAsFixed(0)}/mo',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.teal),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Text('Pay Due: ${w.paymentDueDay}th of month', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                const SizedBox(width: 16),
                if (w.advanceBalance > 0)
                  Text('Advance Owed: ₹${w.advanceBalance.toStringAsFixed(0)}', style: const TextStyle(fontSize: 11, color: Colors.red, fontWeight: FontWeight.bold)),
              ],
            ),
            const Divider(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton.icon(
                  icon: const Icon(Icons.money, size: 14),
                  label: const Text('Give Advance', style: TextStyle(fontSize: 11)),
                  onPressed: () => _showAddAdvanceDialog(context, w),
                ),
                const SizedBox(width: 8),
                FilledButton.tonal(
                  onPressed: () => _showDraftSalaryForWorker(context, w),
                  child: const Text('Draft Salary', style: TextStyle(fontSize: 11)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // --- Recurring Household Services UI ---
  Widget _buildServiceEntryCard(BuildContext context, RecurringService s, List<ServiceEntry> entries) {
    final dateStr = '${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}';
    final entry = entries.where((e) => e.serviceId == s.id && e.date == dateStr).firstOrNull;
    final currentQty = entry?.quantity ?? s.defaultDailyQuantity;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(14.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const CircleAvatar(
                  backgroundColor: Colors.blueAccent,
                  child: Icon(Icons.local_shipping, color: Colors.white, size: 18),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(s.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      Text('${s.providerName} • ₹${s.unitRate.toStringAsFixed(0)}/${s.unitName}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                    ],
                  ),
                ),
                Text(
                  '₹${(currentQty * s.unitRate).toStringAsFixed(0)}',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.blueAccent),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Today\'s Delivery: $currentQty ${s.unitName}', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                Row(
                  children: [
                    IconButton.outlined(
                      icon: const Icon(Icons.remove, size: 16),
                      onPressed: () async {
                        final newQty = (currentQty - 0.5).clamp(0.0, 50.0);
                        await _updateServiceQty(s, newQty);
                      },
                    ),
                    IconButton.filled(
                      icon: const Icon(Icons.add, size: 16),
                      onPressed: () async {
                        final newQty = currentQty + 0.5;
                        await _updateServiceQty(s, newQty);
                      },
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton(
                      onPressed: () => _showSettleServiceDialog(context, s),
                      child: const Text('Settle Bill', style: TextStyle(fontSize: 11)),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _updateServiceQty(RecurringService s, double newQty) async {
    final user = ref.read(userProfileProvider);
    if (user == null) return;
    final repo = ref.read(domesticHelpRepositoryProvider);
    final dateStr = '${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}';

    await repo.recordServiceEntry(
      user.uid,
      ServiceEntry(
        id: ServiceEntry.generateId(s.id, _selectedDate),
        serviceId: s.id,
        householdId: s.householdId,
        date: dateStr,
        quantity: newQty,
        rate: s.unitRate,
        isDelivered: newQty > 0,
      ),
    );
    ref.invalidate(todayServiceEntriesProvider);
  }

  // --- Salary Statements UI ---
  Widget _buildSalaryStatementCard(BuildContext context, SalaryStatement s) {
    final isPaid = s.status == 'paid';

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: isPaid ? Colors.green.shade100 : Colors.amber.shade100,
                  child: Icon(isPaid ? Icons.check_circle : Icons.pending_actions, color: isPaid ? Colors.green : Colors.amber.shade800),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${s.workerName} (${s.month}/${s.year})', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      Text('Base: ₹${s.baseSalary.toStringAsFixed(0)} • Ded: -₹${s.deductions.toStringAsFixed(0)} • Adv Rec: -₹${s.advanceRecovery.toStringAsFixed(0)}', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '₹${s.netPayable.toStringAsFixed(0)}',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                    Text(
                      isPaid ? 'PAID' : (s.paidAmount > 0 ? 'PARTIAL (₹${s.paidAmount.toStringAsFixed(0)})' : 'UNPAID'),
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: isPaid ? Colors.green : Colors.orange),
                    ),
                  ],
                ),
              ],
            ),
            const Divider(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                OutlinedButton.icon(
                  icon: const Icon(Icons.picture_as_pdf_outlined, size: 14),
                  label: const Text('Payslip (PDF)', style: TextStyle(fontSize: 11)),
                  onPressed: () {
                    final workers = ref.read(domesticWorkersProvider).value ?? const [];
                    final worker = workers.where((w) => w.id == s.workerId).firstOrNull;
                    PdfExporter.generateSalaryStatementSlip(s, worker: worker);
                  },
                ),
                if (!isPaid)
                  FilledButton.icon(
                    style: FilledButton.styleFrom(backgroundColor: Colors.green.shade700),
                    icon: const Icon(Icons.payment, size: 14),
                    label: Text('Pay ₹${s.outstandingBalance.toStringAsFixed(0)}'),
                    onPressed: () => _showRecordSalaryPaymentDialog(context, s),
                  )
                else
                  const Chip(
                    avatar: Icon(Icons.check, size: 14, color: Colors.green),
                    label: Text('Settled', style: TextStyle(fontSize: 11, color: Colors.green, fontWeight: FontWeight.bold)),
                    visualDensity: VisualDensity.compact,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // --- Dialogs ---
  void _showAddWorkerDialog(BuildContext context) {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final salaryCtrl = TextEditingController();
    String role = 'Maid';
    int paymentDay = 5;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) => AlertDialog(
          title: const Text('Add Domestic Worker'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Full Name *')),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: role,
                  decoration: const InputDecoration(labelText: 'Job Role *'),
                  items: ['Maid', 'Cook', 'Driver', 'Gardener', 'Babysitter', 'Caretaker', 'Other']
                      .map((r) => DropdownMenuItem(value: r, child: Text(r)))
                      .toList(),
                  onChanged: (v) {
                    if (v != null) setSt(() => role = v);
                  },
                ),
                const SizedBox(height: 8),
                TextField(controller: phoneCtrl, decoration: const InputDecoration(labelText: 'Phone Number')),
                const SizedBox(height: 8),
                TextField(controller: salaryCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Monthly Salary (₹) *')),
                const SizedBox(height: 8),
                TextField(
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(labelText: 'Payment Due Day of Month (e.g. $paymentDay)'),
                  onChanged: (v) => paymentDay = int.tryParse(v) ?? 5,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            FilledButton(
              onPressed: () async {
                final name = nameCtrl.text.trim();
                final sal = double.tryParse(salaryCtrl.text) ?? 0.0;
                if (name.isEmpty || sal <= 0) return;

                final user = ref.read(userProfileProvider);
                if (user == null) return;

                final repo = ref.read(domesticHelpRepositoryProvider);
                await repo.addWorker(
                  user.uid,
                  DomesticWorker(
                    id: const Uuid().v4(),
                    householdId: '',
                    name: name,
                    role: role,
                    phone: phoneCtrl.text.trim(),
                    startDate: DateTime.now(),
                    baseSalary: sal,
                    paymentDueDay: paymentDay,
                  ),
                );
                ref.invalidate(domesticWorkersProvider);
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: const Text('Save Worker'),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddServiceDialog(BuildContext context) {
    final nameCtrl = TextEditingController();
    final providerCtrl = TextEditingController();
    final rateCtrl = TextEditingController();
    String type = 'Milk';
    String unit = 'Litres';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) => AlertDialog(
          title: const Text('Add Recurring Service'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Service Name (e.g. Amul Milk) *')),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: type,
                  decoration: const InputDecoration(labelText: 'Service Type *'),
                  items: ['Milk', 'Newspaper', 'Laundry', 'WaterCan', 'Cleaning', 'Internet', 'Other']
                      .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                      .toList(),
                  onChanged: (v) {
                    if (v != null) {
                      setSt(() {
                        type = v;
                        if (v == 'Milk') unit = 'Litres';
                        if (v == 'WaterCan') unit = 'Cans';
                        if (v == 'Newspaper') unit = 'Papers';
                      });
                    }
                  },
                ),
                const SizedBox(height: 8),
                TextField(controller: providerCtrl, decoration: const InputDecoration(labelText: 'Vendor Name / Contact')),
                const SizedBox(height: 8),
                TextField(controller: rateCtrl, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: 'Rate per $unit (₹) *')),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            FilledButton(
              onPressed: () async {
                final name = nameCtrl.text.trim();
                final rate = double.tryParse(rateCtrl.text) ?? 0.0;
                if (name.isEmpty || rate <= 0) return;

                final user = ref.read(userProfileProvider);
                if (user == null) return;

                final repo = ref.read(domesticHelpRepositoryProvider);
                await repo.addRecurringService(
                  user.uid,
                  RecurringService(
                    id: const Uuid().v4(),
                    householdId: '',
                    name: name,
                    serviceType: type,
                    providerName: providerCtrl.text.trim(),
                    unitRate: rate,
                    unitName: unit,
                  ),
                );
                ref.invalidate(recurringServicesProvider);
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: const Text('Save Service'),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddAdvanceDialog(BuildContext context, DomesticWorker worker) {
    final amountCtrl = TextEditingController();
    final recoveryCtrl = TextEditingController(text: '1000');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Salary Advance for ${worker.name}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: amountCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Advance Amount (₹) *')),
            const SizedBox(height: 8),
            TextField(controller: recoveryCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Monthly Recovery Amount (₹) *')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              final amt = double.tryParse(amountCtrl.text) ?? 0.0;
              final rec = double.tryParse(recoveryCtrl.text) ?? 0.0;
              if (amt <= 0) return;

              final user = ref.read(userProfileProvider);
              if (user == null) return;

              final repo = ref.read(domesticHelpRepositoryProvider);
              await repo.addAdvance(
                user.uid,
                SalaryAdvance(
                  id: const Uuid().v4(),
                  workerId: worker.id,
                  householdId: worker.householdId,
                  amount: amt,
                  date: DateTime.now(),
                  monthlyRecoveryAmount: rec,
                ),
              );
              ref.invalidate(domesticWorkersProvider);
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Record Advance'),
          ),
        ],
      ),
    );
  }

  void _showDraftSalaryForWorker(BuildContext context, DomesticWorker w) async {
    final user = ref.read(userProfileProvider);
    if (user == null) return;

    final repo = ref.read(domesticHelpRepositoryProvider);
    final now = DateTime.now();
    final statement = await repo.calculateSalaryStatement(user.uid, w, now.month, now.year);
    await repo.saveSalaryStatement(user.uid, statement);
    ref.invalidate(salaryStatementsProvider);
    _tabController.animateTo(2); // Switch to Salaries tab
  }

  void _showDraftSalaryDialog(BuildContext context, List<DomesticWorker> workers) {
    if (workers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No registered workers to draft salary for.')));
      return;
    }
    DomesticWorker selectedWorker = workers.first;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) => AlertDialog(
          title: const Text('Calculate Draft Salary'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<DomesticWorker>(
                initialValue: selectedWorker,
                decoration: const InputDecoration(labelText: 'Select Worker'),
                items: workers.map((w) => DropdownMenuItem(value: w, child: Text(w.name))).toList(),
                onChanged: (v) {
                  if (v != null) setSt(() => selectedWorker = v);
                },
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            FilledButton(
              onPressed: () async {
                Navigator.pop(ctx);
                _showDraftSalaryForWorker(context, selectedWorker);
              },
              child: const Text('Calculate & Draft'),
            ),
          ],
        ),
      ),
    );
  }

  void _showRecordSalaryPaymentDialog(BuildContext context, SalaryStatement s) {
    final amountCtrl = TextEditingController(text: s.outstandingBalance.toStringAsFixed(0));
    String method = 'UPI';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Record Salary Payment (${s.workerName})'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Net Payable: ₹${s.netPayable.toStringAsFixed(0)}'),
            Text('Outstanding: ₹${s.outstandingBalance.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
            const SizedBox(height: 12),
            TextField(controller: amountCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Payment Amount (₹)')),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: method,
              decoration: const InputDecoration(labelText: 'Payment Method'),
              items: ['UPI', 'Bank Transfer', 'Cash', 'Cheque'].map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(),
              onChanged: (v) {
                if (v != null) method = v;
              },
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              final amt = double.tryParse(amountCtrl.text) ?? 0.0;
              if (amt <= 0) return;

              final user = ref.read(userProfileProvider);
              if (user == null) return;

              final repo = ref.read(domesticHelpRepositoryProvider);
              await repo.settleSalaryPayment(user.uid, s.id, amt, paymentMethod: method);

              ref.invalidate(salaryStatementsProvider);
              ref.invalidate(financialTransactionsProvider);
              ref.invalidate(domesticWorkersProvider);
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Confirm Payment'),
          ),
        ],
      ),
    );
  }

  void _showSettleServiceDialog(BuildContext context, RecurringService s) {
    final now = DateTime.now();
    final estMonthly = s.defaultDailyQuantity * s.unitRate * 30;
    final amountCtrl = TextEditingController(text: estMonthly.toStringAsFixed(0));

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Settle Bill for ${s.name}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: amountCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Settlement Amount (₹)')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              final amt = double.tryParse(amountCtrl.text) ?? 0.0;
              if (amt <= 0) return;

              final user = ref.read(userProfileProvider);
              if (user == null) return;

              final repo = ref.read(domesticHelpRepositoryProvider);
              await repo.settleServiceBill(user.uid, s.id, s.name, now.month, now.year, amt);

              ref.invalidate(financialTransactionsProvider);
              ref.invalidate(recurringServicesProvider);
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Pay Vendor'),
          ),
        ],
      ),
    );
  }
}
