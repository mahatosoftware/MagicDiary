import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class SetupChecklistCard extends StatefulWidget {
  final bool hasBills;
  final bool hasDiaries;
  final bool hasAssets;
  final bool hasDocuments;

  const SetupChecklistCard({
    super.key,
    required this.hasBills,
    required this.hasDiaries,
    required this.hasAssets,
    required this.hasDocuments,
  });

  @override
  State<SetupChecklistCard> createState() => _SetupChecklistCardState();
}

class _SetupChecklistCardState extends State<SetupChecklistCard> {
  bool _isDismissed = false;

  @override
  Widget build(BuildContext context) {
    if (_isDismissed) return const SizedBox.shrink();

    final items = [
      _ChecklistItem('Add your first bill or expense', widget.hasBills, '/bills'),
      _ChecklistItem('Log a diary reflection or goal', widget.hasDiaries, '/personal'),
      _ChecklistItem('Register a vehicle or warranty', widget.hasAssets, '/diaries'),
      _ChecklistItem('Upload an ID or invoice document', widget.hasDocuments, '/documents'),
    ];

    final completedCount = items.where((i) => i.isCompleted).length;
    final totalCount = items.length;

    // If all are completed, user does not need to see setup checklist anymore
    if (completedCount == totalCount) return const SizedBox.shrink();

    final progress = completedCount / totalCount;

    return Card(
      elevation: 0,
      color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.35),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.2)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.checklist_rtl, color: Theme.of(context).colorScheme.primary),
                    const SizedBox(width: 8),
                    Text(
                      'Getting Started Checklist',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  onPressed: () => setState(() => _isDismissed = true),
                  tooltip: 'Dismiss checklist',
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              '$completedCount of $totalCount steps completed to set up your personal command center.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 6,
                backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
              ),
            ),
            const SizedBox(height: 12),
            ...items.map((item) {
              return InkWell(
                onTap: item.isCompleted ? null : () => context.push(item.route),
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6.0, horizontal: 4.0),
                  child: Row(
                    children: [
                      Icon(
                        item.isCompleted ? Icons.check_circle : Icons.radio_button_unchecked,
                        color: item.isCompleted ? Colors.green : Colors.grey,
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          item.title,
                          style: TextStyle(
                            decoration: item.isCompleted ? TextDecoration.lineThrough : null,
                            color: item.isCompleted ? Colors.grey : null,
                            fontWeight: item.isCompleted ? FontWeight.normal : FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      if (!item.isCompleted)
                        const Icon(Icons.arrow_forward_ios, size: 12, color: Colors.grey),
                    ],
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

class _ChecklistItem {
  final String title;
  final bool isCompleted;
  final String route;
  _ChecklistItem(this.title, this.isCompleted, this.route);
}
