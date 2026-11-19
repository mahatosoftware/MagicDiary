import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/pdf_exporter.dart';
import '../../../core/widgets/status_badge.dart';
import '../models/bills_models.dart';

class BillsDashboardScreen extends ConsumerStatefulWidget {
  const BillsDashboardScreen({super.key});

  @override
  ConsumerState<BillsDashboardScreen> createState() => _BillsDashboardScreenState();
}

class _BillsDashboardScreenState extends ConsumerState<BillsDashboardScreen> {
  int _selectedTab = 0; // 0: Bills & Utilities, 1: Subscriptions & Free Trials

  IconData _getCategoryIcon(String category, String name) {
    final lowerName = name.toLowerCase();
    final lowerCat = category.toLowerCase();

    if (lowerName.contains('netflix') || lowerName.contains('prime') || lowerName.contains('hotstar') || lowerName.contains('tv')) {
      return Icons.tv_rounded;
    }
    if (lowerName.contains('spotify') || lowerName.contains('music') || lowerName.contains('apple music') || lowerName.contains('youtube music')) {
      return Icons.music_note_rounded;
    }
    if (lowerName.contains('gym') || lowerName.contains('fitness') || lowerName.contains('cult')) {
      return Icons.fitness_center_rounded;
    }
    if (lowerName.contains('gpt') || lowerName.contains('ai') || lowerName.contains('cloud') || lowerName.contains('google one') || lowerName.contains('icloud')) {
      return Icons.cloud_done_rounded;
    }
    if (lowerCat.contains('broadband') || lowerCat.contains('telecom') || lowerCat.contains('internet') || lowerName.contains('airtel') || lowerName.contains('jio')) {
      return Icons.wifi;
    }
    if (lowerCat.contains('electricity') || lowerName.contains('power') || lowerName.contains('electric')) {
      return Icons.bolt_rounded;
    }
    if (lowerCat.contains('credit card') || lowerName.contains('card')) {
      return Icons.credit_card;
    }
    if (lowerCat.contains('water') || lowerCat.contains('gas')) {
      return Icons.water_drop_rounded;
    }
    if (lowerCat.contains('newspaper')) {
      return Icons.newspaper;
    }
    if (lowerCat.contains('subscription')) {
      return Icons.subscriptions_rounded;
    }
    return Icons.receipt_long_rounded;
  }

  Future<void> _launchUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri != null && (uri.scheme == 'http' || uri.scheme == 'https')) {
      try {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } catch (_) {}
    }
  }

  @override
  Widget build(BuildContext context) {
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
        title: const Text('Bills & Recurring Expenses'),
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
            tooltip: _selectedTab == 0 ? 'Add Bill Account' : 'Add Subscription',
            onPressed: () => context.push('/bills/add-account'),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/bills/add-account'),
        icon: Icon(_selectedTab == 0 ? Icons.post_add : Icons.subscriptions),
        label: Text(_selectedTab == 0 ? 'Add Bill Account' : 'Add Subscription'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 88.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Segmented Tab Switcher
            Container(
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade300),
              ),
              padding: const EdgeInsets.all(4),
              child: Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () => setState(() => _selectedTab = 0),
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: _selectedTab == 0 ? Colors.white : Colors.transparent,
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: _selectedTab == 0
                              ? const [BoxShadow(color: Color(0x0F000000), blurRadius: 4, offset: Offset(0, 2))]
                              : null,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.receipt_long, size: 18, color: _selectedTab == 0 ? Colors.orange.shade800 : Colors.grey.shade700),
                            const SizedBox(width: 6),
                            Text(
                              'Bills & Utilities',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: _selectedTab == 0 ? Colors.orange.shade900 : Colors.grey.shade700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: InkWell(
                      onTap: () => setState(() => _selectedTab = 1),
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: _selectedTab == 1 ? Colors.white : Colors.transparent,
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: _selectedTab == 1
                              ? const [BoxShadow(color: Color(0x0F000000), blurRadius: 4, offset: Offset(0, 2))]
                              : null,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.subscriptions_rounded, size: 18, color: _selectedTab == 1 ? Colors.indigo : Colors.grey.shade700),
                            const SizedBox(width: 6),
                            Text(
                              'Subscriptions & Trials',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: _selectedTab == 1 ? Colors.indigo.shade900 : Colors.grey.shade700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            if (_selectedTab == 0) ...[
              _buildBillsTab(context, accountsAsync, billsAsync),
            ] else ...[
              _buildSubscriptionsTab(context, accountsAsync),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildBillsTab(
    BuildContext context,
    AsyncValue<List<BillAccount>> accountsAsync,
    AsyncValue<List<Bill>> billsAsync,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                'Recurring Bill Accounts',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(width: 8),
            TextButton(
              onPressed: () => context.push('/bills/add-account'),
              child: const Text('+ Add Account'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        accountsAsync.when(
          data: (allAccounts) {
            final utilityAccounts = allAccounts.where((a) => !a.isSubscription && a.category != 'Subscription').toList();
            if (utilityAccounts.isEmpty) {
              return const Card(
                child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text('No recurring utility bill accounts added yet. Tap "+ Add Account" to setup Electricity, Broadband, Gas, or Rent.'),
                ),
              );
            }
            return SizedBox(
              height: 125,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: utilityAccounts.length,
                itemBuilder: (context, index) {
                  final acc = utilityAccounts[index];
                  return Container(
                    width: 250,
                    margin: const EdgeInsets.only(right: 12),
                    child: Card(
                      color: Colors.orange.shade50,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
                                    _getCategoryIcon(acc.category, acc.name),
                                    size: 18,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    acc.name,
                                    style: const TextStyle(fontWeight: FontWeight.bold),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Due on day ${acc.dueDayOfMonth} of month',
                              style: const TextStyle(fontSize: 12, color: Colors.grey),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Avg: ${AppFormatters.currency(acc.defaultAmount)}',
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
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

            final accountsMap = {
              for (final a in (accountsAsync.valueOrNull ?? <BillAccount>[])) a.id: a,
            };

            return Column(
              children: bills.map((b) {
                final isUnpaid = b.status == 'unpaid';
                final acc = accountsMap[b.billAccountId];
                final billTitle = b.displayTitle(accountName: acc?.name);
                final categoryIcon = acc != null ? _getCategoryIcon(acc.category, acc.name) : null;

                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 12.0),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        CircleAvatar(
                          radius: 20,
                          backgroundColor: isUnpaid ? Colors.red.shade100 : Colors.green.shade100,
                          child: Icon(
                            categoryIcon ?? (isUnpaid ? Icons.receipt_long : Icons.check_circle),
                            color: isUnpaid ? Colors.red.shade800 : Colors.green.shade800,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                billTitle,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Due Date: ${AppFormatters.date(b.dueDate)}',
                                style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (b.notes != null && b.notes!.isNotEmpty && !b.notes!.startsWith('Auto-generated bill for') && !b.notes!.startsWith('Auto-rolled over for')) ...[
                                const SizedBox(height: 2),
                                Text(
                                  b.notes!,
                                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              AppFormatters.currency(b.amount),
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                            ),
                            const SizedBox(height: 2),
                            StatusBadge(status: b.status),
                          ],
                        ),
                        if (isUnpaid) ...[
                          const SizedBox(width: 4),
                          IconButton(
                            icon: const Icon(Icons.payment, color: Colors.blue),
                            tooltip: 'Pay Bill',
                            visualDensity: VisualDensity.compact,
                            onPressed: () {
                              context.push('/bills/record-payment', extra: b);
                            },
                          ),
                        ],
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
    );
  }

  Widget _buildSubscriptionsTab(
    BuildContext context,
    AsyncValue<List<BillAccount>> accountsAsync,
  ) {
    return accountsAsync.when(
      data: (allAccounts) {
        final subs = allAccounts.where((a) => a.isSubscription || a.category == 'Subscription').toList();
        final now = DateTime.now();

        // 1. Calculate Monthly Commitments
        double monthlyTotal = 0.0;
        int activeCount = 0;
        final endingSoonTrials = <BillAccount>[];

        for (final sub in subs) {
          if (!sub.isActive) continue;
          activeCount++;

          if (sub.subscriptionType == 'paid') {
            final cycle = sub.billingCycle.toLowerCase();
            if (cycle.contains('year')) {
              monthlyTotal += (sub.defaultAmount / 12);
            } else if (cycle.contains('quarter')) {
              monthlyTotal += (sub.defaultAmount / 3);
            } else {
              monthlyTotal += sub.defaultAmount;
            }
          }

          // Check if free trial ends in <= 3 days
          if (sub.subscriptionType == 'free_trial' && sub.trialEndsAt != null) {
            final diffDays = sub.trialEndsAt!.difference(now).inDays;
            if (diffDays <= 3 && !sub.trialEndsAt!.isBefore(now.subtract(const Duration(days: 1)))) {
              endingSoonTrials.add(sub);
            }
          }
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Overview summary card
            Card(
              color: Colors.indigo.shade50,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    const CircleAvatar(
                      radius: 24,
                      backgroundColor: Colors.indigo,
                      child: Icon(Icons.subscriptions_rounded, color: Colors.white, size: 24),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Estimated Monthly Cost',
                            style: TextStyle(fontSize: 12, color: Colors.black54),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            AppFormatters.currency(monthlyTotal),
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Colors.indigo.shade900,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '$activeCount active subscription${activeCount == 1 ? '' : 's'}',
                            style: TextStyle(fontSize: 12, color: Colors.indigo.shade700),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Prominent Free Trial Alert Banner (3 Days Notice)
            if (endingSoonTrials.isNotEmpty) ...[
              ...endingSoonTrials.map((trial) {
                final diffDays = trial.trialEndsAt!.difference(now).inDays;
                final daysText = diffDays <= 0 ? 'ends today!' : 'ends in $diffDays day${diffDays == 1 ? '' : 's'}!';
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.amber.shade400, width: 1.5),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.warning_amber_rounded, color: Colors.amber, size: 28),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Free Trial Alert: ${trial.name}',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Trial $daysText (${AppFormatters.date(trial.trialEndsAt!)}). Cancel now to avoid ${AppFormatters.currency(trial.defaultAmount)} charge.',
                              style: TextStyle(fontSize: 12, color: Colors.grey.shade800),
                            ),
                          ],
                        ),
                      ),
                      if (trial.cancelUrl != null && trial.cancelUrl!.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.amber.shade700,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                          onPressed: () => _launchUrl(trial.cancelUrl!),
                          child: const Text('Cancel URL'),
                        ),
                      ],
                    ],
                  ),
                );
              }),
              const SizedBox(height: 8),
            ],

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    'Tracked Subscriptions',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ),
                TextButton(
                  onPressed: () => context.push('/bills/add-account'),
                  child: const Text('+ Add'),
                ),
              ],
            ),
            const SizedBox(height: 8),

            if (subs.isEmpty) ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(Icons.card_membership_rounded, size: 48, color: Colors.grey.shade400),
                        const SizedBox(height: 12),
                        const Text(
                          'No subscriptions or free trials tracked yet.',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Track Netflix, Spotify, ChatGPT, Gym memberships, or App Trials. We will alert you 3 days before renewal or expiry so you never get surprise charges!',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 13, color: Colors.grey),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: () => context.push('/bills/add-account'),
                          icon: const Icon(Icons.add),
                          label: const Text('Add First Subscription / Trial'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ] else ...[
              Column(
                children: subs.map((sub) {
                  final isTrial = sub.subscriptionType == 'free_trial';
                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 12.0),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          CircleAvatar(
                            radius: 22,
                            backgroundColor: isTrial ? Colors.amber.shade100 : Colors.indigo.shade100,
                            child: Icon(
                              _getCategoryIcon(sub.category, sub.name),
                              color: isTrial ? Colors.amber.shade900 : Colors.indigo.shade800,
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        sub.name,
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 15,
                                          decoration: sub.isActive ? null : TextDecoration.lineThrough,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: isTrial
                                            ? Colors.amber.shade100
                                            : (sub.isActive ? Colors.green.shade50 : Colors.grey.shade200),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        isTrial ? 'FREE TRIAL' : (sub.isActive ? sub.billingCycle.toUpperCase() : 'CANCELLED'),
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          color: isTrial
                                              ? Colors.amber.shade900
                                              : (sub.isActive ? Colors.green.shade800 : Colors.grey.shade700),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 3),
                                if (sub.planTier != null && sub.planTier!.isNotEmpty) ...[
                                  Text(
                                    sub.planTier!,
                                    style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 2),
                                ],
                                Text(
                                  isTrial
                                      ? (sub.trialEndsAt != null
                                          ? 'Trial Expiry: ${AppFormatters.date(sub.trialEndsAt!)}'
                                          : 'Free Trial')
                                      : (sub.renewalDate != null
                                          ? 'Next Renewal: ${AppFormatters.date(sub.renewalDate!)}'
                                          : 'Due: Day ${sub.dueDayOfMonth} of month'),
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isTrial ? Colors.orange.shade800 : Colors.grey.shade600,
                                    fontWeight: isTrial ? FontWeight.bold : FontWeight.normal,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 10),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                AppFormatters.currency(sub.defaultAmount),
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                isTrial ? 'post-trial' : '/ ${sub.billingCycle.toLowerCase()}',
                                style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                              ),
                              if (sub.cancelUrl != null && sub.cancelUrl!.isNotEmpty) ...[
                                const SizedBox(height: 4),
                                InkWell(
                                  onTap: () => _launchUrl(sub.cancelUrl!),
                                  child: const Text(
                                    'Manage / Cancel',
                                    style: TextStyle(fontSize: 11, color: Colors.blue, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ],
        );
      },
      loading: () => const CircularProgressIndicator(),
      error: (err, stack) => Text('Error: $err'),
    );
  }
}
