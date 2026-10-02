import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/status_badge.dart';

class HouseholdDashboardScreen extends ConsumerWidget {
  const HouseholdDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final expensesAsync = ref.watch(householdExpensesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Household & Utility Diary'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Recurring Household Utilities',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            expensesAsync.when(
              data: (expenses) {
                if (expenses.isEmpty) {
                  return const Card(
                    child: Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Text('No household expenses listed.'),
                    ),
                  );
                }
                return Column(
                  children: expenses.map((h) {
                    final isPaid = h.status == 'paid';
                    return Card(
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: isPaid ? Colors.green.shade100 : Colors.amber.shade100,
                          child: Icon(
                            _getCategoryIcon(h.category),
                            color: isPaid ? Colors.green.shade800 : Colors.amber.shade900,
                          ),
                        ),
                        title: Text('${h.category} - ${h.providerName}', style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text('${h.period} • Due: ${AppFormatters.date(h.dueDate)}'),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              AppFormatters.currency(h.amount),
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                            ),
                            const SizedBox(height: 2),
                            StatusBadge(status: h.status),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, stack) => Text('Error loading household expenses: $err'),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getCategoryIcon(String category) {
    switch (category) {
      case 'Electricity':
        return Icons.bolt;
      case 'Water':
        return Icons.water_drop;
      case 'Gas':
        return Icons.local_fire_department;
      case 'Internet':
        return Icons.wifi;
      case 'Domestic Help':
        return Icons.cleaning_services;
      default:
        return Icons.home_work;
    }
  }
}
