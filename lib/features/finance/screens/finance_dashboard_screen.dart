import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/utils/formatters.dart';
import '../models/finance_models.dart';

class FinanceDashboardScreen extends ConsumerWidget {
  const FinanceDashboardScreen({super.key});

  void _showAddInvestmentDialog(BuildContext context, WidgetRef ref) {
    final user = ref.read(userProfileProvider);
    if (user == null) return;

    final formKey = GlobalKey<FormState>();
    final titleController = TextEditingController();
    final investedController = TextEditingController();
    final currentController = TextEditingController();
    final accountController = TextEditingController();

    String investmentType = 'Mutual Funds';
    DateTime maturityDate = DateTime.now().add(const Duration(days: 365 * 3));

    final investmentTypes = [
      'Mutual Funds',
      'SIP',
      'Stocks / Equity',
      'FD (Fixed Deposit)',
      'RD (Recurring Deposit)',
      'PPF / EPF',
      'Gold / SGB',
      'Bonds / Debentures',
      'NPS',
      'Crypto',
      'Real Estate',
      'Other',
    ];

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Row(
                children: [
                  Icon(Icons.trending_up, color: Colors.green),
                  SizedBox(width: 8),
                  Text('Add Investment Asset'),
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
                        TextFormField(
                          controller: titleController,
                          decoration: const InputDecoration(
                            labelText: 'Investment Name / Scheme *',
                            hintText: 'e.g., Parag Parikh Flexi Cap Fund',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.account_balance_wallet),
                          ),
                          validator: (v) => (v == null || v.trim().isEmpty)
                              ? 'Please enter investment name'
                              : null,
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          initialValue: investmentType,
                          decoration: const InputDecoration(
                            labelText: 'Asset Category *',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.category),
                          ),
                          items: investmentTypes.map((t) {
                            return DropdownMenuItem(value: t, child: Text(t));
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) setState(() => investmentType = val);
                          },
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: investedController,
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                decoration: const InputDecoration(
                                  labelText: 'Invested Amount *',
                                  hintText: 'e.g., 50000',
                                  border: OutlineInputBorder(),
                                  prefixIcon: Icon(Icons.currency_rupee),
                                ),
                                validator: (v) {
                                  if (v == null || v.trim().isEmpty) return 'Required';
                                  if (double.tryParse(v.trim()) == null) return 'Invalid number';
                                  return null;
                                },
                                onChanged: (val) {
                                  // Auto-fill current amount if empty
                                  if (currentController.text.isEmpty) {
                                    currentController.text = val;
                                  }
                                },
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextFormField(
                                controller: currentController,
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                decoration: const InputDecoration(
                                  labelText: 'Current Value *',
                                  hintText: 'e.g., 62000',
                                  border: OutlineInputBorder(),
                                  prefixIcon: Icon(Icons.insights),
                                ),
                                validator: (v) {
                                  if (v == null || v.trim().isEmpty) return 'Required';
                                  if (double.tryParse(v.trim()) == null) return 'Invalid number';
                                  return null;
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: accountController,
                                decoration: const InputDecoration(
                                  labelText: 'Folio / Account / Demat #',
                                  hintText: 'e.g., FOLIO-98214',
                                  border: OutlineInputBorder(),
                                  prefixIcon: Icon(Icons.tag),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                                ),
                                icon: const Icon(Icons.event, size: 18),
                                label: Text(
                                  'Maturity:\n${DateFormat('dd MMM yyyy').format(maturityDate)}',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(fontSize: 12),
                                ),
                                onPressed: () async {
                                  final picked = await showDatePicker(
                                    context: context,
                                    initialDate: maturityDate,
                                    firstDate: DateTime(2000),
                                    lastDate: DateTime.now().add(const Duration(days: 3650 * 5)),
                                  );
                                  if (picked != null) setState(() => maturityDate = picked);
                                },
                              ),
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
                    final invested = double.parse(investedController.text.trim());
                    final current = double.parse(currentController.text.trim());

                    final newInv = InvestmentRecord(
                      id: const Uuid().v4(),
                      title: titleController.text.trim(),
                      type: investmentType,
                      investedAmount: invested,
                      currentAmount: current,
                      maturityDate: maturityDate,
                      accountNumber: accountController.text.trim().isNotEmpty
                          ? accountController.text.trim()
                          : 'N/A',
                    );

                    final repo = ref.read(financeRepositoryProvider);
                    await repo.addInvestment(user.uid, newInv);
                    ref.invalidate(investmentsProvider);

                    if (ctx.mounted) {
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Investment "${newInv.title}" saved successfully!'),
                          backgroundColor: Colors.green.shade800,
                        ),
                      );
                    }
                  },
                  child: const Text('Save Investment'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showAddTransactionDialog(
    BuildContext context,
    WidgetRef ref, {
    String initialType = 'Expense',
  }) {
    final user = ref.read(userProfileProvider);
    if (user == null) return;

    final formKey = GlobalKey<FormState>();
    final descController = TextEditingController();
    final amountController = TextEditingController();

    String txType = initialType;
    DateTime txDate = DateTime.now();

    final expenseCategories = [
      'Groceries & Food',
      'Rent & Housing',
      'EMI & Loan Payment',
      'Credit Card Bill',
      'Utilities & Bills',
      'Shopping & Apparel',
      'Dining Out & Cafe',
      'Entertainment & OTT',
      'Healthcare & Medicines',
      'Travel, Fuel & Cab',
      'Subscriptions',
      'Education & Courses',
      'Investment Deposit',
      'Charity & Gifts',
      'Other Expense',
    ];

    final incomeCategories = [
      'Salary',
      'Business / Freelance',
      'Rental Income',
      'Investment Returns & Dividend',
      'Interest',
      'Cashback & Refunds',
      'Bonus / Incentives',
      'Gift / Family Transfer',
      'Other Income',
    ];

    String selectedCategory = txType == 'Income' ? 'Salary' : 'Groceries & Food';

    final paymentMethods = [
      'UPI (GPay / PhonePe / Paytm)',
      'Credit Card',
      'Debit Card',
      'Net Banking / IMPS',
      'Cash',
      'Cheque',
      'Other',
    ];

    String paymentMethod = 'UPI (GPay / PhonePe / Paytm)';

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setState) {
            final activeCategories = txType == 'Income' ? incomeCategories : expenseCategories;
            if (!activeCategories.contains(selectedCategory)) {
              selectedCategory = activeCategories.first;
            }

            return AlertDialog(
              title: Row(
                children: [
                  Icon(
                    txType == 'Income' ? Icons.arrow_downward : Icons.arrow_upward,
                    color: txType == 'Income' ? Colors.green : Colors.red,
                  ),
                  const SizedBox(width: 8),
                  Text('Add ${txType == 'Income' ? 'Income' : 'Expense'} Entry'),
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
                        // Income / Expense Toggle
                        Center(
                          child: SegmentedButton<String>(
                            segments: const [
                              ButtonSegment(
                                value: 'Expense',
                                label: Text('Expense'),
                                icon: Icon(Icons.arrow_upward, color: Colors.red),
                              ),
                              ButtonSegment(
                                value: 'Income',
                                label: Text('Income'),
                                icon: Icon(Icons.arrow_downward, color: Colors.green),
                              ),
                            ],
                            selected: {txType},
                            onSelectionChanged: (val) {
                              setState(() {
                                txType = val.first;
                                selectedCategory =
                                    txType == 'Income' ? incomeCategories.first : expenseCategories.first;
                              });
                            },
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: descController,
                          decoration: InputDecoration(
                            labelText: 'Description / Note *',
                            hintText: txType == 'Income'
                                ? 'e.g., Monthly Salary - Oct'
                                : 'e.g., Weekly Supermarket Grocery',
                            border: const OutlineInputBorder(),
                            prefixIcon: const Icon(Icons.edit_note),
                          ),
                          validator: (v) => (v == null || v.trim().isEmpty)
                              ? 'Please enter description'
                              : null,
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          key: ValueKey(txType),
                          initialValue: selectedCategory,
                          decoration: const InputDecoration(
                            labelText: 'Category *',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.category),
                          ),
                          items: activeCategories.map((c) {
                            return DropdownMenuItem(value: c, child: Text(c));
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) setState(() => selectedCategory = val);
                          },
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: amountController,
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                decoration: const InputDecoration(
                                  labelText: 'Amount *',
                                  hintText: 'e.g., 1850',
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
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                                ),
                                icon: const Icon(Icons.calendar_today, size: 18),
                                label: Text(
                                  'Date:\n${DateFormat('dd MMM yyyy').format(txDate)}',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(fontSize: 12),
                                ),
                                onPressed: () async {
                                  final picked = await showDatePicker(
                                    context: context,
                                    initialDate: txDate,
                                    firstDate: DateTime(2000),
                                    lastDate: DateTime.now(),
                                  );
                                  if (picked != null) setState(() => txDate = picked);
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          initialValue: paymentMethod,
                          decoration: const InputDecoration(
                            labelText: 'Payment Method *',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.payment),
                          ),
                          items: paymentMethods.map((m) {
                            return DropdownMenuItem(value: m, child: Text(m));
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) setState(() => paymentMethod = val);
                          },
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
                  style: FilledButton.styleFrom(
                    backgroundColor: txType == 'Income' ? Colors.green.shade700 : Colors.red.shade700,
                  ),
                  onPressed: () async {
                    if (!formKey.currentState!.validate()) return;
                    final amount = double.parse(amountController.text.trim());

                    final newTx = FinancialTransaction(
                      id: const Uuid().v4(),
                      type: txType,
                      category: selectedCategory,
                      amount: amount,
                      date: txDate,
                      description: descController.text.trim(),
                      paymentMethod: paymentMethod,
                    );

                    final repo = ref.read(financeRepositoryProvider);
                    await repo.addTransaction(user.uid, newTx);
                    ref.invalidate(financialTransactionsProvider);

                    if (ctx.mounted) {
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('$txType "${newTx.description}" recorded!'),
                          backgroundColor: txType == 'Income' ? Colors.green.shade800 : Colors.blueGrey,
                        ),
                      );
                    }
                  },
                  child: Text('Save $txType'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showDeleteTransactionConfirmation(
      BuildContext context, WidgetRef ref, FinancialTransaction tx) {
    final user = ref.read(userProfileProvider);
    if (user == null) return;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Transaction?'),
        content: Text('Are you sure you want to delete "${tx.description}" (${AppFormatters.currency(tx.amount)})?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(ctx);
              final repo = ref.read(financeRepositoryProvider);
              await repo.deleteTransaction(user.uid, tx.id);
              ref.invalidate(financialTransactionsProvider);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Transaction deleted.')),
                );
              }
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _showDeleteInvestmentConfirmation(
      BuildContext context, WidgetRef ref, InvestmentRecord inv) {
    final user = ref.read(userProfileProvider);
    if (user == null) return;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Investment Asset?'),
        content: Text('Are you sure you want to remove "${inv.title}" from your portfolio?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(ctx);
              final repo = ref.read(financeRepositoryProvider);
              await repo.deleteInvestment(user.uid, inv.id);
              ref.invalidate(investmentsProvider);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Investment removed.')),
                );
              }
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final transactionsAsync = ref.watch(financialTransactionsProvider);
    final investmentsAsync = ref.watch(investmentsProvider);
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
        title: const Text('Financial Diary & Investments'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_chart_outlined),
            tooltip: 'Add Investment',
            onPressed: () => _showAddInvestmentDialog(context, ref),
          ),
          IconButton(
            icon: const Icon(Icons.add_circle_outline),
            tooltip: 'Add Transaction',
            onPressed: () => _showAddTransactionDialog(context, ref),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          showModalBottomSheet(
            context: context,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            builder: (ctx) => SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 16.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ListTile(
                      leading: const CircleAvatar(
                        backgroundColor: Colors.red,
                        child: Icon(Icons.arrow_upward, color: Colors.white),
                      ),
                      title: const Text('Record Expense', style: TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: const Text('Log groceries, rent, shopping, dining, bills, or EMI'),
                      onTap: () {
                        Navigator.pop(ctx);
                        _showAddTransactionDialog(context, ref, initialType: 'Expense');
                      },
                    ),
                    const Divider(),
                    ListTile(
                      leading: const CircleAvatar(
                        backgroundColor: Colors.green,
                        child: Icon(Icons.arrow_downward, color: Colors.white),
                      ),
                      title: const Text('Record Income', style: TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: const Text('Log salary, business earnings, dividend, or freelance payments'),
                      onTap: () {
                        Navigator.pop(ctx);
                        _showAddTransactionDialog(context, ref, initialType: 'Income');
                      },
                    ),
                    const Divider(),
                    ListTile(
                      leading: const CircleAvatar(
                        backgroundColor: Colors.teal,
                        child: Icon(Icons.trending_up, color: Colors.white),
                      ),
                      title: const Text('Add Investment Asset', style: TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: const Text('Track Mutual Funds, SIP, Stocks, FD, PPF, or Gold'),
                      onTap: () {
                        Navigator.pop(ctx);
                        _showAddInvestmentDialog(context, ref);
                      },
                    ),
                  ],
                ),
              ),
            ),
          );
        },
        icon: const Icon(Icons.add),
        label: const Text('Record Finance'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cash Flow Banner (from Transactions)
            transactionsAsync.when(
              data: (txs) {
                if (txs.isEmpty) return const SizedBox.shrink();
                final totalIncome = txs
                    .where((t) => t.type == 'Income')
                    .fold<double>(0.0, (sum, t) => sum + t.amount);
                final totalExpense = txs
                    .where((t) => t.type == 'Expense')
                    .fold<double>(0.0, (sum, t) => sum + t.amount);
                final netCashflow = totalIncome - totalExpense;

                return Card(
                  elevation: 0,
                  color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5)),
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
                              const Text('Total Inflow', style: TextStyle(fontSize: 12, color: Colors.grey), maxLines: 1),
                              const SizedBox(height: 4),
                              FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  AppFormatters.currency(totalIncome),
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.green),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(height: 36, width: 1, color: Colors.grey.shade300),
                        Expanded(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text('Total Outflow', style: TextStyle(fontSize: 12, color: Colors.grey), maxLines: 1),
                              const SizedBox(height: 4),
                              FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  AppFormatters.currency(totalExpense),
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.red.shade700),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(height: 36, width: 1, color: Colors.grey.shade300),
                        Expanded(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text('Net Savings', style: TextStyle(fontSize: 12, color: Colors.grey), maxLines: 1),
                              const SizedBox(height: 4),
                              FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  AppFormatters.currency(netCashflow),
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                    color: netCashflow >= 0 ? Colors.green.shade800 : Colors.red.shade800,
                                  ),
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

            // Section 1: Savings & Investments Portfolio
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    'Savings & Investments Portfolio',
                    style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ),
                TextButton.icon(
                  onPressed: () => _showAddInvestmentDialog(context, ref),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Add Asset'),
                ),
              ],
            ),
            const SizedBox(height: 8),

            investmentsAsync.when(
              data: (investments) {
                if (investments.isEmpty) {
                  return Card(
                    elevation: 1,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.savings_outlined, size: 52, color: Colors.green.shade300),
                          const SizedBox(height: 12),
                          const Text(
                            'No investment records added yet',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'Track your Mutual Funds SIPs, Fixed Deposits, Stocks, PPF, and Gold in one centralized ledger.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.grey, fontSize: 13),
                          ),
                          const SizedBox(height: 16),
                          FilledButton.icon(
                            style: FilledButton.styleFrom(backgroundColor: Colors.teal.shade700),
                            onPressed: () => _showAddInvestmentDialog(context, ref),
                            icon: const Icon(Icons.add),
                            label: const Text('Add First Investment'),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                final totalInvested = investments.fold<double>(0.0, (sum, item) => sum + item.investedAmount);
                final totalValue = investments.fold<double>(0.0, (sum, item) => sum + item.currentAmount);
                final gain = totalValue - totalInvested;
                final gainPercentage = totalInvested > 0 ? (gain / totalInvested) * 100 : 0.0;

                return Column(
                  children: [
                    Card(
                      color: Colors.green.shade50,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(color: Colors.green.shade200),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Total Portfolio Value',
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.black87),
                                  ),
                                  const SizedBox(height: 4),
                                  FittedBox(
                                    fit: BoxFit.scaleDown,
                                    alignment: Alignment.centerLeft,
                                    child: Text(
                                      AppFormatters.currency(totalValue),
                                      style: TextStyle(
                                        fontWeight: FontWeight.w800,
                                        fontSize: 22,
                                        color: Colors.green.shade900,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  'Invested: ${AppFormatters.currency(totalInvested)}',
                                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                                ),
                                const SizedBox(height: 4),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: gain >= 0 ? Colors.green.shade100 : Colors.red.shade100,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    '${gain >= 0 ? '+' : ''}${gainPercentage.toStringAsFixed(1)}% (${AppFormatters.currency(gain)})',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: gain >= 0 ? Colors.green.shade800 : Colors.red.shade800,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    ...investments.map((inv) {
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: Colors.green.shade100,
                            child: Icon(_getInvestmentIcon(inv.type), color: Colors.green.shade800),
                          ),
                          title: Text(inv.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text(
                            'Type: ${inv.type} • Folio: ${inv.accountNumber}\nMaturity: ${DateFormat('dd MMM yyyy').format(inv.maturityDate)}',
                          ),
                          isThreeLine: true,
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: Text(
                                      AppFormatters.currency(inv.currentAmount),
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.green),
                                    ),
                                  ),
                                  Text(
                                    'Invested: ${AppFormatters.currency(inv.investedAmount)}',
                                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                                  ),
                                ],
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline, size: 18, color: Colors.grey),
                                tooltip: 'Delete',
                                onPressed: () => _showDeleteInvestmentConfirmation(context, ref, inv),
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
              error: (err, stack) => Text('Error loading investments: $err'),
            ),

            const SizedBox(height: 28),

            // Section 2: Income & Expense Ledger
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    'Income & Expense Ledger',
                    style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ),
                TextButton.icon(
                  onPressed: () => _showAddTransactionDialog(context, ref),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Add Entry'),
                ),
              ],
            ),
            const SizedBox(height: 8),

            transactionsAsync.when(
              data: (txs) {
                if (txs.isEmpty) {
                  return Card(
                    elevation: 1,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.receipt_long_outlined, size: 48, color: Colors.blueGrey.shade300),
                          const SizedBox(height: 12),
                          const Text(
                            'No transactions recorded yet',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'Record your daily expenses, salary credits, rental income, and bill payments.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.grey, fontSize: 13),
                          ),
                          const SizedBox(height: 16),
                          Wrap(
                            alignment: WrapAlignment.center,
                            spacing: 12,
                            runSpacing: 8,
                            children: [
                              FilledButton.tonalIcon(
                                onPressed: () => _showAddTransactionDialog(context, ref, initialType: 'Expense'),
                                icon: const Icon(Icons.arrow_upward, color: Colors.red),
                                label: const Text('Add Expense'),
                              ),
                              FilledButton.tonalIcon(
                                onPressed: () => _showAddTransactionDialog(context, ref, initialType: 'Income'),
                                icon: const Icon(Icons.arrow_downward, color: Colors.green),
                                label: const Text('Add Income'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                }
                return Column(
                  children: txs.map((t) {
                    final isIncome = t.type == 'Income';
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      elevation: 1,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: isIncome ? Colors.green.shade100 : Colors.red.shade100,
                          child: Icon(
                            isIncome ? Icons.arrow_downward : Icons.arrow_upward,
                            color: isIncome ? Colors.green.shade800 : Colors.red.shade800,
                          ),
                        ),
                        title: Text(t.description, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text(
                          '${t.category} • ${DateFormat('dd MMM yyyy').format(t.date)}\nVia ${t.paymentMethod}',
                        ),
                        isThreeLine: true,
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                '${isIncome ? '+' : '-'}${AppFormatters.currency(t.amount)}',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                  color: isIncome ? Colors.green.shade800 : Colors.red.shade800,
                                ),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, size: 18, color: Colors.grey),
                              tooltip: 'Delete',
                              onPressed: () => _showDeleteTransactionConfirmation(context, ref, t),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                );
              },
              loading: () => const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator())),
              error: (err, stack) => Text('Error loading transactions: $err'),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getInvestmentIcon(String type) {
    switch (type) {
      case 'Mutual Funds':
      case 'SIP':
        return Icons.pie_chart;
      case 'Stocks / Equity':
        return Icons.candlestick_chart;
      case 'FD (Fixed Deposit)':
      case 'RD (Recurring Deposit)':
        return Icons.lock_clock;
      case 'Gold / SGB':
        return Icons.workspace_premium;
      case 'PPF / EPF':
      case 'NPS':
        return Icons.shield;
      case 'Crypto':
        return Icons.currency_bitcoin;
      case 'Real Estate':
        return Icons.domain;
      default:
        return Icons.account_balance_wallet;
    }
  }
}
