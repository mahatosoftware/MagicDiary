import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/utils/formatters.dart';

class PropertyDashboardScreen extends ConsumerWidget {
  const PropertyDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final propertiesAsync = ref.watch(propertiesProvider);
    final maintenancesAsync = ref.watch(propertyMaintenancesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Home & Property Diary'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'My Properties',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            propertiesAsync.when(
              data: (props) {
                if (props.isEmpty) {
                  return const Card(
                    child: Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Text('No property records added.'),
                    ),
                  );
                }
                return Column(
                  children: props.map((p) {
                    return Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                CircleAvatar(
                                  backgroundColor: Colors.indigo.shade100,
                                  child: const Icon(Icons.home, color: Colors.indigo),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(p.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                      Text(p.address, style: const TextStyle(color: Colors.grey, fontSize: 12)),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const Divider(height: 20),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('Property Tax: ${AppFormatters.currency(p.propertyTaxAmount)}'),
                                Text('Due: ${AppFormatters.date(p.taxDueDate)}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.deepOrange)),
                              ],
                            ),
                            if (p.monthlyRentIncome != null) ...[
                              const SizedBox(height: 4),
                              Text('Rental Income: ${AppFormatters.currency(p.monthlyRentIncome!)} / mo', style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                            ]
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, stack) => Text('Error loading properties: $err'),
            ),

            const SizedBox(height: 24),

            Text(
              'Repairs & Renovations History',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            maintenancesAsync.when(
              data: (maints) {
                if (maints.isEmpty) {
                  return const Card(
                    child: Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Text('No maintenance records.'),
                    ),
                  );
                }
                return Column(
                  children: maints.map((m) {
                    return Card(
                      child: ListTile(
                        leading: const CircleAvatar(
                          backgroundColor: Colors.amberAccent,
                          child: Icon(Icons.handyman, color: Colors.brown),
                        ),
                        title: Text(m.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text('${m.category} • ${AppFormatters.date(m.date)}\nContractor: ${m.contractorName}'),
                        trailing: Text(
                          AppFormatters.currency(m.cost),
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                      ),
                    );
                  }).toList(),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, stack) => Text('Error loading maintenance: $err'),
            ),
          ],
        ),
      ),
    );
  }
}
