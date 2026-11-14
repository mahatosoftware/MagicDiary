import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/services/magic_assistant_service.dart';

class MagicInsightsCarousel extends ConsumerWidget {
  const MagicInsightsCarousel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final insights = ref.watch(magicAssistantInsightsProvider);
    if (insights.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.auto_awesome, size: 18, color: Colors.amber),
            const SizedBox(width: 8),
            Text(
              'Magic Assistant Insights',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 130,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: insights.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (ctx, index) {
              final item = insights[index];
              return _buildInsightCard(context, item);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildInsightCard(BuildContext context, MagicInsight item) {
    Color cardBorder;
    Color iconBg;
    Color iconColor;

    switch (item.type) {
      case InsightType.urgent:
        cardBorder = Colors.red.shade300;
        iconBg = Colors.red.shade50;
        iconColor = Colors.red.shade700;
        break;
      case InsightType.warning:
        cardBorder = Colors.amber.shade300;
        iconBg = Colors.amber.shade50;
        iconColor = Colors.amber.shade800;
        break;
      case InsightType.suggestion:
        cardBorder = Colors.blue.shade200;
        iconBg = Colors.blue.shade50;
        iconColor = Colors.blue.shade700;
        break;
      case InsightType.celebration:
        cardBorder = Colors.green.shade300;
        iconBg = Colors.green.shade50;
        iconColor = Colors.green.shade700;
        break;
    }

    return Container(
      width: 290,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cardBorder, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(item.icon, size: 20, color: iconColor),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      item.message,
                      style: TextStyle(
                        fontSize: 11,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          Align(
            alignment: Alignment.bottomRight,
            child: SizedBox(
              height: 28,
              child: FilledButton.tonal(
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                ),
                onPressed: () => context.push(item.actionRoute),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(item.actionLabel),
                    const SizedBox(width: 4),
                    const Icon(Icons.arrow_forward, size: 12),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
