import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/utils/formatters.dart';
import '../models/outflow_forecast_models.dart';
import '../services/outflow_forecast_service.dart';

class OutflowForecastScreen extends ConsumerStatefulWidget {
  const OutflowForecastScreen({super.key});

  @override
  ConsumerState<OutflowForecastScreen> createState() => _OutflowForecastScreenState();
}

class _OutflowForecastScreenState extends ConsumerState<OutflowForecastScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedCategoryFilter = 'All';
  DateTime? _selectedMonthFilter;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final activeHorizon = ref.watch(selectedOutflowHorizonProvider);
    final allReports = ref.watch(outflowForecastReportsProvider);
    final report = allReports[activeHorizon]!;

    final monthReport = allReports[OutflowHorizon.month]!;
    final quarterReport = allReports[OutflowHorizon.quarter]!;
    final yearReport = allReports[OutflowHorizon.year]!;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/payments');
            }
          },
        ),
        title: const Text('Outflow Forecast 💸'),
        actions: [
          IconButton(
            icon: const Icon(Icons.account_balance_wallet_outlined),
            tooltip: 'Cash Flow Simulator',
            onPressed: () => context.push('/cash-forecast'),
          ),
          IconButton(
            icon: const Icon(Icons.info_outline_rounded),
            tooltip: 'About Forecast',
            onPressed: () => _showForecastInfoDialog(context),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(billsProvider);
          ref.invalidate(billAccountsProvider);
          ref.invalidate(feeInstallmentsProvider);
          ref.invalidate(vehiclesProvider);
          ref.invalidate(propertiesProvider);
          ref.invalidate(domesticWorkersProvider);
          ref.invalidate(recurringServicesProvider);
          ref.invalidate(householdExpensesProvider);
          ref.invalidate(remindersProvider);
          ref.invalidate(productsProvider);
        },
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16.0, 12.0, 16.0, 88.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Multi-Horizon Quick Comparison Strip
              _buildHorizonCardsRow(
                context,
                activeHorizon,
                monthReport.totalOutflow,
                quarterReport.totalOutflow,
                yearReport.totalOutflow,
              ),

              const SizedBox(height: 14),

              // 2. Horizon Segmented Selector
              SegmentedButton<OutflowHorizon>(
                segments: const [
                  ButtonSegment(
                    value: OutflowHorizon.month,
                    label: Text('Next Month', style: TextStyle(fontSize: 11.5)),
                    icon: Icon(Icons.calendar_view_month_rounded, size: 16),
                  ),
                  ButtonSegment(
                    value: OutflowHorizon.quarter,
                    label: Text('Next Quarter', style: TextStyle(fontSize: 11.5)),
                    icon: Icon(Icons.pie_chart_outline_rounded, size: 16),
                  ),
                  ButtonSegment(
                    value: OutflowHorizon.year,
                    label: Text('Next Year', style: TextStyle(fontSize: 11.5)),
                    icon: Icon(Icons.calendar_today_rounded, size: 16),
                  ),
                ],
                selected: {activeHorizon},
                onSelectionChanged: (val) {
                  setState(() {
                    _selectedMonthFilter = null;
                    _selectedCategoryFilter = 'All';
                  });
                  ref.read(selectedOutflowHorizonProvider.notifier).state = val.first;
                },
                style: const ButtonStyle(
                  visualDensity: VisualDensity.compact,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),

              const SizedBox(height: 14),

              // 3. Active Horizon Executive Summary Card
              _buildExecutiveSummaryCard(context, report),

              const SizedBox(height: 16),

              // 4. Month-by-Month Trend Visualizer (for Quarter and Year)
              if (activeHorizon != OutflowHorizon.month && report.monthlyTrend.isNotEmpty) ...[
                _buildMonthlyTrendSection(context, report),
                const SizedBox(height: 16),
              ],

              // 5. Category Breakdown Section
              _buildCategoryBreakdownSection(context, report),

              const SizedBox(height: 16),

              // 6. Itemized Commitments Header & Filters
              _buildCommitmentsLedgerHeader(context, report),

              const SizedBox(height: 10),

              // Search Bar
              TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search commitments (e.g. EMI, BESCOM, School)...',
                  prefixIcon: const Icon(Icons.search_rounded, size: 20),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded, size: 18),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _searchQuery = '');
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 0),
                ),
                onChanged: (val) => setState(() => _searchQuery = val.trim()),
              ),

              const SizedBox(height: 10),

              // Category Filter Pills
              _buildCategoryFilterPills(report),

              const SizedBox(height: 12),

              // Active Filters Reset Strip (if month or category filter active)
              if (_selectedMonthFilter != null || _selectedCategoryFilter != 'All' || _searchQuery.isNotEmpty)
                _buildActiveFilterChips(),

              // 7. Filtered Obligations List
              _buildObligationsList(context, report),

              const SizedBox(height: 16),

              // 8. Smart Planning Insight Card
              _buildPlanningInsightCard(context, report),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 1. MULTI-HORIZON COMPARISON ROW
  // ---------------------------------------------------------------------------
  Widget _buildHorizonCardsRow(
    BuildContext context,
    OutflowHorizon active,
    double monthTotal,
    double quarterTotal,
    double yearTotal,
  ) {
    return Row(
      children: [
        Expanded(
          child: _buildHorizonMiniCard(
            context: context,
            label: 'Next Month',
            sublabel: '30 Days',
            amount: monthTotal,
            isSelected: active == OutflowHorizon.month,
            color: Colors.blue,
            onTap: () {
              setState(() {
                _selectedMonthFilter = null;
                _selectedCategoryFilter = 'All';
              });
              ref.read(selectedOutflowHorizonProvider.notifier).state = OutflowHorizon.month;
            },
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildHorizonMiniCard(
            context: context,
            label: 'Next Quarter',
            sublabel: '3 Months',
            amount: quarterTotal,
            isSelected: active == OutflowHorizon.quarter,
            color: Colors.indigo,
            onTap: () {
              setState(() {
                _selectedMonthFilter = null;
                _selectedCategoryFilter = 'All';
              });
              ref.read(selectedOutflowHorizonProvider.notifier).state = OutflowHorizon.quarter;
            },
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildHorizonMiniCard(
            context: context,
            label: 'Next Year',
            sublabel: '12 Months',
            amount: yearTotal,
            isSelected: active == OutflowHorizon.year,
            color: Colors.deepPurple,
            onTap: () {
              setState(() {
                _selectedMonthFilter = null;
                _selectedCategoryFilter = 'All';
              });
              ref.read(selectedOutflowHorizonProvider.notifier).state = OutflowHorizon.year;
            },
          ),
        ),
      ],
    );
  }

  Widget _buildHorizonMiniCard({
    required BuildContext context,
    required String label,
    required String sublabel,
    required double amount,
    required bool isSelected,
    required MaterialColor color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
        decoration: BoxDecoration(
          color: isSelected ? color.shade700 : color.shade50,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? color.shade800 : color.shade200,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: color.withValues(alpha: 0.25),
                    blurRadius: 6,
                    offset: const Offset(0, 3),
                  ),
                ]
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: isSelected ? Colors.white : color.shade900,
                  ),
                ),
                if (isSelected)
                  const Icon(Icons.check_circle_rounded, size: 12, color: Colors.white),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              sublabel,
              style: TextStyle(
                fontSize: 9.5,
                color: isSelected ? Colors.white.withValues(alpha: 0.8) : Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 6),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                '₹${AppFormatters.currency(amount)}',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: isSelected ? Colors.white : color.shade900,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 2. ACTIVE HORIZON EXECUTIVE SUMMARY CARD
  // ---------------------------------------------------------------------------
  Widget _buildExecutiveSummaryCard(BuildContext context, OutflowHorizonReport report) {
    final fixedPct = (report.fixedPercentage * 100).toInt();
    final variablePct = (report.variablePercentage * 100).toInt();

    return Card(
      elevation: 0,
      color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.25),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
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
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Total Projected Outflow',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade700, fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '₹${AppFormatters.currency(report.totalOutflow)}',
                      style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        color: Colors.redAccent,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'Monthly Average',
                        style: TextStyle(fontSize: 10.5, color: Theme.of(context).colorScheme.primary),
                      ),
                      Text(
                        '₹${AppFormatters.currency(report.averageMonthlyOutflow)}/mo',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Fixed vs Variable Split Progress Bar
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(width: 8, height: 8, decoration: const BoxDecoration(color: Colors.indigo, shape: BoxShape.circle)),
                    const SizedBox(width: 5),
                    Text('Fixed / Mandatory: $fixedPct%', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                  ],
                ),
                Row(
                  children: [
                    Container(width: 8, height: 8, decoration: const BoxDecoration(color: Colors.amber, shape: BoxShape.circle)),
                    const SizedBox(width: 5),
                    Text('Variable / Estimated: $variablePct%', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: SizedBox(
                height: 8,
                child: Row(
                  children: [
                    Expanded(
                      flex: (report.fixedPercentage * 1000).toInt().clamp(1, 1000),
                      child: Container(color: Colors.indigo),
                    ),
                    Expanded(
                      flex: (report.variablePercentage * 1000).toInt().clamp(1, 1000),
                      child: Container(color: Colors.amber.shade600),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '₹${AppFormatters.currency(report.fixedOutflow)} (EMIs, fees, salaries)',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
                ),
                Text(
                  '₹${AppFormatters.currency(report.variableOutflow)} (utilities, fuel, living)',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 3. MONTH-BY-MONTH TREND VISUALIZER
  // ---------------------------------------------------------------------------
  Widget _buildMonthlyTrendSection(BuildContext context, OutflowHorizonReport report) {
    final maxAmount = report.monthlyTrend.fold<double>(0.0, (max, p) => p.totalAmount > max ? p.totalAmount : max);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Monthly Distribution (${report.monthlyTrend.length} Months)',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            if (_selectedMonthFilter != null)
              TextButton(
                onPressed: () => setState(() => _selectedMonthFilter = null),
                child: const Text('Show All Months', style: TextStyle(fontSize: 11)),
              ),
          ],
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 110,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: report.monthlyTrend.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final pt = report.monthlyTrend[index];
              final isSelected = _selectedMonthFilter != null &&
                  _selectedMonthFilter!.year == pt.monthDate.year &&
                  _selectedMonthFilter!.month == pt.monthDate.month;
              final ratio = maxAmount > 0 ? (pt.totalAmount / maxAmount) : 0.0;

              return InkWell(
                onTap: () {
                  setState(() {
                    if (isSelected) {
                      _selectedMonthFilter = null;
                    } else {
                      _selectedMonthFilter = pt.monthDate;
                    }
                  });
                },
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  width: 95,
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? Colors.blue.shade100
                        : (pt.isPeakMonth ? Colors.red.shade50 : Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.35)),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected
                          ? Colors.blue.shade700
                          : (pt.isPeakMonth ? Colors.red.shade200 : Colors.grey.shade300),
                      width: isSelected ? 2 : 1,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            pt.monthLabel,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: pt.isPeakMonth ? Colors.red.shade900 : null,
                            ),
                          ),
                          if (pt.isPeakMonth) ...[
                            const SizedBox(width: 3),
                            const Icon(Icons.warning_amber_rounded, size: 12, color: Colors.red),
                          ],
                        ],
                      ),
                      // Mini Vertical Fill Bar
                      Container(
                        height: 38,
                        width: 14,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade200,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        alignment: Alignment.bottomCenter,
                        child: FractionallySizedBox(
                          heightFactor: ratio.clamp(0.08, 1.0),
                          child: Container(
                            decoration: BoxDecoration(
                              color: pt.isPeakMonth ? Colors.red.shade500 : Colors.indigo.shade400,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ),
                      ),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          '₹${AppFormatters.currency(pt.totalAmount)}',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: pt.isPeakMonth ? Colors.red.shade900 : Colors.black87,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // 4. CATEGORY BREAKDOWN SECTION
  // ---------------------------------------------------------------------------
  Widget _buildCategoryBreakdownSection(BuildContext context, OutflowHorizonReport report) {
    if (report.categoryBreakdown.isEmpty) {
      return const SizedBox.shrink();
    }

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Outflow by Category',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                Text(
                  '${report.categoryBreakdown.length} Categories',
                  style: TextStyle(fontSize: 11.5, color: Colors.grey.shade600),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...report.categoryBreakdown.map((cat) {
              final isSelected = _selectedCategoryFilter == cat.category;
              final pct = (cat.percentage * 100).toInt();

              return InkWell(
                onTap: () {
                  setState(() {
                    if (isSelected) {
                      _selectedCategoryFilter = 'All';
                    } else {
                      _selectedCategoryFilter = cat.category;
                    }
                  });
                },
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 6),
                  margin: const EdgeInsets.only(bottom: 6),
                  decoration: BoxDecoration(
                    color: isSelected ? cat.color.withValues(alpha: 0.12) : null,
                    borderRadius: BorderRadius.circular(10),
                    border: isSelected ? Border.all(color: cat.color, width: 1.5) : null,
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 14,
                            backgroundColor: cat.color.withValues(alpha: 0.15),
                            child: Icon(cat.icon, color: cat.color, size: 15),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              cat.category,
                              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12.5),
                            ),
                          ),
                          Text(
                            '${cat.itemCount} item${cat.itemCount == 1 ? "" : "s"}',
                            style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            '₹${AppFormatters.currency(cat.totalAmount)}',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: cat.percentage,
                                minHeight: 4,
                                backgroundColor: Colors.grey.shade200,
                                valueColor: AlwaysStoppedAnimation<Color>(cat.color),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '$pct%',
                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey.shade700),
                          ),
                        ],
                      ),
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

  // ---------------------------------------------------------------------------
  // 5. COMMITMENT LEDGER HEADER & FILTERS
  // ---------------------------------------------------------------------------
  Widget _buildCommitmentsLedgerHeader(BuildContext context, OutflowHorizonReport report) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            const Icon(Icons.format_list_bulleted_rounded, size: 18),
            const SizedBox(width: 6),
            Text(
              'Commitment Ledger (${report.allItems.length})',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
          ],
        ),
        Text(
          'Total: ₹${AppFormatters.currency(report.totalOutflow)}',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: Colors.redAccent),
        ),
      ],
    );
  }

  Widget _buildCategoryFilterPills(OutflowHorizonReport report) {
    final categories = ['All', ...report.categoryBreakdown.map((c) => c.category)];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: categories.map((cat) {
          final isSelected = _selectedCategoryFilter == cat;
          return Padding(
            padding: const EdgeInsets.only(right: 6.0),
            child: FilterChip(
              label: Text(
                cat,
                style: const TextStyle(fontSize: 11),
              ),
              selected: isSelected,
              onSelected: (_) => setState(() => _selectedCategoryFilter = cat),
              visualDensity: VisualDensity.compact,
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildActiveFilterChips() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Wrap(
        spacing: 6,
        children: [
          if (_selectedMonthFilter != null)
            Chip(
              label: Text(
                'Month: ${DateFormat("MMM yyyy").format(_selectedMonthFilter!)}',
                style: const TextStyle(fontSize: 11),
              ),
              deleteIcon: const Icon(Icons.close, size: 14),
              onDeleted: () => setState(() => _selectedMonthFilter = null),
              visualDensity: VisualDensity.compact,
            ),
          if (_selectedCategoryFilter != 'All')
            Chip(
              label: Text('Category: $_selectedCategoryFilter', style: const TextStyle(fontSize: 11)),
              deleteIcon: const Icon(Icons.close, size: 14),
              onDeleted: () => setState(() => _selectedCategoryFilter = 'All'),
              visualDensity: VisualDensity.compact,
            ),
          if (_searchQuery.isNotEmpty)
            Chip(
              label: Text('Search: "$_searchQuery"', style: const TextStyle(fontSize: 11)),
              deleteIcon: const Icon(Icons.close, size: 14),
              onDeleted: () {
                _searchController.clear();
                setState(() => _searchQuery = '');
              },
              visualDensity: VisualDensity.compact,
            ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 6. FILTERED OBLIGATIONS LIST
  // ---------------------------------------------------------------------------
  Widget _buildObligationsList(BuildContext context, OutflowHorizonReport report) {
    var filtered = report.allItems;

    // Filter by Month if selected
    if (_selectedMonthFilter != null) {
      filtered = filtered.where((i) =>
          i.dueDate.year == _selectedMonthFilter!.year &&
          i.dueDate.month == _selectedMonthFilter!.month).toList();
    }

    // Filter by Category if selected
    if (_selectedCategoryFilter != 'All') {
      filtered = filtered.where((i) => i.category == _selectedCategoryFilter).toList();
    }

    // Filter by Search Query
    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((i) =>
          i.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          i.category.toLowerCase().contains(_searchQuery.toLowerCase())).toList();
    }

    if (filtered.isEmpty) {
      return Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: Colors.grey.shade200),
        ),
        child: const Padding(
          padding: EdgeInsets.all(28.0),
          child: Center(
            child: Column(
              children: [
                Icon(Icons.check_circle_outline_rounded, size: 36, color: Colors.green),
                SizedBox(height: 8),
                Text(
                  'No commitments matching the selected criteria.',
                  style: TextStyle(color: Colors.grey, fontSize: 13),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Column(
      children: filtered.map((item) {
        final icon = OutflowForecastService.getCategoryIcon(item.category);
        final color = OutflowForecastService.getCategoryColor(item.category);

        return Card(
          elevation: 0,
          margin: const EdgeInsets.only(bottom: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(color: Colors.grey.shade200),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            leading: CircleAvatar(
              backgroundColor: color.withValues(alpha: 0.15),
              child: Icon(icon, color: color, size: 20),
            ),
            title: Text(
              item.title,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 2),
                Text(
                  'Due: ${DateFormat("d MMM yyyy").format(item.dueDate)} • ${item.category}',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                      decoration: BoxDecoration(
                        color: item.isFixed ? Colors.indigo.withValues(alpha: 0.12) : Colors.amber.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        item.isFixed ? 'Fixed' : 'Variable',
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.bold,
                          color: item.isFixed ? Colors.indigo.shade800 : Colors.amber.shade900,
                        ),
                      ),
                    ),
                    if (item.isEstimate) ...[
                      const SizedBox(width: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade200,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text('Estimate', style: TextStyle(fontSize: 9.5, color: Colors.black87)),
                      ),
                    ],
                    if (item.isOverdue) ...[
                      const SizedBox(width: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                        decoration: BoxDecoration(
                          color: Colors.red.shade100,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text('Overdue', style: TextStyle(fontSize: 9.5, color: Colors.red, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ],
                ),
              ],
            ),
            trailing: Text(
              '₹${AppFormatters.currency(item.amount)}',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            onTap: item.route != null ? () => context.push(item.route!) : null,
          ),
        );
      }).toList(),
    );
  }

  // ---------------------------------------------------------------------------
  // 7. SMART PLANNING INSIGHT CARD
  // ---------------------------------------------------------------------------
  Widget _buildPlanningInsightCard(BuildContext context, OutflowHorizonReport report) {
    final topCat = report.categoryBreakdown.isNotEmpty ? report.categoryBreakdown.first : null;
    final peakMonth = report.monthlyTrend.where((m) => m.isPeakMonth).firstOrNull;

    return Card(
      elevation: 0,
      color: Colors.amber.shade50,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.amber.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.lightbulb_outline_rounded, color: Colors.amber.shade800, size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Planning Recommendations',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.amber.shade900),
                  ),
                  const SizedBox(height: 4),
                  if (topCat != null)
                    Text(
                      '• Largest Outflow Driver: ${topCat.category} represents ${(topCat.percentage * 100).toInt()}% (₹${AppFormatters.currency(topCat.totalAmount)}) of your total commitment.',
                      style: TextStyle(fontSize: 11.5, color: Colors.amber.shade900),
                    ),
                  if (peakMonth != null) ...[
                    const SizedBox(height: 3),
                    Text(
                      '• Peak Outflow Month: ${peakMonth.monthLabel} requires ₹${AppFormatters.currency(peakMonth.totalAmount)}. Consider reserving surplus cash in advance.',
                      style: TextStyle(fontSize: 11.5, color: Colors.amber.shade900),
                    ),
                  ],
                  const SizedBox(height: 8),
                  InkWell(
                    onTap: () => context.push('/cash-forecast'),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Simulate cash flow with income & buffers',
                          style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Colors.blue.shade900),
                        ),
                        const SizedBox(width: 4),
                        Icon(Icons.arrow_forward_rounded, size: 14, color: Colors.blue.shade900),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showForecastInfoDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.info_outline_rounded, color: Colors.blue),
            SizedBox(width: 8),
            Text('About Outflow Forecast', style: TextStyle(fontSize: 16)),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'How are projections calculated?',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
            SizedBox(height: 6),
            Text(
              '• Monthly Commitments (EMIs, domestic staff salaries, recurring deliveries) are projected for 1 month, 3 months, or 12 months based on your selected horizon.',
              style: TextStyle(fontSize: 12),
            ),
            SizedBox(height: 4),
            Text(
              '• Scheduled Items (school fee terms, property taxes, vehicle insurance) are mapped to their exact scheduled due dates.',
              style: TextStyle(fontSize: 12),
            ),
            SizedBox(height: 4),
            Text(
              '• Fixed Commitments are contractual or non-negotiable (loans, fees, salaries), while Variable Commitments reflect utility consumption, groceries, and fuel.',
              style: TextStyle(fontSize: 12),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}
