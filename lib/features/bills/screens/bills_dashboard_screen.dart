import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/pdf_exporter.dart';
import '../../../core/widgets/status_badge.dart';

class BillsDashboardScreen extends ConsumerWidget {
  const BillsDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accountsAsync = ref.watch(billAccountsProvider);
    final billsAsync = ref.watch(billsProvider);

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
        title: const Text('Bills & Recurring Expenses Diary'),
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf),
            tooltip: 'Export Household Expenses Report',
            onPressed: () {
              final accounts = accountsAsync.value ?? [];
              final bills = billsAsync.value ?? [];
              PdfExporter.generateBillsReport(accounts, bills);
            },
          ),
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Add Bill Account',
            onPressed: () => context.push('/bills/add-account'),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/bills/add-account'),
        icon: const Icon(Icons.post_add),
        label: const Text('Add Account'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Bill Accounts & Subscriptions',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
                TextButton(
                  onPressed: () => context.push('/bills/add-account'),
                  child: const Text('+ Add Account'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            accountsAsync.when(
              data: (accounts) {
                if (accounts.isEmpty) {
                  return const Card(
                    child: Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Text('No recurring bill accounts added.'),
                    ),
                  );
                }
                return SizedBox(
                  height: 110,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: accounts.length,
                    itemBuilder: (context, index) {
                      final acc = accounts[index];
                      return Container(
                        width: 240,
                        margin: const EdgeInsets.only(right: 12),
                        child: Card(
                          color: Colors.orange.shade50,
                          child: Padding(
                            padding: const EdgeInsets.all(12.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 16,
                                      backgroundColor: Colors.orange,
                                      child: Icon(
                                        acc.category == 'Telecom'
                                            ? Icons.wifi
                                            : acc.category == 'Credit Card'
                                                ? Icons.credit_card
                                                : acc.category == 'Newspaper'
                                                    ? Icons.newspaper
                                                    : Icons.receipt,
                                        size: 18,
                                        color: Colors.white,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        acc.name,
                                        style: const TextStyle(fontWeight: FontWeight.bold),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Due on day ${acc.dueDayOfMonth} of month',
                                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                                ),
                                Text(
                                  'Avg: ${AppFormatters.currency(acc.defaultAmount)}',
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
              loading: () => const CircularProgressIndicator(),
              error: (err, stack) => Text('Error: $err'),
            ),

            const SizedBox(height: 24),

            Text(
              'Bills Schedule & History',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            billsAsync.when(
              data: (bills) {
                if (bills.isEmpty) {
                  return const Card(
                    child: Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Text('No bills generated yet.'),
                    ),
                  );
                }

                return Column(
                  children: bills.map((b) {
                    final isUnpaid = b.status == 'unpaid';
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: isUnpaid ? Colors.red.shade100 : Colors.green.shade100,
                          child: Icon(
                            isUnpaid ? Icons.receipt_long : Icons.check_circle,
                            color: isUnpaid ? Colors.red.shade800 : Colors.green.shade800,
                          ),
                        ),
                        title: Text('Bill (${b.billPeriod})', style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Due Date: ${AppFormatters.date(b.dueDate)}'),
                            if (b.notes != null) Text('Notes: ${b.notes}'),
                          ],
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  AppFormatters.currency(b.amount),
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                ),
                                StatusBadge(status: b.status),
                              ],
                            ),
                            const SizedBox(width: 8),
                            if (isUnpaid)
                              IconButton(
                                icon: const Icon(Icons.payment, color: Colors.blue),
                                tooltip: 'Pay Bill',
                                onPressed: () {
                                  context.push('/bills/record-payment');
                                },
                              ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                );
              },
              loading: () => const CircularProgressIndicator(),
              error: (err, stack) => Text('Error: $err'),
            ),
          ],
        ),
      ),
    );
  }
}
