import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/utils/formatters.dart';

class FinanceDashboardScreen extends ConsumerWidget {
  const FinanceDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final transactionsAsync = ref.watch(financialTransactionsProvider);
    final investmentsAsync = ref.watch(investmentsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Financial Diary & Investments'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Savings & Investments Portfolio',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            investmentsAsync.when(
              data: (investments) {
                if (investments.isEmpty) {
                  return const Card(
                    child: Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Text('No investment records added yet.'),
                    ),
                  );
                }
                final totalValue = investments.fold<double>(0.0, (sum, item) => sum + item.currentAmount);
                return Column(
                  children: [
                    Card(
                      color: Colors.green.shade50,
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Total Portfolio Value',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                            Text(
                              AppFormatters.currency(totalValue),
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 20,
                                color: Colors.green.shade900,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    ...investments.map((inv) {
                      return Card(
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: Colors.green.shade100,
                            child: const Icon(Icons.account_balance_wallet, color: Colors.green),
                          ),
                          title: Text(inv.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text('Type: ${inv.type} • Maturity: ${AppFormatters.date(inv.maturityDate)}'),
                          trailing: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                AppFormatters.currency(inv.currentAmount),
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.green),
                              ),
                              Text(
                                'Invested: ${AppFormatters.currency(inv.investedAmount)}',
                                style: const TextStyle(fontSize: 11, color: Colors.grey),
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                  ],
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, stack) => Text('Error loading investments: $err'),
            ),

            const SizedBox(height: 24),

            Text(
              'Income & Expense Ledger',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            transactionsAsync.when(
              data: (txs) {
                if (txs.isEmpty) {
                  return const Card(
                    child: Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Text('No transactions recorded.'),
                    ),
                  );
                }
                return Column(
                  children: txs.map((t) {
                    final isIncome = t.type == 'Income';
                    return Card(
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: isIncome ? Colors.green.shade100 : Colors.red.shade100,
                          child: Icon(
                            isIncome ? Icons.arrow_downward : Icons.arrow_upward,
                            color: isIncome ? Colors.green : Colors.red,
                          ),
                        ),
                        title: Text(t.description, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text('${t.category} • ${AppFormatters.date(t.date)} (${t.paymentMethod})'),
                        trailing: Text(
                          '${isIncome ? '+' : '-'}${AppFormatters.currency(t.amount)}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: isIncome ? Colors.green : Colors.red.shade800,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, stack) => Text('Error loading transactions: $err'),
            ),
          ],
        ),
      ),
    );
  }
}
