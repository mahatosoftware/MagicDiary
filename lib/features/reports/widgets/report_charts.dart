import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../core/utils/formatters.dart';
import '../models/report_models.dart';

class CategoryDonutChart extends StatelessWidget {
  final List<CategoryBreakdown> breakdowns;
  final double totalExpense;
  final String? selectedCategory;
  final ValueChanged<String?> onSelectCategory;

  const CategoryDonutChart({
    super.key,
    required this.breakdowns,
    required this.totalExpense,
    this.selectedCategory,
    required this.onSelectCategory,
  });

  @override
  Widget build(BuildContext context) {
    if (breakdowns.isEmpty || totalExpense <= 0) {
      return const SizedBox(
        height: 180,
        child: Center(
          child: Text('No expense data to display for this period.', style: TextStyle(color: Colors.grey)),
        ),
      );
    }

    final isNarrow = MediaQuery.of(context).size.width < 500;

    return Column(
      children: [
        SizedBox(
          height: 180,
          child: Stack(
            alignment: Alignment.center,
            children: [
              CustomPaint(
                size: const Size(170, 170),
                painter: _DonutChartPainter(
                  breakdowns: breakdowns,
                  total: totalExpense,
                  selectedCategory: selectedCategory,
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Total Spent', style: TextStyle(fontSize: 11, color: Colors.grey)),
                  const SizedBox(height: 2),
                  Text(
                    AppFormatters.currency(totalExpense),
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        // Category Legends
        Wrap(
          spacing: 8,
          runSpacing: 8,
          alignment: WrapAlignment.center,
          children: breakdowns.map((b) {
            final isSelected = selectedCategory == b.category;
            return InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () {
                onSelectCategory(isSelected ? null : b.category);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: isSelected ? b.color.withValues(alpha: 0.18) : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isSelected ? b.color : Colors.grey.shade300,
                    width: isSelected ? 1.5 : 1.0,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(color: b.color, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '${b.category} (${b.percentage.toStringAsFixed(1)}%)',
                      style: TextStyle(
                        fontSize: isNarrow ? 11 : 12,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                        color: isSelected ? b.color : Colors.black87,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      AppFormatters.currency(b.amount),
                      style: TextStyle(
                        fontSize: isNarrow ? 11 : 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}

class _DonutChartPainter extends CustomPainter {
  final List<CategoryBreakdown> breakdowns;
  final double total;
  final String? selectedCategory;

  _DonutChartPainter({
    required this.breakdowns,
    required this.total,
    this.selectedCategory,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (total <= 0) return;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 12;
    const strokeWidth = 24.0;
    const selectedStrokeWidth = 28.0;

    double startAngle = -math.pi / 2;

    for (final b in breakdowns) {
      final sweepAngle = (b.amount / total) * 2 * math.pi;
      final isSelected = selectedCategory == b.category;

      final paint = Paint()
        ..color = b.color
        ..style = PaintingStyle.stroke
        ..strokeWidth = isSelected ? selectedStrokeWidth : strokeWidth
        ..strokeCap = StrokeCap.butt;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepAngle - 0.04, // slight gap between segments
        false,
        paint,
      );

      startAngle += sweepAngle;
    }
  }

  @override
  bool shouldRepaint(covariant _DonutChartPainter oldDelegate) {
    return oldDelegate.selectedCategory != selectedCategory ||
        oldDelegate.total != total ||
        oldDelegate.breakdowns != breakdowns;
  }
}

/// Income vs Expense comparison widget
class IncomeExpenseComparisonBar extends StatelessWidget {
  final double income;
  final double expense;

  const IncomeExpenseComparisonBar({
    super.key,
    required this.income,
    required this.expense,
  });

  @override
  Widget build(BuildContext context) {
    final maxVal = math.max(income, expense);
    final incomeRatio = maxVal > 0 ? (income / maxVal) : 0.0;
    final expenseRatio = maxVal > 0 ? (expense / maxVal) : 0.0;

    return Column(
      children: [
        // Income Bar
        Row(
          children: [
            const SizedBox(
              width: 70,
              child: Text('Income', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Colors.green)),
            ),
            Expanded(
              child: Stack(
                children: [
                  Container(
                    height: 18,
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(9),
                    ),
                  ),
                  FractionallySizedBox(
                    widthFactor: incomeRatio.clamp(0.02, 1.0),
                    child: Container(
                      height: 18,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(colors: [Colors.green.shade400, Colors.green.shade700]),
                        borderRadius: BorderRadius.circular(9),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            SizedBox(
              width: 85,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerRight,
                child: Text(
                  AppFormatters.currency(income),
                  textAlign: TextAlign.end,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.green),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        // Expense Bar
        Row(
          children: [
            const SizedBox(
              width: 70,
              child: Text('Expenses', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Colors.red)),
            ),
            Expanded(
              child: Stack(
                children: [
                  Container(
                    height: 18,
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(9),
                    ),
                  ),
                  FractionallySizedBox(
                    widthFactor: expenseRatio.clamp(0.02, 1.0),
                    child: Container(
                      height: 18,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(colors: [Colors.red.shade400, Colors.red.shade700]),
                        borderRadius: BorderRadius.circular(9),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            SizedBox(
              width: 85,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerRight,
                child: Text(
                  AppFormatters.currency(expense),
                  textAlign: TextAlign.end,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.red),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Monthly Trends Bar Chart for Multi-Month reports (Quarterly, Half-Yearly, Annual)
class MonthlyTrendBarChart extends StatelessWidget {
  final List<MonthlyTrendPoint> trends;

  const MonthlyTrendBarChart({
    super.key,
    required this.trends,
  });

  @override
  Widget build(BuildContext context) {
    if (trends.isEmpty) return const SizedBox.shrink();

    double maxVal = 0;
    for (final t in trends) {
      if (t.income > maxVal) maxVal = t.income;
      if (t.expense > maxVal) maxVal = t.expense;
    }
    if (maxVal <= 0) maxVal = 1000;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Row(
              children: [
                Container(width: 10, height: 10, decoration: BoxDecoration(color: Colors.green.shade600, borderRadius: BorderRadius.circular(2))),
                const SizedBox(width: 4),
                const Text('Income', style: TextStyle(fontSize: 11, color: Colors.grey)),
              ],
            ),
            const SizedBox(width: 16),
            Row(
              children: [
                Container(width: 10, height: 10, decoration: BoxDecoration(color: Colors.red.shade600, borderRadius: BorderRadius.circular(2))),
                const SizedBox(width: 4),
                const Text('Expense', style: TextStyle(fontSize: 11, color: Colors.grey)),
              ],
            ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 140,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: trends.map((t) {
                final incomeHeight = ((t.income / maxVal) * 100).clamp(4.0, 100.0);
                final expenseHeight = ((t.expense / maxVal) * 100).clamp(4.0, 100.0);

                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Container(
                            width: 14,
                            height: incomeHeight,
                            decoration: BoxDecoration(
                              color: Colors.green.shade600,
                              borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                            ),
                          ),
                          const SizedBox(width: 4),
                          Container(
                            width: 14,
                            height: expenseHeight,
                            decoration: BoxDecoration(
                              color: Colors.red.shade600,
                              borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        t.monthLabel,
                        style: const TextStyle(fontSize: 10, color: Colors.blueGrey, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ),
      ],
    );
  }
}
