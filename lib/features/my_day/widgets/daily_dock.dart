import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'quick_add_sheet.dart';

class DailyDock extends StatelessWidget {
  const DailyDock({super.key});

  @override
  Widget build(BuildContext context) {
    final actions = [
      _DockItem(
        label: 'Journal',
        icon: Icons.edit_note_rounded,
        color: Colors.purple.shade600,
        backgroundColor: Colors.purple.shade50,
        onTap: () => context.push('/personal'),
      ),
      _DockItem(
        label: 'Pay Bill',
        icon: Icons.receipt_long_rounded,
        color: Colors.teal.shade700,
        backgroundColor: Colors.teal.shade50,
        onTap: () => context.push('/bills/record-payment'),
      ),
      _DockItem(
        label: 'Vehicle',
        icon: Icons.directions_car_rounded,
        color: Colors.blue.shade700,
        backgroundColor: Colors.blue.shade50,
        onTap: () => context.push('/vehicle'),
      ),
      _DockItem(
        label: 'Vault',
        icon: Icons.upload_file_rounded,
        color: Colors.amber.shade800,
        backgroundColor: Colors.amber.shade50,
        onTap: () => context.push('/documents'),
      ),
      _DockItem(
        label: 'Add Task',
        icon: Icons.alarm_add_rounded,
        color: Colors.indigo.shade600,
        backgroundColor: Colors.indigo.shade50,
        onTap: () => QuickAddSheet.show(context),
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4.0, bottom: 8.0),
          child: Row(
            children: [
              Icon(Icons.bolt_rounded, size: 16, color: Colors.amber.shade800),
              const SizedBox(width: 4),
              Text(
                'Quick Actions',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade700,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: actions.map((item) {
            return Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3.0),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: item.onTap,
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
                      decoration: BoxDecoration(
                        color: item.backgroundColor,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: item.color.withValues(alpha: 0.25),
                          width: 1,
                        ),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(item.icon, color: item.color, size: 22),
                          const SizedBox(height: 5),
                          Text(
                            item.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: item.color,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}

class _DockItem {
  final String label;
  final IconData icon;
  final Color color;
  final Color backgroundColor;
  final VoidCallback onTap;

  const _DockItem({
    required this.label,
    required this.icon,
    required this.color,
    required this.backgroundColor,
    required this.onTap,
  });
}
