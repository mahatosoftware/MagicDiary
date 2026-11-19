import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/utils/formatters.dart';
import '../models/cash_forecast_models.dart';

class CashForecastScreen extends ConsumerStatefulWidget {
  const CashForecastScreen({super.key});

  @override
  ConsumerState<CashForecastScreen> createState() => _CashForecastScreenState();
}

class _CashForecastScreenState extends ConsumerState<CashForecastScreen> {
  @override
  Widget build(BuildContext context) {
    final summary = ref.watch(cashForecastSummaryProvider);
    final selectedDays = ref.watch(forecastDaysProvider);
    final currentBuffer = ref.watch(forecastSafetyBufferProvider);
    final activeScenario = ref.watch(forecastActiveScenarioProvider);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/payments');
            }
          },
        ),
        title: const Text('Cash Commitment Forecast 📈'),
        actions: [
          IconButton(
            icon: const Icon(Icons.query_stats_rounded),
            tooltip: 'Outflow Forecast (Month • Quarter • Year)',
            onPressed: () => context.push('/outflow-forecast'),
          ),
          IconButton(
            icon: Icon(
              activeScenario != null ? Icons.science : Icons.science_outlined,
              color: activeScenario != null ? Colors.amber : null,
            ),
            tooltip: activeScenario != null ? 'Scenario Active' : 'Simulate Scenario',
            onPressed: () => _showScenarioDialog(context),
          ),
          IconButton(
            icon: const Icon(Icons.account_balance_wallet_outlined),
            tooltip: 'Calibrate Starting Cash',
            onPressed: () => _showCalibrateStartingCashDialog(context, summary.availableCashNow),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(billsProvider);
          ref.invalidate(feeInstallmentsProvider);
          ref.invalidate(householdExpensesProvider);
          ref.invalidate(domesticWorkersProvider);
          ref.invalidate(recurringServicesProvider);
          ref.invalidate(vehiclesProvider);
          ref.invalidate(propertiesProvider);
        },
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 88.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Executive Cash Summary Card
              _buildExecutiveSummaryCard(context, summary),

              const SizedBox(height: 14),

              // 2. Active Scenario Indicator (if enabled)
              if (activeScenario != null) ...[
                _buildActiveScenarioBanner(context, activeScenario),
                const SizedBox(height: 14),
              ],

              // 3. Shortfall Alert Banner (if projected below safety buffer)
              if (summary.hasShortfall) ...[
                _buildShortfallAlertCard(context, summary.shortfalls.first),
                const SizedBox(height: 16),
              ],

              // 4. Time Horizon Selector & Safety Buffer
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  SegmentedButton<int>(
                    segments: const [
                      ButtonSegment(value: 7, label: Text('7 Days', style: TextStyle(fontSize: 11))),
                      ButtonSegment(value: 30, label: Text('30 Days', style: TextStyle(fontSize: 11))),
                      ButtonSegment(value: 90, label: Text('90 Days', style: TextStyle(fontSize: 11))),
                    ],
                    selected: {selectedDays},
                    onSelectionChanged: (val) {
                      ref.read(forecastDaysProvider.notifier).state = val.first;
                    },
                    style: const ButtonStyle(
                      visualDensity: VisualDensity.compact,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                  TextButton.icon(
                    icon: const Icon(Icons.shield_outlined, size: 16),
                    label: Text(
                      currentBuffer > 0 ? 'Buffer: ₹${currentBuffer.toStringAsFixed(0)}' : 'Set Buffer',
                      style: const TextStyle(fontSize: 12),
                    ),
                    onPressed: () => _showSetBufferDialog(context, currentBuffer),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // 5. Section Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Upcoming Commitments (${summary.obligations.length})',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    'Total: ${AppFormatters.currency(summary.totalExpectedCommitments)}',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.red.shade700),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // 6. Chronological List of Forecast Obligations
              if (summary.obligations.isEmpty)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Center(
                      child: Column(
                        children: [
                          const Icon(Icons.check_circle_outline, size: 40, color: Colors.green),
                          const SizedBox(height: 8),
                          const Text('No cash commitments due in this period! 🎉'),
                          const SizedBox(height: 4),
                          Text(
                            'All scheduled bills, salaries, school fees, and loans are fully settled.',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              else
                ...summary.obligations.map((ob) => _buildObligationTile(context, ob)),

              const SizedBox(height: 24),

              // 7. Day-by-Day Balance Projection Timeline
              Text(
                'Day-by-Day Cash Balance Timeline',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              _buildTimelineCard(context, summary.timeline),

              const SizedBox(height: 80),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildExecutiveSummaryCard(BuildContext context, ForecastSummary summary) {
    final isNetPositive = summary.projectedNetFlow >= 0;

    return Card(
      elevation: 0,
      color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.35),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.2)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'AVAILABLE CASH NOW',
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.8, color: Theme.of(context).colorScheme.primary),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      AppFormatters.currency(summary.availableCashNow),
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 22),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'PROJECTED CLOSING',
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.8, color: isNetPositive ? Colors.green.shade800 : Colors.red.shade800),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      AppFormatters.currency(summary.projectedClosingBalance),
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 22, color: isNetPositive ? Colors.green.shade800 : Colors.red.shade800),
                    ),
                  ],
                ),
              ],
            ),
            const Divider(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatPill('Inflows', AppFormatters.currency(summary.totalExpectedIncome), Colors.green),
                _buildStatPill('Outflows', AppFormatters.currency(summary.totalExpectedCommitments), Colors.red),
                _buildStatPill('Net Flow', '${isNetPositive ? "+" : ""}${AppFormatters.currency(summary.projectedNetFlow)}', isNetPositive ? Colors.green : Colors.red),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatPill(String label, String value, Color color) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
        const SizedBox(height: 2),
        Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: color)),
      ],
    );
  }

  Widget _buildShortfallAlertCard(BuildContext context, CashShortfall shortfall) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.red.shade300, width: 1.2),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.warning_amber_rounded, color: Colors.red.shade800, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Projected Cash Shortfall Detected!',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.red.shade900),
                ),
                const SizedBox(height: 4),
                Text(
                  shortfall.explanation,
                  style: TextStyle(fontSize: 12, color: Colors.red.shade900),
                ),
                const SizedBox(height: 6),
                Text(
                  'Deficit: ${AppFormatters.currency(shortfall.deficitAmount)}',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.red.shade800),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveScenarioBanner(BuildContext context, ForecastScenario scenario) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.amber.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.amber.shade400),
      ),
      child: Row(
        children: [
          const Icon(Icons.science, color: Colors.amber, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Scenario: "${scenario.name}" (Simulated)',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.amber.shade900),
            ),
          ),
          TextButton(
            onPressed: () {
              ref.read(forecastActiveScenarioProvider.notifier).state = null;
            },
            child: const Text('Exit Scenario', style: TextStyle(fontSize: 11)),
          ),
        ],
      ),
    );
  }

  Widget _buildObligationTile(BuildContext context, ForecastObligation ob) {
    final isOverdue = ob.isOverdue;

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isOverdue ? Colors.red.shade200 : Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: _getModuleColor(ob.sourceModule).withValues(alpha: 0.15),
          child: Icon(_getModuleIcon(ob.sourceModule), size: 18, color: _getModuleColor(ob.sourceModule)),
        ),
        title: Text(ob.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
        subtitle: Text(
          '${ob.sourceModule} • Due: ${DateFormat('dd MMM').format(ob.dueDate)}${ob.isEstimate ? " (Estimate)" : ""}',
          style: TextStyle(fontSize: 11, color: isOverdue ? Colors.red.shade700 : Colors.grey),
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              AppFormatters.currency(ob.remainingCommitment),
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            if (isOverdue)
              const Text('OVERDUE', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.red)),
          ],
        ),
      ),
    );
  }

  Widget _buildTimelineCard(BuildContext context, List<ForecastDayPoint> timeline) {
    final activeDays = timeline.where((p) => p.inflows > 0 || p.outflows > 0).toList();
    if (activeDays.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Text('No cash transactions scheduled on individual days.'),
        ),
      );
    }

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: activeDays.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (ctx, i) {
          final p = activeDays[i];
          final dateStr = DateFormat('EEE, dd MMM').format(p.date);

          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              children: [
                SizedBox(
                  width: 90,
                  child: Text(dateStr, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: p.eventSummaries.map((e) => Text(e, style: const TextStyle(fontSize: 11))).toList(),
                  ),
                ),
                Text(
                  AppFormatters.currency(p.endingBalance),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: p.endingBalance < 0 ? Colors.red : null,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Color _getModuleColor(String module) {
    switch (module.toLowerCase()) {
      case 'bills':
        return Colors.orange;
      case 'schoolfees':
        return Colors.deepOrange;
      case 'vehicle':
        return Colors.red;
      case 'property':
        return Colors.indigo;
      case 'domestichelp':
        return Colors.teal;
      case 'household':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  IconData _getModuleIcon(String module) {
    switch (module.toLowerCase()) {
      case 'bills':
        return Icons.receipt_long;
      case 'schoolfees':
        return Icons.school;
      case 'vehicle':
        return Icons.directions_car;
      case 'property':
        return Icons.apartment;
      case 'domestichelp':
        return Icons.clean_hands;
      case 'household':
        return Icons.home_repair_service;
      default:
        return Icons.payment;
    }
  }

  void _showCalibrateStartingCashDialog(BuildContext context, double current) {
    final ctrl = TextEditingController(text: current.toStringAsFixed(0));
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Calibrate Starting Cash Balance'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Enter your current available bank/cash balance to project cash flow accurately.',
              style: TextStyle(fontSize: 12),
            ),
            const SizedBox(height: 12),
            TextField(controller: ctrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Available Cash Now (₹)')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              final amt = double.tryParse(ctrl.text);
              if (amt != null) {
                ref.read(forecastManualStartingCashProvider.notifier).state = amt;
              }
              Navigator.pop(ctx);
            },
            child: const Text('Save Balance'),
          ),
        ],
      ),
    );
  }

  void _showSetBufferDialog(BuildContext context, double current) {
    final ctrl = TextEditingController(text: current.toStringAsFixed(0));
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Set Minimum Safety Buffer'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Set a threshold (e.g. ₹10,000). The forecast flags an alert whenever projected cash dips below this buffer.',
              style: TextStyle(fontSize: 12),
            ),
            const SizedBox(height: 12),
            TextField(controller: ctrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Safety Buffer (₹)')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              final buf = double.tryParse(ctrl.text) ?? 0.0;
              ref.read(forecastSafetyBufferProvider.notifier).state = buf;
              Navigator.pop(ctx);
            },
            child: const Text('Set Buffer'),
          ),
        ],
      ),
    );
  }

  void _showScenarioDialog(BuildContext context) {
    int delayDays = 5;
    final expCtrl = TextEditingController(text: '15000');
    final titleCtrl = TextEditingController(text: 'Emergency Medical / Repair');

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) => AlertDialog(
          title: const Text('Simulate What-If Scenario'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Test hypotheticals without modifying your actual records or canonical ledger.',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(height: 12),
                Text('Delay Expected Inflows by: $delayDays days', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                Slider(
                  value: delayDays.toDouble(),
                  min: 0,
                  max: 15,
                  divisions: 15,
                  label: '$delayDays days',
                  onChanged: (val) => setSt(() => delayDays = val.toInt()),
                ),
                const SizedBox(height: 10),
                TextField(controller: titleCtrl, decoration: const InputDecoration(labelText: 'Simulated Extra Expense Title')),
                const SizedBox(height: 8),
                TextField(controller: expCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Simulated Extra Amount (₹)')),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                ref.read(forecastActiveScenarioProvider.notifier).state = null;
                Navigator.pop(ctx);
              },
              child: const Text('Clear Scenario'),
            ),
            FilledButton(
              onPressed: () {
                final amt = double.tryParse(expCtrl.text) ?? 0.0;
                ref.read(forecastActiveScenarioProvider.notifier).state = ForecastScenario(
                  id: 'scenario_user',
                  name: titleCtrl.text.isNotEmpty ? titleCtrl.text : 'Simulated Scenario',
                  delayIncomeDays: delayDays,
                  additionalExpenseAmount: amt,
                  additionalExpenseTitle: titleCtrl.text,
                );
                Navigator.pop(ctx);
              },
              child: const Text('Apply Scenario'),
            ),
          ],
        ),
      ),
    );
  }
}
