import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/status_badge.dart';
import '../models/household_models.dart';

class HouseholdDashboardScreen extends ConsumerStatefulWidget {
  const HouseholdDashboardScreen({super.key});

  @override
  ConsumerState<HouseholdDashboardScreen> createState() => _HouseholdDashboardScreenState();
}

class _HouseholdDashboardScreenState extends ConsumerState<HouseholdDashboardScreen> {
  String _selectedFilter = 'All'; // 'All', 'Unpaid', 'Paid'
  String _selectedFrequencyFilter = 'All'; // 'All', 'Monthly', 'Quarterly', etc.

  void _showAddExpenseDialog(BuildContext context, {HouseholdExpense? expense}) {
    final user = ref.read(userProfileProvider);
    if (user == null) return;

    final isEditing = expense != null;
    final formKey = GlobalKey<FormState>();
    final providerController = TextEditingController(text: expense?.providerName ?? '');
    final amountController = TextEditingController(
      text: expense != null
          ? (expense.amount % 1 == 0 ? expense.amount.toInt().toString() : expense.amount.toString())
          : '',
    );
    String frequency = expense?.frequency ?? 'Monthly';
    final periodController = TextEditingController(
      text: expense?.period ?? '$frequency - ${DateFormat('MMM yyyy').format(DateTime.now())}',
    );

    String category = expense?.category ?? 'Electricity';
    String status = expense?.status ?? 'unpaid';
    DateTime dueDate = expense?.dueDate ?? DateTime.now().add(const Duration(days: 7));

    final categories = [
      'Electricity',
      'Water',
      'Gas / Cylinder',
      'Internet / Broadband',
      'Mobile Postpaid',
      'Newspaper & Magazines',
      'House Rent',
      'Domestic Help / Maid',
      'Cook',
      'Driver',
      'Society Maintenance Fee',
      'Cable / DTH TV',
      'Waste Management',
      'Milk & Daily Delivery',
      'Other Household',
    ];

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Row(
                children: [
                  const Icon(Icons.home_work, color: Colors.blueAccent),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(isEditing ? 'Edit Household Bill' : 'Add Household Utility / Bill'),
                  ),
                ],
              ),
              content: SizedBox(
                width: 500,
                child: Form(
                  key: formKey,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        DropdownButtonFormField<String>(
                          initialValue: category,
                          decoration: const InputDecoration(
                            labelText: 'Expense Category *',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.category),
                          ),
                          items: categories.map((c) {
                            return DropdownMenuItem(value: c, child: Text(c));
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) setState(() => category = val);
                          },
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          isExpanded: true,
                          initialValue: frequency,
                          decoration: const InputDecoration(
                            labelText: 'Payment Frequency *',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.update),
                          ),
                          items: HouseholdExpense.frequencies.map((f) {
                            return DropdownMenuItem(value: f, child: Text(f));
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) {
                              setState(() {
                                frequency = val;
                                for (final prev in HouseholdExpense.frequencies) {
                                  if (periodController.text.startsWith(prev)) {
                                    periodController.text = '$val - ${DateFormat('MMM yyyy').format(dueDate)}';
                                    break;
                                  }
                                }
                              });
                            }
                          },
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: providerController,
                          decoration: const InputDecoration(
                            labelText: 'Service Provider / Recipient *',
                            hintText: 'e.g., BESCOM, Airtel Xstream, Geeta Bai',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.business),
                          ),
                          validator: (v) => (v == null || v.trim().isEmpty)
                              ? 'Please enter provider or recipient'
                              : null,
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: amountController,
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                decoration: const InputDecoration(
                                  labelText: 'Bill Amount *',
                                  hintText: 'e.g., 2450',
                                  border: OutlineInputBorder(),
                                  prefixIcon: Icon(Icons.currency_rupee),
                                ),
                                validator: (v) {
                                  if (v == null || v.trim().isEmpty) return 'Required';
                                  if (double.tryParse(v.trim()) == null) return 'Invalid number';
                                  return null;
                                },
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                                ),
                                icon: const Icon(Icons.calendar_today, size: 16),
                                label: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text(
                                    'Due Date:\n${DateFormat('dd MMM yyyy').format(dueDate)}',
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                ),
                                onPressed: () async {
                                  final picked = await showDatePicker(
                                    context: context,
                                    initialDate: dueDate,
                                    firstDate: DateTime(2000),
                                    lastDate: DateTime.now().add(const Duration(days: 365)),
                                  );
                                  if (picked != null) setState(() => dueDate = picked);
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: periodController,
                          decoration: const InputDecoration(
                            labelText: 'Billing Period / Cycle *',
                            hintText: 'e.g., Monthly - Oct 2026',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.date_range),
                          ),
                          validator: (v) => (v == null || v.trim().isEmpty)
                              ? 'Please enter billing period'
                              : null,
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 8,
                          runSpacing: 6,
                          children: [
                            const Text('Initial Status: ', style: TextStyle(fontWeight: FontWeight.bold)),
                            ChoiceChip(
                              label: const Text('Unpaid (Pending)'),
                              selected: status == 'unpaid',
                              selectedColor: Colors.amber.shade200,
                              onSelected: (val) {
                                if (val) setState(() => status = 'unpaid');
                              },
                            ),
                            ChoiceChip(
                              label: const Text('Paid'),
                              selected: status == 'paid',
                              selectedColor: Colors.green.shade200,
                              onSelected: (val) {
                                if (val) setState(() => status = 'paid');
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () async {
                    if (!formKey.currentState!.validate()) return;
                    final amount = double.parse(amountController.text.trim());

                    final newExp = HouseholdExpense(
                      id: expense?.id ?? const Uuid().v4(),
                      category: category,
                      providerName: providerController.text.trim(),
                      amount: amount,
                      dueDate: dueDate,
                      status: status,
                      period: periodController.text.trim(),
                      frequency: frequency,
                    );

                    final repo = ref.read(householdRepositoryProvider);
                    await repo.addExpense(user.uid, newExp);
                    ref.invalidate(householdExpensesProvider);

                    if (ctx.mounted) {
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(isEditing
                              ? 'Expense "${newExp.category}" updated!'
                              : 'Expense "${newExp.category}" added!'),
                          backgroundColor: Colors.blueAccent,
                        ),
                      );
                    }
                  },
                  child: Text(isEditing ? 'Update Expense' : 'Save Expense'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showDeleteConfirmation(BuildContext context, HouseholdExpense expense) {
    final user = ref.read(userProfileProvider);
    if (user == null) return;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Expense?'),
        content: Text(
          'Are you sure you want to delete "${expense.category} - ${expense.providerName}" (${AppFormatters.currency(expense.amount)})?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(ctx);
              final repo = ref.read(householdRepositoryProvider);
              await repo.deleteExpense(user.uid, expense.id);
              ref.invalidate(householdExpensesProvider);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Household expense removed.')),
                );
              }
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Future<void> _toggleExpenseStatus(HouseholdExpense expense) async {
    final user = ref.read(userProfileProvider);
    if (user == null) return;

    final newStatus = expense.status.toLowerCase() == 'paid' ? 'unpaid' : 'paid';
    final repo = ref.read(householdRepositoryProvider);
    await repo.updateExpenseStatus(user.uid, expense.id, newStatus);
    ref.invalidate(householdExpensesProvider);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Marked ${expense.category} as ${newStatus == 'paid' ? 'PAID ✓' : 'UNPAID'}',
          ),
          duration: const Duration(seconds: 2),
          backgroundColor: newStatus == 'paid' ? Colors.green.shade800 : Colors.amber.shade900,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final expensesAsync = ref.watch(householdExpensesProvider);
    final theme = Theme.of(context);

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
        title: const Text('Household & Utility Diary'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline),
            tooltip: 'Add Household Expense',
            onPressed: () => _showAddExpenseDialog(context),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddExpenseDialog(context),
        icon: const Icon(Icons.add),
        label: const Text('Add Expense'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Summary Cards Banner
            expensesAsync.when(
              data: (expenses) {
                if (expenses.isEmpty) return const SizedBox.shrink();
                final totalAmount = expenses.fold<double>(0.0, (sum, e) => sum + e.amount);
                final unpaidAmount = expenses
                    .where((e) => e.status.toLowerCase() == 'unpaid')
                    .fold<double>(0.0, (sum, e) => sum + e.amount);
                final paidAmount = expenses
                    .where((e) => e.status.toLowerCase() == 'paid')
                    .fold<double>(0.0, (sum, e) => sum + e.amount);

                return Card(
                  elevation: 0,
                  color: Colors.blue.shade50,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(color: Colors.blue.shade100),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        Expanded(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text('Total Budget', style: TextStyle(fontSize: 12, color: Colors.blueGrey), maxLines: 1),
                              const SizedBox(height: 4),
                              FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  AppFormatters.currency(totalAmount),
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(height: 36, width: 1, color: Colors.blue.shade200),
                        Expanded(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text('Pending Due', style: TextStyle(fontSize: 12, color: Colors.deepOrange), maxLines: 1),
                              const SizedBox(height: 4),
                              FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  AppFormatters.currency(unpaidAmount),
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.deepOrange),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(height: 36, width: 1, color: Colors.blue.shade200),
                        Expanded(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text('Paid', style: TextStyle(fontSize: 12, color: Colors.green), maxLines: 1),
                              const SizedBox(height: 4),
                              FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  AppFormatters.currency(paidAmount),
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.green),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
            ),

            const SizedBox(height: 16),

            // Section Header & Filters
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    'Recurring Household Utilities',
                    style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ),
                TextButton.icon(
                  onPressed: () => _showAddExpenseDialog(context),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Add Expense'),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Filter Chips
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilterChip(
                  label: const Text('All Status'),
                  selected: _selectedFilter == 'All',
                  onSelected: (val) => setState(() => _selectedFilter = 'All'),
                ),
                FilterChip(
                  label: const Text('Pending Due'),
                  selected: _selectedFilter == 'Unpaid',
                  onSelected: (val) => setState(() => _selectedFilter = 'Unpaid'),
                ),
                FilterChip(
                  label: const Text('Paid'),
                  selected: _selectedFilter == 'Paid',
                  onSelected: (val) => setState(() => _selectedFilter = 'Paid'),
                ),
              ],
            ),
            const SizedBox(height: 8),

            expensesAsync.when(
              data: (expenses) {
                if (expenses.isEmpty) {
                  return Card(
                    elevation: 1,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.receipt_long_outlined, size: 52, color: Colors.blue.shade300),
                          const SizedBox(height: 12),
                          const Text(
                            'No household expenses added yet',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'Keep tabs on recurring electricity bills, water, gas cylinders, maid & cook wages, and Wi-Fi subscriptions.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.grey, fontSize: 13),
                          ),
                          const SizedBox(height: 16),
                          FilledButton.icon(
                            onPressed: () => _showAddExpenseDialog(context),
                            icon: const Icon(Icons.add),
                            label: const Text('Add First Household Expense'),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                // Frequency filter row if multiple frequencies exist
                final distinctFreqs = expenses.map((e) => e.frequency).toSet();

                // Apply filter
                final filtered = expenses.where((e) {
                  if (_selectedFilter == 'Unpaid' && e.status.toLowerCase() != 'unpaid') return false;
                  if (_selectedFilter == 'Paid' && e.status.toLowerCase() != 'paid') return false;
                  if (_selectedFrequencyFilter != 'All' && e.frequency != _selectedFrequencyFilter) return false;
                  return true;
                }).toList();

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (distinctFreqs.length > 1) ...[
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            FilterChip(
                              label: const Text('All Frequencies'),
                              selected: _selectedFrequencyFilter == 'All',
                              onSelected: (_) => setState(() => _selectedFrequencyFilter = 'All'),
                            ),
                            const SizedBox(width: 8),
                            ...HouseholdExpense.frequencies
                                .where((f) => distinctFreqs.contains(f))
                                .map((f) => Padding(
                                      padding: const EdgeInsets.only(right: 8.0),
                                      child: FilterChip(
                                        label: Text(f),
                                        selected: _selectedFrequencyFilter == f,
                                        onSelected: (selected) {
                                          setState(() => _selectedFrequencyFilter = selected ? f : 'All');
                                        },
                                      ),
                                    )),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    if (filtered.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 32.0),
                        child: Center(
                          child: Text(
                            'No ${_selectedFilter != 'All' ? _selectedFilter.toLowerCase() : ''} ${_selectedFrequencyFilter != 'All' ? '($_selectedFrequencyFilter)' : ''} expenses found.',
                            style: const TextStyle(color: Colors.grey),
                          ),
                        ),
                      )
                    else
                      ...filtered.map((h) {
                        final isPaid = h.status.toLowerCase() == 'paid';
                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          elevation: 1,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 12.0),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                CircleAvatar(
                                  radius: 20,
                                  backgroundColor: isPaid ? Colors.green.shade100 : Colors.amber.shade100,
                                  child: Icon(
                                    _getCategoryIcon(h.category),
                                    color: isPaid ? Colors.green.shade800 : Colors.amber.shade900,
                                    size: 22,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '${h.category} - ${h.providerName}',
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 3),
                                      Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                            decoration: BoxDecoration(
                                              color: Colors.blue.shade50,
                                              borderRadius: BorderRadius.circular(4),
                                              border: Border.all(color: Colors.blue.shade200, width: 0.8),
                                            ),
                                            child: Text(
                                              h.frequency,
                                              style: TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.blue.shade800,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 6),
                                          Expanded(
                                            child: Text(
                                              '${h.period} • Due: ${DateFormat('dd MMM').format(h.dueDate)}',
                                              style: const TextStyle(color: Colors.grey, fontSize: 12),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 6),
                                      InkWell(
                                        onTap: () => _toggleExpenseStatus(h),
                                        borderRadius: BorderRadius.circular(12),
                                        child: StatusBadge(status: h.status),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    FittedBox(
                                      fit: BoxFit.scaleDown,
                                      child: Text(
                                        AppFormatters.currency(h.amount),
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    PopupMenuButton<String>(
                                      icon: const Icon(Icons.more_vert, size: 20, color: Colors.grey),
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(),
                                      onSelected: (val) {
                                        if (val == 'edit') {
                                          _showAddExpenseDialog(context, expense: h);
                                        } else if (val == 'toggle') {
                                          _toggleExpenseStatus(h);
                                        } else if (val == 'delete') {
                                          _showDeleteConfirmation(context, h);
                                        }
                                      },
                                      itemBuilder: (ctx) => [
                                        const PopupMenuItem(
                                          value: 'edit',
                                          child: Row(
                                            children: [
                                              Icon(Icons.edit_outlined, size: 18, color: Colors.blue),
                                              SizedBox(width: 8),
                                              Text('Edit Expense'),
                                            ],
                                          ),
                                        ),
                                        PopupMenuItem(
                                          value: 'toggle',
                                          child: Row(
                                            children: [
                                              Icon(
                                                isPaid ? Icons.undo : Icons.check_circle_outline,
                                                size: 18,
                                                color: isPaid ? Colors.orange : Colors.green,
                                              ),
                                              const SizedBox(width: 8),
                                              Text(isPaid ? 'Mark as Unpaid' : 'Mark as Paid'),
                                            ],
                                          ),
                                        ),
                                        const PopupMenuItem(
                                          value: 'delete',
                                          child: Row(
                                            children: [
                                              Icon(Icons.delete_outline, size: 18, color: Colors.red),
                                              SizedBox(width: 8),
                                              Text('Delete', style: TextStyle(color: Colors.red)),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      }),
                  ],
                );
              },
              loading: () => const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator())),
              error: (err, stack) => Text('Error loading household expenses: $err'),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getCategoryIcon(String category) {
    if (category.contains('Electricity')) return Icons.bolt;
    if (category.contains('Water')) return Icons.water_drop;
    if (category.contains('Gas')) return Icons.local_fire_department;
    if (category.contains('Internet') || category.contains('Broadband')) return Icons.wifi;
    if (category.contains('Mobile')) return Icons.smartphone;
    if (category.contains('Help') || category.contains('Maid')) return Icons.cleaning_services;
    if (category.contains('Cook')) return Icons.restaurant;
    if (category.contains('Driver')) return Icons.directions_car;
    if (category.contains('Rent')) return Icons.home;
    if (category.contains('Society') || category.contains('Maintenance')) return Icons.apartment;
    if (category.contains('Cable') || category.contains('DTH')) return Icons.tv;
    if (category.contains('Newspaper')) return Icons.newspaper;
    if (category.contains('Milk') || category.contains('Delivery')) return Icons.local_shipping;
    return Icons.home_work;
  }
}
