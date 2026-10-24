import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/utils/formatters.dart';
import '../../household/models/household_models.dart';
import '../../school_fees/models/school_fees_models.dart';
import '../../vehicle/models/vehicle_models.dart';
import '../../property/models/property_models.dart';
import '../models/report_models.dart';
import '../services/financial_analytics_service.dart';
import '../services/financial_pdf_exporter.dart';
import '../widgets/report_charts.dart';
import '../widgets/module_reports_sheet.dart';
import '../../../core/ads/admob_config.dart';
import '../../../core/ads/widgets/native_ad_card_widget.dart';

class FinancialReportsScreen extends ConsumerStatefulWidget {
  const FinancialReportsScreen({super.key});

  @override
  ConsumerState<FinancialReportsScreen> createState() => _FinancialReportsScreenState();
}

class _FinancialReportsScreenState extends ConsumerState<FinancialReportsScreen> {
  ReportPeriodType _periodType = ReportPeriodType.monthly;
  YearType _yearType = YearType.financialYear;
  DateTime _referenceDate = DateTime.now();
  DateTime? _customStart;
  DateTime? _customEnd;

  String? _selectedCategoryFilter;
  String _transactionTypeFilter = 'All'; // 'All', 'Income', 'Expense'
  String _sourceModuleFilter = 'All'; // 'All', 'Finance', 'Household', 'Bills', 'SchoolFees', 'Vehicle', 'Property'
  String _searchQuery = '';
  int _obligationHorizonDays = 30; // 7, 30, 90, 365

  void _previousPeriod() {
    if (_periodType == ReportPeriodType.allTime) return;
    setState(() {
      switch (_periodType) {
        case ReportPeriodType.monthly:
          _referenceDate = DateTime(_referenceDate.year, _referenceDate.month - 1, 1);
          break;
        case ReportPeriodType.quarterly:
          _referenceDate = DateTime(_referenceDate.year, _referenceDate.month - 3, 1);
          break;
        case ReportPeriodType.halfYearly:
          _referenceDate = DateTime(_referenceDate.year, _referenceDate.month - 6, 1);
          break;
        case ReportPeriodType.annual:
          _referenceDate = DateTime(_referenceDate.year - 1, _referenceDate.month, 1);
          break;
        case ReportPeriodType.allTime:
          break;
        case ReportPeriodType.custom:
          if (_customStart != null && _customEnd != null) {
            final diff = _customEnd!.difference(_customStart!);
            _customEnd = _customStart!.subtract(const Duration(days: 1));
            _customStart = _customEnd!.subtract(diff);
          }
          break;
      }
    });
  }

  void _nextPeriod() {
    if (_periodType == ReportPeriodType.allTime) return;
    setState(() {
      switch (_periodType) {
        case ReportPeriodType.monthly:
          _referenceDate = DateTime(_referenceDate.year, _referenceDate.month + 1, 1);
          break;
        case ReportPeriodType.quarterly:
          _referenceDate = DateTime(_referenceDate.year, _referenceDate.month + 3, 1);
          break;
        case ReportPeriodType.halfYearly:
          _referenceDate = DateTime(_referenceDate.year, _referenceDate.month + 6, 1);
          break;
        case ReportPeriodType.annual:
          _referenceDate = DateTime(_referenceDate.year + 1, _referenceDate.month, 1);
          break;
        case ReportPeriodType.allTime:
          break;
        case ReportPeriodType.custom:
          if (_customStart != null && _customEnd != null) {
            final diff = _customEnd!.difference(_customStart!);
            _customStart = _customEnd!.add(const Duration(days: 1));
            _customEnd = _customStart!.add(diff);
          }
          break;
      }
    });
  }

  Future<void> _pickCustomDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      initialDateRange: _customStart != null && _customEnd != null
          ? DateTimeRange(start: _customStart!, end: _customEnd!)
          : DateTimeRange(
              start: DateTime(_referenceDate.year, _referenceDate.month, 1),
              end: DateTime.now(),
            ),
    );

    if (picked != null) {
      setState(() {
        _periodType = ReportPeriodType.custom;
        _customStart = picked.start;
        _customEnd = picked.end;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateRange = FinancialAnalyticsService.getDateRange(
      periodType: _periodType,
      referenceDate: _referenceDate,
      yearType: _yearType,
      customStart: _customStart,
      customEnd: _customEnd,
    );

    // Watch all underlying financial source modules
    final financeTxAsync = ref.watch(financialTransactionsProvider);
    final householdAsync = ref.watch(householdExpensesProvider);
    final childrenAsync = ref.watch(childrenProvider);
    final installmentsAsync = ref.watch(feeInstallmentsProvider);
    final vehiclesAsync = ref.watch(vehiclesProvider);
    final vehicleServicesAsync = ref.watch(vehicleServicesProvider);
    final propertiesAsync = ref.watch(propertiesProvider);
    final propertyMaintenancesAsync = ref.watch(propertyMaintenancesProvider);
    final billAccountsAsync = ref.watch(billAccountsProvider);
    final billsAsync = ref.watch(billsProvider);
    final remindersAsync = ref.watch(remindersProvider);

    // Only show full-screen spinner if primary providers have no cached data at all
    final isLoading = (financeTxAsync.isLoading && financeTxAsync.value == null) ||
        (householdAsync.isLoading && householdAsync.value == null) ||
        (billsAsync.isLoading && billsAsync.value == null);

    final summary = FinancialAnalyticsService.generateReport(
      dateRange: dateRange,
      financialTransactions: financeTxAsync.value ?? [],
      householdExpenses: householdAsync.value ?? [],
      children: childrenAsync.value ?? [],
      feeInstallments: installmentsAsync.value ?? [],
      vehicles: vehiclesAsync.value ?? [],
      vehicleServices: vehicleServicesAsync.value ?? [],
      properties: propertiesAsync.value ?? [],
      propertyMaintenances: propertyMaintenancesAsync.value ?? [],
      billAccounts: billAccountsAsync.value ?? [],
      bills: billsAsync.value ?? [],
      reminders: remindersAsync.value ?? [],
      sourceModuleFilter: _sourceModuleFilter,
    );

    final insights = FinancialAnalyticsService.generateInsights(summary);

    // Filter transactions for drill-down
    final filteredTransactions = summary.transactions.where((t) {
      if (_selectedCategoryFilter != null && t.category != _selectedCategoryFilter) {
        return false;
      }
      if (_transactionTypeFilter == 'Income' && t.flow != TransactionFlow.income) {
        return false;
      }
      if (_transactionTypeFilter == 'Expense' && t.flow != TransactionFlow.expense) {
        return false;
      }
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final match = t.title.toLowerCase().contains(q) ||
            t.category.toLowerCase().contains(q) ||
            t.subcategory.toLowerCase().contains(q);
        if (!match) return false;
      }
      return true;
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Financial Reports'),
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf_outlined),
            tooltip: 'Export PDF Report',
            onPressed: () async {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Generating PDF Report...')),
              );
              await FinancialReportPdfExporter.exportPdf(summary);
            },
          ),
          IconButton(
            icon: const Icon(Icons.download_rounded),
            tooltip: 'Export CSV',
            onPressed: () {
              final csv = FinancialReportPdfExporter.generateCsv(summary);
              Clipboard.setData(ClipboardData(text: csv));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('CSV copied to clipboard! You can paste it into Excel or Google Sheets.')),
              );
            },
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () async {
                ref.invalidate(financialTransactionsProvider);
                ref.invalidate(householdExpensesProvider);
                ref.invalidate(feeInstallmentsProvider);
                ref.invalidate(vehicleServicesProvider);
                ref.invalidate(propertyMaintenancesProvider);
              },
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 1. Period Selector & Controls
                    _buildPeriodSelectorCard(dateRange),

                    const SizedBox(height: 16),

                    // 2. Financial Summary Cards
                    _buildFinancialSummaryCards(summary),

                    const SizedBox(height: 16),

                    // 3. Smart Data-Driven Insights
                    if (insights.isNotEmpty) ...[
                      _buildInsightsSection(insights),
                      const SizedBox(height: 16),
                    ],

                    // 4. Interactive Charts & Category Breakdown
                    _buildChartsCard(summary),

                    const SizedBox(height: 16),
                    const NativeAdCardWidget(
                      placement: AdMobConfig.placementReportsInline,
                    ),
                    const SizedBox(height: 16),

                    // 5. Dedicated Module Reports Deep-Dives
                    _buildModuleReportsBar(
                      householdExpenses: householdAsync.asData?.value ?? [],
                      children: childrenAsync.asData?.value ?? [],
                      installments: installmentsAsync.asData?.value ?? [],
                      vehicles: vehiclesAsync.asData?.value ?? [],
                      vehicleServices: vehicleServicesAsync.asData?.value ?? [],
                      properties: propertiesAsync.asData?.value ?? [],
                      propertyMaintenances: propertyMaintenancesAsync.asData?.value ?? [],
                      dateRange: dateRange,
                    ),

                    const SizedBox(height: 16),

                    // 6. Upcoming Financial Obligations
                    _buildUpcomingObligationsCard(summary.upcomingObligations),

                    const SizedBox(height: 16),

                    // 7. Itemized Transactions Drill-Down
                    _buildTransactionsDrillDown(filteredTransactions, summary.transactions.length),

                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
    );
  }

  // --- Sub-Widgets ---

  Widget _buildPeriodSelectorCard(ReportDateRange dateRange) {
    return Card(
      elevation: 0,
      color: Colors.indigo.shade50.withValues(alpha: 0.6),
      shape: RoundedRectangleBorder(
        side: BorderSide(color: Colors.indigo.shade100),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          children: [
            // Top Row: Period Types Chips
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _periodTypeChip('Monthly', ReportPeriodType.monthly),
                  _periodTypeChip('Quarterly', ReportPeriodType.quarterly),
                  _periodTypeChip('Half-Yearly', ReportPeriodType.halfYearly),
                  _periodTypeChip('Annual', ReportPeriodType.annual),
                  _periodTypeChip('All Time', ReportPeriodType.allTime),
                  ActionChip(
                    avatar: const Icon(Icons.date_range, size: 16, color: Colors.indigo),
                    label: const Text('Custom Range'),
                    backgroundColor: _periodType == ReportPeriodType.custom ? Colors.indigo.shade200 : null,
                    onPressed: _pickCustomDateRange,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),

            // Navigation Row with Previous / Next Arrows
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (_periodType != ReportPeriodType.allTime)
                  IconButton(
                    icon: const Icon(Icons.chevron_left_rounded, size: 28),
                    tooltip: 'Previous Period',
                    onPressed: _previousPeriod,
                  )
                else
                  const SizedBox(width: 48),
                Expanded(
                  child: Column(
                    children: [
                      Text(
                        dateRange.label,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.indigo),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 2),
                      if (_periodType != ReportPeriodType.allTime)
                        Text(
                          '${DateFormat('dd MMM yyyy').format(dateRange.start)} – ${DateFormat('dd MMM yyyy').format(dateRange.end)}',
                          style: TextStyle(fontSize: 11, color: Colors.indigo.shade900),
                          textAlign: TextAlign.center,
                        )
                      else
                        Text(
                          'Aggregating complete diary history',
                          style: TextStyle(fontSize: 11, color: Colors.indigo.shade900),
                          textAlign: TextAlign.center,
                        ),
                    ],
                  ),
                ),
                if (_periodType != ReportPeriodType.allTime)
                  IconButton(
                    icon: const Icon(Icons.chevron_right_rounded, size: 28),
                    tooltip: 'Next Period',
                    onPressed: _nextPeriod,
                  )
                else
                  const SizedBox(width: 48),
              ],
            ),

            // Year Type Toggle (Indian FY vs Calendar Year)
            if (_periodType != ReportPeriodType.monthly &&
                _periodType != ReportPeriodType.custom &&
                _periodType != ReportPeriodType.allTime) ...[
              const Divider(height: 16),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('Base Year: ', style: TextStyle(fontSize: 12, color: Colors.grey)),
                    ChoiceChip(
                      label: const Text('Indian FY (Apr–Mar)'),
                      selected: _yearType == YearType.financialYear,
                      onSelected: (val) {
                        if (val) setState(() => _yearType = YearType.financialYear);
                      },
                    ),
                    const SizedBox(width: 8),
                    ChoiceChip(
                      label: const Text('Calendar (Jan–Dec)'),
                      selected: _yearType == YearType.calendarYear,
                      onSelected: (val) {
                        if (val) setState(() => _yearType = YearType.calendarYear);
                      },
                    ),
                  ],
                ),
              ),
            ],

            const Divider(height: 16),

            // Source Module Filter Row
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const Icon(Icons.tune_rounded, size: 16, color: Colors.indigo),
                const SizedBox(width: 6),
                const Text('Source:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.indigo)),
                const SizedBox(width: 8),
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _sourceChip('All Sources', 'All'),
                        _sourceChip('Finance Diary', 'Finance'),
                        _sourceChip('Household', 'Household'),
                        _sourceChip('Bills', 'Bills'),
                        _sourceChip('School Fees', 'SchoolFees'),
                        _sourceChip('Vehicle', 'Vehicle'),
                        _sourceChip('Property', 'Property'),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _sourceChip(String label, String key) {
    final isSelected = _sourceModuleFilter == key;
    return Padding(
      padding: const EdgeInsets.only(right: 6.0),
      child: FilterChip(
        label: Text(label, style: TextStyle(fontSize: 11, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
        selected: isSelected,
        selectedColor: Colors.indigo.shade200,
        backgroundColor: Colors.white,
        checkmarkColor: Colors.indigo.shade900,
        visualDensity: VisualDensity.compact,
        padding: const EdgeInsets.symmetric(horizontal: 4),
        onSelected: (val) {
          if (val) setState(() => _sourceModuleFilter = key);
        },
      ),
    );
  }

  Widget _periodTypeChip(String label, ReportPeriodType type) {
    final isSelected = _periodType == type;
    return Padding(
      padding: const EdgeInsets.only(right: 6.0),
      child: ChoiceChip(
        label: Text(label),
        selected: isSelected,
        selectedColor: Colors.indigo.shade200,
        onSelected: (val) {
          if (val) setState(() => _periodType = type);
        },
      ),
    );
  }

  Widget _buildFinancialSummaryCards(FinancialPeriodSummary summary) {
    final isNegativeSavings = summary.netSavings < 0;

    return Column(
      children: [
        // Top 2 cards: Income & Expenses
        Row(
          children: [
            Expanded(
              child: _summaryMetricCard(
                title: 'Total Income',
                amount: summary.totalIncome,
                icon: Icons.arrow_downward_rounded,
                color: Colors.green,
                bgColor: Colors.green.shade50,
                growthPct: summary.previousPeriodIncome > 0 ? summary.incomeChangePct : null,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _summaryMetricCard(
                title: 'Total Expenses',
                amount: summary.totalExpenses,
                icon: Icons.arrow_upward_rounded,
                color: Colors.red,
                bgColor: Colors.red.shade50,
                growthPct: summary.previousPeriodExpenses > 0 ? summary.expenseChangePct : null,
                invertGrowthColor: true,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Bottom 2 cards: Net Savings & Savings Rate
        Row(
          children: [
            Expanded(
              child: _summaryMetricCard(
                title: 'Net Savings',
                amount: summary.netSavings,
                icon: isNegativeSavings ? Icons.trending_down_rounded : Icons.savings_rounded,
                color: isNegativeSavings ? Colors.red.shade800 : Colors.teal.shade800,
                bgColor: isNegativeSavings ? Colors.red.shade50 : Colors.teal.shade50,
                subtitle: isNegativeSavings ? 'Deficit' : 'Surplus',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Card(
                elevation: 0,
                color: Colors.indigo.shade50,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: BorderSide(color: Colors.indigo.shade100)),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Expanded(
                            child: Text(
                              'Savings Rate',
                              style: TextStyle(fontSize: 12, color: Colors.blueGrey, fontWeight: FontWeight.w500),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Icon(Icons.pie_chart_outline_rounded, size: 18, color: Colors.indigo.shade700),
                        ],
                      ),
                      const SizedBox(height: 4),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          '${summary.savingsRate.toStringAsFixed(1)}%',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.indigo.shade900),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        summary.savingsRate >= 30
                            ? 'Excellent'
                            : (summary.savingsRate >= 15 ? 'Healthy' : 'Below Target'),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: summary.savingsRate >= 15 ? Colors.green.shade800 : Colors.amber.shade900,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),

        // Accounting Ledger: Opening Balance -> Net Savings -> Closing Balance
        if (_periodType != ReportPeriodType.allTime) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _balanceColumn('Opening Balance', summary.openingBalance),
                const Icon(Icons.add, size: 14, color: Colors.grey),
                _balanceColumn('Period Net', summary.netSavings, isDelta: true),
                const Icon(Icons.drag_handle, size: 14, color: Colors.grey),
                _balanceColumn('Closing Balance', summary.closingBalance, isHighlight: true),
              ],
            ),
          ),
        ],

        // Module Contribution Breakdown Pills
        if (summary.moduleTotals.values.any((v) => v > 0)) ...[
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: summary.moduleTotals.entries
                  .where((e) => e.value > 0)
                  .map((e) => Padding(
                        padding: const EdgeInsets.only(right: 6.0),
                        child: InkWell(
                          onTap: () {
                            setState(() {
                              _sourceModuleFilter = _sourceModuleFilter == e.key ? 'All' : e.key;
                            });
                          },
                          borderRadius: BorderRadius.circular(20),
                          child: Chip(
                            backgroundColor: _sourceModuleFilter == e.key ? Colors.indigo.shade100 : Colors.grey.shade100,
                            avatar: Icon(Icons.folder_outlined, size: 14, color: Colors.indigo.shade800),
                            label: Text(
                              '${e.key}: ${AppFormatters.currency(e.value)}',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: _sourceModuleFilter == e.key ? FontWeight.bold : FontWeight.normal,
                                color: _sourceModuleFilter == e.key ? Colors.indigo.shade900 : Colors.black87,
                              ),
                            ),
                          ),
                        ),
                      ))
                  .toList(),
            ),
          ),
        ],
      ],
    );
  }

  Widget _balanceColumn(String label, double amount, {bool isDelta = false, bool isHighlight = false}) {
    final color = isDelta
        ? (amount >= 0 ? Colors.green.shade800 : Colors.red.shade800)
        : (isHighlight ? Colors.indigo.shade900 : Colors.black87);
    final prefix = isDelta && amount > 0 ? '+' : '';

    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.w500),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              '$prefix${AppFormatters.currency(amount)}',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _summaryMetricCard({
    required String title,
    required double amount,
    required IconData icon,
    required Color color,
    required Color bgColor,
    double? growthPct,
    bool invertGrowthColor = false,
    String? subtitle,
  }) {
    return Card(
      elevation: 0,
      color: bgColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: BorderSide(color: color.withValues(alpha: 0.2))),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(fontSize: 12, color: color.withValues(alpha: 0.9), fontWeight: FontWeight.w500),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Icon(icon, size: 18, color: color),
              ],
            ),
            const SizedBox(height: 4),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                AppFormatters.currency(amount),
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color),
              ),
            ),
            const SizedBox(height: 2),
            if (growthPct != null)
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      growthPct >= 0 ? Icons.arrow_upward : Icons.arrow_downward,
                      size: 11,
                      color: (growthPct >= 0) ^ invertGrowthColor ? Colors.green : Colors.red,
                    ),
                    const SizedBox(width: 2),
                    Text(
                      '${growthPct.abs().toStringAsFixed(1)}% vs prev',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: (growthPct >= 0) ^ invertGrowthColor ? Colors.green : Colors.red,
                      ),
                    ),
                  ],
                ),
              )
            else if (subtitle != null)
              Text(
                subtitle,
                style: TextStyle(fontSize: 10, color: color.withValues(alpha: 0.8), fontWeight: FontWeight.w600),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              )
            else
              const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Widget _buildInsightsSection(List<FinancialInsight> insights) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(Icons.auto_awesome, size: 18, color: Colors.amber),
            SizedBox(width: 6),
            Text('Financial Insights & Analysis', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          ],
        ),
        const SizedBox(height: 8),
        ...insights.map((ins) => Card(
              margin: const EdgeInsets.only(bottom: 8),
              elevation: 0,
              shape: RoundedRectangleBorder(
                side: BorderSide(color: ins.color.withValues(alpha: 0.25)),
                borderRadius: BorderRadius.circular(12),
              ),
              color: ins.color.withValues(alpha: 0.06),
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(ins.icon, color: ins.color, size: 22),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(ins.title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: ins.color)),
                          const SizedBox(height: 2),
                          Text(ins.message, style: const TextStyle(fontSize: 12, color: Colors.black87)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            )),
      ],
    );
  }

  Widget _buildChartsCard(FinancialPeriodSummary summary) {
    final showTrends = summary.monthlyTrends.length > 1;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Expanded(
                  child: Text(
                    'Cash Flow & Categories',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (_selectedCategoryFilter != null) ...[
                  const SizedBox(width: 8),
                  Flexible(
                    child: TextButton.icon(
                      icon: const Icon(Icons.clear, size: 14),
                      onPressed: () => setState(() => _selectedCategoryFilter = null),
                      label: Text(
                        'Reset (${_selectedCategoryFilter!})',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 12),

            // Comparison Bar
            IncomeExpenseComparisonBar(
              income: summary.totalIncome,
              expense: summary.totalExpenses,
            ),

            const Divider(height: 32),

            // Category Donut Chart
            CategoryDonutChart(
              breakdowns: summary.categoryBreakdowns,
              totalExpense: summary.totalExpenses,
              selectedCategory: _selectedCategoryFilter,
              onSelectCategory: (cat) => setState(() => _selectedCategoryFilter = cat),
            ),

            // Monthly Trend Chart if multi-month
            if (showTrends) ...[
              const Divider(height: 32),
              const Text('Monthly Income & Expense Trend', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              const SizedBox(height: 8),
              MonthlyTrendBarChart(trends: summary.monthlyTrends),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildModuleReportsBar({
    required List<HouseholdExpense> householdExpenses,
    required List<Child> children,
    required List<FeeInstallment> installments,
    required List<Vehicle> vehicles,
    required List<ServiceRecord> vehicleServices,
    required List<Property> properties,
    required List<PropertyMaintenance> propertyMaintenances,
    required ReportDateRange dateRange,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Deep-Dive Reports', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _moduleReportButton(
                icon: Icons.home_work_rounded,
                label: 'Household',
                color: Colors.green,
                onTap: () => ModuleReportsSheet.showHouseholdReport(
                  context,
                  expenses: householdExpenses,
                  dateRange: dateRange,
                ),
              ),
              const SizedBox(width: 8),
              _moduleReportButton(
                icon: Icons.school_rounded,
                label: 'Education',
                color: Colors.purple,
                onTap: () => ModuleReportsSheet.showEducationReport(
                  context,
                  children: children,
                  installments: installments,
                  dateRange: dateRange,
                ),
              ),
              const SizedBox(width: 8),
              _moduleReportButton(
                icon: Icons.directions_car_rounded,
                label: 'Vehicle Maintenance',
                color: Colors.red,
                onTap: () => ModuleReportsSheet.showVehicleReport(
                  context,
                  vehicles: vehicles,
                  services: vehicleServices,
                  dateRange: dateRange,
                ),
              ),
              const SizedBox(width: 8),
              _moduleReportButton(
                icon: Icons.apartment_rounded,
                label: 'Property & Tax',
                color: Colors.deepOrange,
                onTap: () => ModuleReportsSheet.showPropertyReport(
                  context,
                  properties: properties,
                  maintenances: propertyMaintenances,
                  dateRange: dateRange,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _moduleReportButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return ActionChip(
      avatar: Icon(icon, size: 16, color: color),
      label: Text(label),
      backgroundColor: color.withValues(alpha: 0.08),
      side: BorderSide(color: color.withValues(alpha: 0.3)),
      onPressed: onTap,
    );
  }

  Widget _buildUpcomingObligationsCard(List<UpcomingObligation> obligations) {
    // Only count genuine upcoming items (0 to horizon days) to avoid skewing from old unpaid records
    final upcomingInHorizon = obligations.where((o) => o.daysRemaining >= 0 && o.daysRemaining <= _obligationHorizonDays).toList();
    final overdueList = obligations.where((o) => o.daysRemaining < 0 && o.daysRemaining >= -90).toList();
    final totalDueInHorizon = upcomingInHorizon.fold<double>(0, (s, o) => s + o.amount);

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: Colors.orange.shade200),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.schedule_rounded, color: Colors.deepOrange, size: 20),
                const SizedBox(width: 6),
                Expanded(
                  child: Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      const Text(
                        'Upcoming Obligations',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                      if (overdueList.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.red.shade100,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '${overdueList.length} Overdue',
                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.red.shade800),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    AppFormatters.currency(totalDueInHorizon),
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.deepOrange),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Horizon Filter Pills
            Wrap(
              spacing: 6,
              children: [7, 30, 90, 365].map((days) {
                final isSelected = _obligationHorizonDays == days;
                return ChoiceChip(
                  label: Text('$days Days'),
                  selected: isSelected,
                  selectedColor: Colors.orange.shade200,
                  onSelected: (val) {
                    if (val) setState(() => _obligationHorizonDays = days);
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 12),

            if (upcomingInHorizon.isEmpty && overdueList.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16.0),
                child: Center(child: Text('No upcoming obligations in this timeframe.', style: TextStyle(color: Colors.grey))),
              )
            else ...[
              if (overdueList.isNotEmpty) ...[
                const Text('Overdue Actions Needed', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.red)),
                const SizedBox(height: 4),
                ...overdueList.take(3).map((o) => _obligationTile(o)),
                const SizedBox(height: 8),
              ],
              if (upcomingInHorizon.isNotEmpty) ...[
                Text('Next $_obligationHorizonDays Days', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.deepOrange)),
                const SizedBox(height: 4),
                ...upcomingInHorizon.take(6).map((o) => _obligationTile(o)),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _obligationTile(UpcomingObligation o) {
    final isOverdue = o.daysRemaining < 0;
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: isOverdue ? Colors.red.shade50 : Colors.orange.shade50.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: isOverdue ? Colors.red.shade200 : Colors.orange.shade100),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: Text(o.sourceModule, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        o.title,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  'Due: ${DateFormat('dd MMM yyyy').format(o.dueDate)} • ${isOverdue ? "${-o.daysRemaining}d overdue" : (o.daysRemaining == 0 ? "Due Today" : "in ${o.daysRemaining}d")}',
                  style: TextStyle(fontSize: 11, color: isOverdue ? Colors.red.shade900 : Colors.blueGrey),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              o.amount > 0 ? AppFormatters.currency(o.amount) : 'Quote Pending',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: isOverdue ? Colors.red.shade900 : Colors.deepOrange.shade900,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionsDrillDown(List<UnifiedTransaction> transactions, int totalAll) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    'Itemized Transactions (${transactions.length})',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (_selectedCategoryFilter != null) ...[
                  const SizedBox(width: 8),
                  Chip(
                    label: Text(_selectedCategoryFilter!, style: const TextStyle(fontSize: 11)),
                    visualDensity: VisualDensity.compact,
                    deleteIcon: const Icon(Icons.close, size: 14),
                    onDeleted: () => setState(() => _selectedCategoryFilter = null),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 10),

            // Search Bar
            TextField(
              decoration: InputDecoration(
                hintText: 'Search transactions in this period...',
                prefixIcon: const Icon(Icons.search, size: 20),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              onChanged: (val) => setState(() => _searchQuery = val.trim()),
            ),
            const SizedBox(height: 8),

            // Type filter: All, Income, Expense
            Row(
              children: ['All', 'Income', 'Expense'].map((type) {
                return Padding(
                  padding: const EdgeInsets.only(right: 6.0),
                  child: ChoiceChip(
                    label: Text(type),
                    selected: _transactionTypeFilter == type,
                    onSelected: (val) {
                      if (val) setState(() => _transactionTypeFilter = type);
                    },
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 12),

            if (transactions.isEmpty)
              const Padding(
                padding: EdgeInsets.all(24.0),
                child: Center(child: Text('No transactions match the selected filters.', style: TextStyle(color: Colors.grey))),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: transactions.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (ctx, index) {
                  final t = transactions[index];
                  final isIncome = t.flow == TransactionFlow.income;
                  final isRefund = t.flow == TransactionFlow.refund;
                  final isTransfer = t.flow == TransactionFlow.transfer;

                  Color flowColor = Colors.red;
                  if (isIncome) flowColor = Colors.green;
                  if (isRefund) flowColor = Colors.teal;
                  if (isTransfer) flowColor = Colors.blueGrey;

                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: CircleAvatar(
                      radius: 18,
                      backgroundColor: flowColor.withValues(alpha: 0.12),
                      child: Icon(
                        isIncome
                            ? Icons.arrow_downward_rounded
                            : (isTransfer ? Icons.swap_horiz_rounded : Icons.arrow_upward_rounded),
                        color: flowColor,
                        size: 18,
                      ),
                    ),
                    title: Text(
                      t.title,
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      '${DateFormat('dd MMM').format(t.date)} • ${t.category}${t.subcategory.isNotEmpty ? " (${t.subcategory})" : ""} • ${t.sourceModule}',
                      style: const TextStyle(fontSize: 11, color: Colors.grey),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        '${isIncome ? "+" : "-"}${AppFormatters.currency(t.amount)}',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: flowColor),
                      ),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}
