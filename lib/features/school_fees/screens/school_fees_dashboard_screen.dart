import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/pdf_exporter.dart';
import '../../../core/widgets/status_badge.dart';

class SchoolFeesDashboardScreen extends ConsumerWidget {
  const SchoolFeesDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final childrenAsync = ref.watch(childrenProvider);
    final installmentsAsync = ref.watch(feeInstallmentsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('School Fees & Education Diary'),
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf),
            tooltip: 'Export Fee Report',
            onPressed: () {
              final children = childrenAsync.value ?? [];
              final installments = installmentsAsync.value ?? [];
              PdfExporter.generateSchoolFeeReport(children, installments);
            },
          ),
          IconButton(
            icon: const Icon(Icons.person_add_alt_1),
            tooltip: 'Add Child',
            onPressed: () => context.go('/school-fees/add-child'),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.go('/school-fees/add-structure'),
        icon: const Icon(Icons.add_card),
        label: const Text('Setup Fee Schedule'),
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
                  'Children Enrolled',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
                TextButton(
                  onPressed: () => context.go('/school-fees/add-child'),
                  child: const Text('+ Add Child'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            childrenAsync.when(
              data: (children) {
                if (children.isEmpty) {
                  return const Card(
                    child: Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Text('No children profiles added yet. Tap "+ Add Child" to begin.'),
                    ),
                  );
                }
                return SizedBox(
                  height: 90,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: children.length,
                    itemBuilder: (context, index) {
                      final c = children[index];
                      return Container(
                        width: 220,
                        margin: const EdgeInsets.only(right: 12),
                        child: Card(
                          color: Colors.purple.shade50,
                          child: Padding(
                            padding: const EdgeInsets.all(12.0),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  backgroundColor: Colors.purple,
                                  child: Text(
                                    c.name[0].toUpperCase(),
                                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        c.name,
                                        style: const TextStyle(fontWeight: FontWeight.bold),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const Text(
                                        'Delhi Public School',
                                        style: TextStyle(fontSize: 12, color: Colors.grey),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
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
              'Fee Installment Schedule',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            installmentsAsync.when(
              data: (installments) {
                if (installments.isEmpty) {
                  return const Card(
                    child: Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Text('No fee structure configured. Tap "Setup Fee Schedule" below.'),
                    ),
                  );
                }

                return Column(
                  children: installments.map((inst) {
                    final isPending = inst.status == 'pending';
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: isPending ? Colors.orange.shade100 : Colors.green.shade100,
                          child: Icon(
                            isPending ? Icons.pending_actions : Icons.check_circle_outline,
                            color: isPending ? Colors.orange.shade800 : Colors.green.shade800,
                          ),
                        ),
                        title: Text(inst.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text('Due Date: ${AppFormatters.date(inst.dueDate)}'),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  AppFormatters.currency(inst.amount),
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                ),
                                StatusBadge(status: inst.status),
                              ],
                            ),
                            const SizedBox(width: 8),
                            if (isPending)
                              IconButton(
                                icon: const Icon(Icons.payment, color: Colors.blue),
                                tooltip: 'Record Payment',
                                onPressed: () {
                                  context.go('/school-fees/record-payment');
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
