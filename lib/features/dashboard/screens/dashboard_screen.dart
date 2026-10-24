import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/date_calculators.dart';
import '../../../core/widgets/summary_card.dart';
import '../../../core/widgets/status_badge.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final productsAsync = ref.watch(productsProvider);
    final installmentsAsync = ref.watch(feeInstallmentsProvider);
    final billsAsync = ref.watch(billsProvider);
    final remindersAsync = ref.watch(remindersProvider);

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(productsProvider);
          ref.invalidate(feeInstallmentsProvider);
          ref.invalidate(billsProvider);
          ref.invalidate(remindersProvider);
        },
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Card(
                color: Colors.blue.shade50,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Welcome to Magic Diary 👋',
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Colors.blue.shade900,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Your complete personal life organizer across 8 specialized diary modules.',
                        style: TextStyle(color: Colors.blue.shade800),
                      ),
                      const SizedBox(height: 16),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          ElevatedButton.icon(
                            icon: const Icon(Icons.add),
                            label: const Text('Add Product'),
                            onPressed: () => context.push('/warranty/add'),
                          ),
                          ElevatedButton.icon(
                            icon: const Icon(Icons.directions_car),
                            label: const Text('Vehicle Log'),
                            onPressed: () => context.push('/vehicle'),
                          ),
                          ElevatedButton.icon(
                            icon: const Icon(Icons.account_balance_wallet),
                            label: const Text('Finance'),
                            onPressed: () => context.push('/finance'),
                          ),
                          OutlinedButton.icon(
                            icon: const Icon(Icons.document_scanner),
                            label: const Text('OCR Scanner'),
                            onPressed: () => context.push('/warranty/ocr'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 20),

              Text(
                'Explore All Diary Modules',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: MediaQuery.of(context).size.width > 900 ? 4 : 2,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: 2.2,
                children: [
                  _ModuleCard(
                    title: '1. Personal Diary',
                    icon: Icons.menu_book,
                    color: Colors.purple,
                    onTap: () => context.push('/personal'),
                  ),
                  _ModuleCard(
                    title: '2. Vehicle Diary',
                    icon: Icons.directions_car,
                    color: Colors.red,
                    onTap: () => context.push('/vehicle'),
                  ),
                  _ModuleCard(
                    title: '3. Finance Diary',
                    icon: Icons.account_balance_wallet,
                    color: Colors.green,
                    onTap: () => context.push('/finance'),
                  ),
                  _ModuleCard(
                    title: '4. Household Diary',
                    icon: Icons.home_work,
                    color: Colors.teal,
                    onTap: () => context.push('/household'),
                  ),
                  _ModuleCard(
                    title: '5. Education Diary',
                    icon: Icons.school,
                    color: Colors.deepOrange,
                    onTap: () => context.push('/school-fees'),
                  ),
                  _ModuleCard(
                    title: '6. Property Diary',
                    icon: Icons.apartment,
                    color: Colors.indigo,
                    onTap: () => context.push('/property'),
                  ),
                  _ModuleCard(
                    title: '7. Warranty Diary',
                    icon: Icons.verified,
                    color: Colors.blue,
                    onTap: () => context.push('/warranty'),
                  ),
                  _ModuleCard(
                    title: '8. Bills & Recurring',
                    icon: Icons.receipt_long,
                    color: Colors.orange,
                    onTap: () => context.push('/bills'),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              LayoutBuilder(
                builder: (context, constraints) {
                  final crossAxisCount = constraints.maxWidth > 900
                      ? 4
                      : constraints.maxWidth > 600
                          ? 2
                          : 2;

                  final pendingFeeAmount = installmentsAsync.value
                          ?.where((i) => i.status == 'pending')
                          .fold<double>(0.0, (previousValue, element) => previousValue + element.amount) ??
                      0.0;

                  final pendingBillAmount = billsAsync.value
                          ?.where((b) => b.status == 'unpaid')
                          .fold<double>(0.0, (previousValue, element) => previousValue + element.amount) ??
                      0.0;

                  return GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: crossAxisCount,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 1.35,
                    children: [
                      SummaryCard(
                        title: 'Total Products',
                        value: '${productsAsync.value?.length ?? 0}',
                        subtitle: '${productsAsync.value?.where((p) => p.hasWarranty).length ?? 0} with warranty',
                        icon: Icons.verified,
                        color: Colors.blue,
                        onTap: () => context.push('/warranty'),
                      ),
                      SummaryCard(
                        title: 'Upcoming School Fees',
                        value: AppFormatters.currency(pendingFeeAmount),
                        subtitle: '${installmentsAsync.value?.where((i) => i.status == 'pending').length ?? 0} installments due',
                        icon: Icons.school,
                        color: Colors.purple,
                        onTap: () => context.push('/school-fees'),
                      ),
                      SummaryCard(
                        title: 'Pending Bills',
                        value: AppFormatters.currency(pendingBillAmount),
                        subtitle: '${billsAsync.value?.where((b) => b.status == 'unpaid').length ?? 0} bills pending',
                        icon: Icons.receipt_long,
                        color: Colors.orange,
                        onTap: () => context.push('/bills'),
                      ),
                      SummaryCard(
                        title: 'Active Reminders',
                        value: '${remindersAsync.value?.where((r) => r.status != 'completed').length ?? 0}',
                        subtitle: 'Tap to view schedule',
                        icon: Icons.notifications_active,
                        color: Colors.teal,
                        onTap: () => context.push('/reminders'),
                      ),
                    ],
                  );
                },
              ),

              const SizedBox(height: 24),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      'Expiring Warranties & Services',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  TextButton(
                    onPressed: () => context.push('/warranty'),
                    child: const Text('View All'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              productsAsync.when(
                data: (products) {
                  final activeWarranties = products.where((p) => p.hasWarranty && p.warrantyEndDate != null).toList();
                  if (activeWarranties.isEmpty) {
                    return const Card(
                      child: Padding(
                        padding: EdgeInsets.all(16.0),
                        child: Text('No active warranties tracked.'),
                      ),
                    );
                  }
                  return Column(
                    children: activeWarranties.map((p) {
                      final status = DateCalculators.getWarrantyStatus(p.warrantyEndDate!);
                      final daysLeft = p.warrantyEndDate!.difference(DateTime.now()).inDays;
                      return Card(
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: Colors.blue.shade100,
                            child: const Icon(Icons.devices, color: Colors.blue),
                          ),
                          title: Text(p.name, style: const TextStyle(fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
                          subtitle: Text('${p.brand} • Purchased: ${AppFormatters.date(p.purchaseDate)}', maxLines: 1, overflow: TextOverflow.ellipsis),
                          trailing: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              StatusBadge(status: status),
                              const SizedBox(height: 4),
                              Text(
                                daysLeft >= 0 ? '$daysLeft days left' : 'Expired',
                                style: const TextStyle(fontSize: 11, color: Colors.grey),
                              ),
                            ],
                          ),
                          onTap: () => context.push('/warranty'),
                        ),
                      );
                    }).toList(),
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (err, stack) => Text('Error loading warranties: $err'),
              ),

              const SizedBox(height: 24),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      'Pending Payments & Bills',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  TextButton(
                    onPressed: () => context.push('/bills'),
                    child: const Text('View Bills'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              billsAsync.when(
                data: (bills) {
                  final unpaidBills = bills.where((b) => b.status == 'unpaid').toList();
                  if (unpaidBills.isEmpty) {
                    return const Card(
                      child: Padding(
                        padding: EdgeInsets.all(16.0),
                        child: Text('All recurring bills paid!'),
                      ),
                    );
                  }
                  return Column(
                    children: unpaidBills.map((b) {
                      return Card(
                        child: ListTile(
                          leading: const CircleAvatar(
                            backgroundColor: Colors.orangeAccent,
                            child: Icon(Icons.receipt, color: Colors.white),
                          ),
                          title: Text('Bill (${b.billPeriod})', style: const TextStyle(fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
                          subtitle: Text('Due: ${AppFormatters.date(b.dueDate)}', maxLines: 1, overflow: TextOverflow.ellipsis),
                          trailing: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              FittedBox(
                                child: Text(
                                  AppFormatters.currency(b.amount),
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                ),
                              ),
                              const StatusBadge(status: 'unpaid'),
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
            ],
          ),
        ),
      ),
    );
  }
}

class _ModuleCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _ModuleCard({
    required this.title,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: color.withValues(alpha: 0.15),
                child: Icon(icon, color: color, size: 18),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
