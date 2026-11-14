import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/diary_engine/models/diary_record.dart';
import '../../../core/diary_engine/screens/generic_diary_list_screen.dart';
import '../../../core/diary_registry/diary_registry.dart';
import '../../../core/security/diary_access_control_service.dart';
import '../models/shared_diary_models.dart';
import '../repositories/shared_diary_repository.dart';

class RecordSelectionScreen extends ConsumerStatefulWidget {
  final String diaryId;
  final String ownerUid;
  final Set<String> initiallySelectedRecordIds;
  final String? currentShareId;
  final String? recipientName;
  final String? diaryTitle;

  const RecordSelectionScreen({
    super.key,
    required this.diaryId,
    required this.ownerUid,
    this.initiallySelectedRecordIds = const {},
    this.currentShareId,
    this.recipientName,
    this.diaryTitle,
  });

  @override
  ConsumerState<RecordSelectionScreen> createState() => _RecordSelectionScreenState();
}

class _RecordSelectionScreenState extends ConsumerState<RecordSelectionScreen> {
  final TextEditingController _searchController = TextEditingController();
  late Set<String> _selectedIds;
  Set<String> _otherSharedIds = {};
  String _searchQuery = '';
  DateTimeRange? _selectedDateRange;
  String? _selectedStatus;

  @override
  void initState() {
    super.initState();
    _selectedIds = Set<String>.from(widget.initiallySelectedRecordIds);
    _loadOtherShares();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadOtherShares() async {
    final repo = ref.read(sharedDiaryRepositoryProvider);
    final otherShared = await repo.getExistingSharedRecordIds(
      ownerUid: widget.ownerUid,
      diaryId: widget.diaryId,
      excludeShareId: widget.currentShareId,
    );
    if (mounted) {
      setState(() {
        _otherSharedIds = otherShared;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final diary = DiaryRegistry.getDiaryById(widget.diaryId);
    final color = diary?.color ?? Colors.blue;
    final isSensitive = DiaryAccessControlService.isSensitiveDiary(widget.diaryId);

    final recordsAsync = ref.watch(diaryUserRecordsStreamProvider(
      (diaryId: widget.diaryId, userId: widget.ownerUid),
    ));

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Select Records to Share',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            Text(
              diary?.name ?? widget.diaryId,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context, _selectedIds.toList());
            },
            child: const Text('DONE', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
      body: recordsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Error loading records: $err')),
        data: (allRecords) {
          // Filter records by search query, date range, and status
          final filteredRecords = allRecords.where((record) {
            if (_searchQuery.isNotEmpty) {
              final titleMatch = record.title.toLowerCase().contains(_searchQuery);
              final subtitleMatch = record.subtitle?.toLowerCase().contains(_searchQuery) ?? false;
              if (!titleMatch && !subtitleMatch) return false;
            }
            if (_selectedDateRange != null) {
              if (record.recordDate.isBefore(_selectedDateRange!.start) ||
                  record.recordDate.isAfter(_selectedDateRange!.end.add(const Duration(days: 1)))) {
                return false;
              }
            }
            if (_selectedStatus != null && record.status != _selectedStatus) {
              return false;
            }
            return true;
          }).toList();

          // Calculate accurate 4-way summary counts
          final summary = SharedRecordAccessSummary.compute(
            allRecords: allRecords,
            currentlySelectedRecordIds: _selectedIds,
            allOtherSharedRecordIds: _otherSharedIds,
          );

          return Column(
            children: [
              // 1. Sensitive Privacy Banner if applicable
              if (isSensitive)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  color: Colors.amber.shade100,
                  child: Row(
                    children: [
                      Icon(Icons.shield_outlined, size: 16, color: Colors.amber.shade900),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'High-Sensitivity Diary: Only selected records will be visible.',
                          style: TextStyle(fontSize: 11.5, color: Colors.amber.shade900, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),

              // 2. Accurate Counts Summary Header
              _buildSummaryHeader(summary, color),

              // 3. Search & Filters Bar
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          hintText: 'Search by title or description...',
                          prefixIcon: const Icon(Icons.search, size: 20),
                          suffixIcon: _searchQuery.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear, size: 18),
                                  onPressed: () {
                                    _searchController.clear();
                                    setState(() => _searchQuery = '');
                                  },
                                )
                              : null,
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        onChanged: (val) => setState(() => _searchQuery = val.trim().toLowerCase()),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.outlined(
                      icon: Icon(
                        _selectedDateRange != null ? Icons.filter_alt : Icons.filter_alt_outlined,
                        color: _selectedDateRange != null ? color : Colors.grey,
                      ),
                      tooltip: 'Filter by Date Range',
                      onPressed: () async {
                        final picked = await showDateRangePicker(
                          context: context,
                          firstDate: DateTime(1900),
                          lastDate: DateTime(2200),
                          initialDateRange: _selectedDateRange,
                        );
                        if (picked != null) {
                          setState(() => _selectedDateRange = picked);
                        } else if (_selectedDateRange != null) {
                          setState(() => _selectedDateRange = null);
                        }
                      },
                    ),
                  ],
                ),
              ),

              // 4. Selection Actions (Select All / Deselect All)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Row(
                  children: [
                    Text(
                      '${filteredRecords.length} records found',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                    ),
                    const Spacer(),
                    TextButton.icon(
                      icon: const Icon(Icons.select_all, size: 16),
                      label: const Text('Select All', style: TextStyle(fontSize: 12)),
                      onPressed: () {
                        setState(() {
                          _selectedIds.addAll(filteredRecords.map((r) => r.id));
                        });
                      },
                    ),
                    const SizedBox(width: 4),
                    TextButton.icon(
                      icon: const Icon(Icons.deselect, size: 16),
                      label: const Text('Deselect All', style: TextStyle(fontSize: 12)),
                      onPressed: () {
                        setState(() {
                          _selectedIds.removeAll(filteredRecords.map((r) => r.id));
                        });
                      },
                    ),
                  ],
                ),
              ),

              const Divider(height: 1),

              // 5. Records List
              Expanded(
                child: filteredRecords.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.inventory_2_outlined, size: 48, color: Colors.grey.shade400),
                            const SizedBox(height: 12),
                            Text(
                              _searchQuery.isNotEmpty ? 'No records match search' : 'No records in this diary',
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 88),
                        itemCount: filteredRecords.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 6),
                        itemBuilder: (context, index) {
                          final record = filteredRecords[index];
                          final isSelected = _selectedIds.contains(record.id);
                          final isAlreadyShared = _otherSharedIds.contains(record.id);

                          return Card(
                            elevation: isSelected ? 2 : 0.5,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: BorderSide(
                                color: isSelected ? color : Colors.grey.shade300,
                                width: isSelected ? 1.5 : 0.8,
                              ),
                            ),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(12),
                              onTap: () {
                                setState(() {
                                  if (isSelected) {
                                    _selectedIds.remove(record.id);
                                  } else {
                                    _selectedIds.add(record.id);
                                  }
                                });
                              },
                              child: Padding(
                                padding: const EdgeInsets.all(12.0),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Checkbox(
                                      value: isSelected,
                                      activeColor: color,
                                      onChanged: (val) {
                                        setState(() {
                                          if (val == true) {
                                            _selectedIds.add(record.id);
                                          } else {
                                            _selectedIds.remove(record.id);
                                          }
                                        });
                                      },
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  record.title,
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 14,
                                                  ),
                                                ),
                                              ),
                                              if (record.amount != null)
                                                Text(
                                                  '${record.currency}${record.amount}',
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 13,
                                                  ),
                                                ),
                                            ],
                                          ),
                                          if (record.subtitle != null && record.subtitle!.isNotEmpty) ...[
                                            const SizedBox(height: 3),
                                            Text(
                                              record.subtitle!,
                                              style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ],
                                          const SizedBox(height: 6),
                                          Row(
                                            children: [
                                              Icon(Icons.calendar_today, size: 12, color: Colors.grey.shade500),
                                              const SizedBox(width: 4),
                                              Text(
                                                DateFormat('dd MMM yyyy').format(record.recordDate),
                                                style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                                              ),
                                              if (record.attachmentIds.isNotEmpty) ...[
                                                const SizedBox(width: 12),
                                                Icon(Icons.attach_file, size: 12, color: Colors.grey.shade500),
                                                const SizedBox(width: 2),
                                                Text(
                                                  '${record.attachmentIds.length} files',
                                                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                                                ),
                                              ],
                                              const Spacer(),
                                              if (isAlreadyShared)
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                  decoration: BoxDecoration(
                                                    color: Colors.blue.shade50,
                                                    borderRadius: BorderRadius.circular(4),
                                                  ),
                                                  child: Row(
                                                    mainAxisSize: MainAxisSize.min,
                                                    children: [
                                                      Icon(Icons.share, size: 10, color: Colors.blue.shade700),
                                                      const SizedBox(width: 3),
                                                      Text(
                                                        'Already Shared',
                                                        style: TextStyle(fontSize: 10, color: Colors.blue.shade700, fontWeight: FontWeight.bold),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.remove_red_eye_outlined, size: 18),
                                      tooltip: 'Preview Record',
                                      onPressed: () => _showRecordPreview(context, record),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, -2)),
          ],
        ),
        child: SafeArea(
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: color,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () {
              Navigator.pop(context, _selectedIds.toList());
            },
            child: Text(
              'Confirm ${_selectedIds.length} Selected Records',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryHeader(SharedRecordAccessSummary summary, Color color) {
    return Container(
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildCountItem('Total', summary.totalRecords, Colors.black87),
              _buildCountItem('Selected', summary.selectedRecords, color, isBold: true),
              _buildCountItem('Already Shared', summary.alreadySharedRecords, Colors.blue.shade700),
              _buildCountItem('Private', summary.remainingPrivateRecords, Colors.grey.shade700),
            ],
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: summary.totalRecords > 0 ? summary.selectedRecords / summary.totalRecords : 0.0,
            backgroundColor: Colors.grey.shade200,
            color: color,
            borderRadius: BorderRadius.circular(4),
            minHeight: 6,
          ),
        ],
      ),
    );
  }

  Widget _buildCountItem(String label, int count, Color color, {bool isBold = false}) {
    return Column(
      children: [
        Text(
          count.toString(),
          style: TextStyle(
            fontSize: 16,
            fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
            color: color,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
        ),
      ],
    );
  }

  void _showRecordPreview(BuildContext context, DiaryRecord record) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        maxChildSize: 0.85,
        minChildSize: 0.4,
        expand: false,
        builder: (_, scrollController) => ListView(
          controller: scrollController,
          padding: const EdgeInsets.all(20),
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Record Preview', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
              ],
            ),
            const Divider(),
            Text(record.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            if (record.subtitle != null) ...[
              const SizedBox(height: 6),
              Text(record.subtitle!, style: TextStyle(color: Colors.grey.shade700)),
            ],
            const SizedBox(height: 12),
            Text('Date: ${DateFormat('dd MMMM yyyy').format(record.recordDate)}'),
            if (record.amount != null) Text('Amount: ${record.currency}${record.amount}'),
            if (record.fields.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Text('Fields:', style: TextStyle(fontWeight: FontWeight.bold)),
              ...record.fields.entries.map((e) => Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text('${e.key}: ${e.value}'),
                  )),
            ],
          ],
        ),
      ),
    );
  }
}
