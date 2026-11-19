import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/status_badge.dart';
import '../../../core/ads/admob_config.dart';
import '../../../core/ads/widgets/native_ad_card_widget.dart';
import '../../bills/models/bills_models.dart';

class PaymentsHubScreen extends ConsumerWidget {
  const PaymentsHubScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final billsAsync = ref.watch(billsProvider);
    final billAccountsAsync = ref.watch(billAccountsProvider);
    final installmentsAsync = ref.watch(feeInstallmentsProvider);
    final txsAsync = ref.watch(financialTransactionsProvider);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/');
            }
          },
        ),
        title: const Text('My Payments 💳'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_card),
            tooltip: 'Add Bill Account',
            onPressed: () => context.push('/bills/add-account'),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 88.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cash Commitment & Outflow Forecast Shortcut Banners
            Card(
              elevation: 0,
              color: Colors.blue.shade50,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: Colors.blue.shade200),
              ),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.blue.shade100,
                  child: const Icon(Icons.trending_up, color: Colors.blueAccent),
                ),
                title: const Text('Cash Commitment Forecast', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                subtitle: const Text('Understand upcoming cash needs before bills fall due & detect shortfalls', style: TextStyle(fontSize: 12)),
                trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                onTap: () => context.push('/cash-forecast'),
              ),
            ),
            const SizedBox(height: 10),
            Card(
              elevation: 0,
              color: Colors.deepPurple.shade50,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: Colors.deepPurple.shade200),
              ),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.deepPurple.shade100,
                  child: const Icon(Icons.query_stats_rounded, color: Colors.deepPurple),
                ),
                title: const Text('Outflow Forecast (Month • Quarter • Year)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                subtitle: const Text('Project total money outflow across next 30 days, 3 months & 12 months', style: TextStyle(fontSize: 12)),
                trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                onTap: () => context.push('/outflow-forecast'),
              ),
            ),
            const SizedBox(height: 16),

            Text(
              'Bills & Subscriptions Due',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            billsAsync.when(
              data: (bills) {
                if (bills.isEmpty) {
                  return const Card(
                    child: Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Text('No recurring bills listed.'),
                    ),
                  );
                }
                final accountsMap = {
                  for (final a in (billAccountsAsync.valueOrNull ?? <BillAccount>[])) a.id: a,
                };

                return Column(
                  children: bills.map((b) {
                    final isPaid = b.status == 'paid';
                    final acc = accountsMap[b.billAccountId];
                    final billTitle = b.displayTitle(accountName: acc?.name);

                    return Card(
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: isPaid ? Colors.green.shade100 : Colors.orange.shade100,
                          child: Icon(
                            isPaid ? Icons.check_circle : Icons.receipt_long,
                            color: isPaid ? Colors.green : Colors.orange.shade800,
                          ),
                        ),
                        title: Text(billTitle, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text('Due Date: ${AppFormatters.date(b.dueDate)}'),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              AppFormatters.currency(b.amount),
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                            ),
                            const SizedBox(height: 2),
                            StatusBadge(status: b.status),
                          ],
                        ),
                        onTap: () => context.push('/bills'),
                      ),
                    );
                  }).toList(),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, stack) => Text('Error loading bills: $err'),
            ),

            const SizedBox(height: 24),

            Text(
              'Education Fee Installments',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            installmentsAsync.when(
              data: (installments) {
                if (installments.isEmpty) {
                  return const Card(
                    child: Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Text('No fee installments scheduled.'),
                    ),
                  );
                }
                return Column(
                  children: installments.map((i) {
                    return Card(
                      child: ListTile(
                        leading: const CircleAvatar(
                          backgroundColor: Colors.purpleAccent,
                          child: Icon(Icons.school, color: Colors.white),
                        ),
                        title: Text(i.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text('Due: ${AppFormatters.date(i.dueDate)}'),
                        trailing: Text(
                          AppFormatters.currency(i.amount),
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                      ),
                    );
                  }).toList(),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, stack) => Text('Error loading fee installments: $err'),
            ),

            const SizedBox(height: 24),

            Text(
              'Recent Payment History',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            txsAsync.when(
              data: (txs) {
                if (txs.isEmpty) {
                  return const Card(
                    child: Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Text('No recent transaction logs.'),
                    ),
                  );
                }
                return Column(
                  children: txs.map((t) {
                    return Card(
                      child: ListTile(
                        leading: const CircleAvatar(
                          backgroundColor: Colors.blueAccent,
                          child: Icon(Icons.history, color: Colors.white),
                        ),
                        title: Text(t.description, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text('${t.category} • ${AppFormatters.date(t.date)}'),
                        trailing: Text(
                          AppFormatters.currency(t.amount),
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                      ),
                    );
                  }).toList(),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, stack) => Text('Error loading payment history: $err'),
            ),

            const SizedBox(height: 16),
            const NativeAdCardWidget(
              placement: AdMobConfig.placementPaymentsInline,
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
