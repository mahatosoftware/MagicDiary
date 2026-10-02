import 'package:flutter/material.dart';
import '../../config/theme.dart';

class StatusBadge extends StatelessWidget {
  final String status;
  final String? labelOverride;

  const StatusBadge({
    super.key,
    required this.status,
    this.labelOverride,
  });

  @override
  Widget build(BuildContext context) {
    Color color = AppTheme.unknownGray;
    String label = labelOverride ?? status.toUpperCase().replaceAll('_', ' ');

    switch (status.toLowerCase()) {
      case 'active':
      case 'paid':
        color = AppTheme.activeGreen;
        break;
      case 'expiring_soon':
      case 'due':
      case 'partially_paid':
      case 'snoozed':
        color = AppTheme.expiringOrange;
        break;
      case 'expired':
      case 'overdue':
      case 'unpaid':
        color = AppTheme.expiredRed;
        break;
      case 'upcoming':
      case 'pending':
        color = AppTheme.primaryColor;
        break;
      case 'unknown':
      case 'waived':
      default:
        color = AppTheme.unknownGray;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
