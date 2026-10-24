import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/pdf_exporter.dart';
import '../../../core/widgets/status_badge.dart';

class SchoolFeesDashboardScreen extends ConsumerStatefulWidget {
  const SchoolFeesDashboardScreen({super.key});

  @override
  ConsumerState<SchoolFeesDashboardScreen> createState() => _SchoolFeesDashboardScreenState();
}

class _SchoolFeesDashboardScreenState extends ConsumerState<SchoolFeesDashboardScreen> {
  String? _selectedFilterChildId;

  @override
  Widget build(BuildContext context) {
    final childrenAsync = ref.watch(childrenProvider);
    final installmentsAsync = ref.watch(feeInstallmentsProvider);
    final children = childrenAsync.asData?.value ?? [];
    final childMap = {for (var c in children) c.id: c};

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
        title: const Text('School Fees & Education Diary'),
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf),
            tooltip: 'Export Fee Report',
            onPressed: () {
              final installments = installmentsAsync.value ?? [];
              PdfExporter.generateSchoolFeeReport(children, installments);
            },
          ),
          IconButton(
            icon: const Icon(Icons.person_add_alt_1),
            tooltip: 'Add Child',
            onPressed: () => context.push('/school-fees/add-child'),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/school-fees/add-structure'),
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
                TextButton.icon(
                  icon: const Icon(Icons.add, size: 18),
                  onPressed: () => context.push('/school-fees/add-child'),
                  label: const Text('Add Child'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            childrenAsync.when(
              data: (childrenList) {
                if (childrenList.isEmpty) {
                  return const Card(
                    child: Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Text('No children profiles added yet. Tap "+ Add Child" to begin.'),
                    ),
                  );
                }
                return SizedBox(
                  height: 96,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: childrenList.length,
                    itemBuilder: (context, index) {
                      final c = childrenList[index];
                      final isSelected = _selectedFilterChildId == c.id;
                      final subtitleText = c.schoolName?.trim().isNotEmpty == true
                          ? (c.grade?.trim().isNotEmpty == true
                              ? '${c.schoolName} • ${c.grade}'
                              : c.schoolName!)
                          : (c.grade?.trim().isNotEmpty == true
                              ? c.grade!
                              : 'No school specified');

                      return Container(
                        width: 250,
                        margin: const EdgeInsets.only(right: 12),
                        child: Card(
                          shape: RoundedRectangleBorder(
                            side: BorderSide(
                              color: isSelected ? Colors.purple : Colors.purple.shade100,
                              width: isSelected ? 2.0 : 1.0,
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          color: isSelected ? Colors.purple.shade100 : Colors.purple.shade50,
                          clipBehavior: Clip.antiAlias,
                          child: InkWell(
                            onTap: () {
                              setState(() {
                                _selectedFilterChildId = isSelected ? null : c.id;
                              });
                            },
                            child: Padding(
                              padding: const EdgeInsets.all(12.0),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    backgroundColor: Colors.purple,
                                    child: Text(
                                      c.name.isNotEmpty ? c.name[0].toUpperCase() : '?',
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
                                        Text(
                                          subtitleText,
                                          style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        if (isSelected)
                                          const Text(
                                            '✓ Showing Schedule',
                                            style: TextStyle(fontSize: 11, color: Colors.purple, fontWeight: FontWeight.w600),
                                          ),
                                      ],
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.edit_outlined, size: 18, color: Colors.purple),
                                    tooltip: 'Edit Child Profile',
                                    onPressed: () => context.push('/school-fees/add-child', extra: c),
                                  ),
                                ],
                              ),
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

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    _selectedFilterChildId != null && childMap.containsKey(_selectedFilterChildId)
                        ? 'Fee Schedule for ${childMap[_selectedFilterChildId]!.name}'
                        : 'Fee Installment Schedule',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ),
                if (_selectedFilterChildId != null)
                  TextButton.icon(
                    icon: const Icon(Icons.clear, size: 16),
                    onPressed: () => setState(() => _selectedFilterChildId = null),
                    label: const Text('Show All'),
                  ),
              ],
            ),
            const SizedBox(height: 8),

            if (children.length > 1) ...[
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    FilterChip(
                      label: const Text('All Children'),
                      selected: _selectedFilterChildId == null,
                      onSelected: (_) => setState(() => _selectedFilterChildId = null),
                    ),
                    const SizedBox(width: 8),
                    ...children.map((c) => Padding(
                          padding: const EdgeInsets.only(right: 8.0),
                          child: FilterChip(
                            avatar: CircleAvatar(
                              backgroundColor: Colors.purple.shade200,
                              child: Text(
                                c.name.isNotEmpty ? c.name[0].toUpperCase() : '?',
                                style: const TextStyle(fontSize: 10, color: Colors.purple),
                              ),
                            ),
                            label: Text(c.name),
                            selected: _selectedFilterChildId == c.id,
                            onSelected: (selected) {
                              setState(() => _selectedFilterChildId = selected ? c.id : null);
                            },
                          ),
                        )),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],

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

                final displayed = _selectedFilterChildId == null
                    ? installments
                    : installments.where((i) => i.childId == _selectedFilterChildId).toList();

                if (displayed.isEmpty) {
                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        children: [
                          const Text('No installments scheduled for this child yet.'),
                          const SizedBox(height: 8),
                          FilledButton.icon(
                            onPressed: () => context.push('/school-fees/add-structure'),
                            icon: const Icon(Icons.add),
                            label: const Text('Setup Fee Schedule'),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return Column(
                  children: displayed.map((inst) {
                    final isPending = inst.status == 'pending';
                    final child = childMap[inst.childId];

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(
                        side: BorderSide(color: Colors.grey.shade200),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4.0),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: isPending ? Colors.orange.shade100 : Colors.green.shade100,
                            child: Icon(
                              isPending ? Icons.pending_actions : Icons.check_circle_outline,
                              color: isPending ? Colors.orange.shade800 : Colors.green.shade800,
                            ),
                          ),
                          title: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                margin: const EdgeInsets.only(bottom: 4),
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.purple.shade50,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.purple.shade200),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.school, size: 12, color: Colors.purple),
                                    const SizedBox(width: 4),
                                    Flexible(
                                      child: Text(
                                        child != null
                                            ? (child.schoolName != null && child.schoolName!.isNotEmpty
                                                ? '${child.name} • ${child.schoolName}'
                                                : child.name)
                                            : 'Child Fee',
                                        style: const TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.purple,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Text(inst.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                            ],
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  const Icon(Icons.event, size: 13, color: Colors.grey),
                                  const SizedBox(width: 4),
                                  Text('Due Date: ${AppFormatters.date(inst.dueDate)}', style: const TextStyle(fontSize: 12)),
                                ],
                              ),
                              if (child?.grade != null && child!.grade!.isNotEmpty) ...[
                                const SizedBox(height: 2),
                                Text('Grade: ${child.grade}', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                              ],
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
                                    context.push('/school-fees/record-payment', extra: inst);
                                  },
                                ),
                            ],
                          ),
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
