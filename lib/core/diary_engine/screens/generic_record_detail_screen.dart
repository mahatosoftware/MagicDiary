import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../diary_registry/diary_registry.dart';
import '../models/diary_record.dart';
import 'generic_diary_list_screen.dart';
import '../../providers/app_providers.dart';

class GenericRecordDetailScreen extends ConsumerWidget {
  final String diaryId;
  final String recordId;
  final DiaryRecord? initialRecord;

  const GenericRecordDetailScreen({
    super.key,
    required this.diaryId,
    required this.recordId,
    this.initialRecord,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final diary = DiaryRegistry.getDiaryById(diaryId);
    final user = ref.watch(userProfileProvider);
    final color = diary?.color ?? Colors.blue;

    final recordsAsync = ref.watch(diaryRecordsStreamProvider(diaryId));
    final record = recordsAsync.value?.firstWhere(
          (r) => r.id == recordId,
          orElse: () => initialRecord ?? DiaryRecord(
            id: recordId,
            ownerId: user?.uid ?? '',
            sourceDiaryId: diaryId,
            title: 'Record',
            recordDate: DateTime.now(),
            createdBy: user?.uid ?? '',
            updatedBy: user?.uid ?? '',
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        ) ??
        initialRecord;

    if (record == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(record.title),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_rounded),
            tooltip: 'Edit Record',
            onPressed: () {
              context.push('/diary-records/$diaryId/edit', extra: record);
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded),
            tooltip: 'Delete Record',
            onPressed: () => _confirmDelete(context, ref, record),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          // Header Card
          Card(
            elevation: 1.5,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          diary?.name ?? 'Diary Record',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: color,
                          ),
                        ),
                      ),
                      if (record.isPrivate)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.purple.shade50,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.lock_rounded, size: 12, color: Colors.purple.shade700),
                              const SizedBox(width: 4),
                              Text('Private', style: TextStyle(fontSize: 11, color: Colors.purple.shade700)),
                            ],
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    record.title,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 22),
                  ),
                  if (record.amount != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      '₹${record.amount!.toStringAsFixed(0)}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 20,
                        color: color,
                      ),
                    ),
                  ],
                  if (record.subtitle != null && record.subtitle!.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      record.subtitle!,
                      style: TextStyle(fontSize: 14, color: Colors.grey.shade700),
                    ),
                  ],
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Icon(Icons.calendar_today, size: 14, color: Colors.grey.shade500),
                      const SizedBox(width: 6),
                      Text(
                        DateFormat('EEEE, d MMMM yyyy').format(record.recordDate),
                        style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Fields Section
          if (record.fields.isNotEmpty) ...[
            Text(
              'ENTRY DETAILS',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade600,
                letterSpacing: 1.1,
              ),
            ),
            const SizedBox(height: 8),
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Column(
                children: record.fields.entries.map((entry) {
                  final isRestricted = record.isFieldRestricted(entry.key);
                  return ListTile(
                    title: Text(
                      _formatFieldKey(entry.key),
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    subtitle: Text(
                      isRestricted ? '•••••••• (Restricted)' : entry.value.toString(),
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: isRestricted ? Colors.grey : Colors.black87,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _formatFieldKey(String key) {
    return key
        .replaceAll('_', ' ')
        .split(' ')
        .map((str) => str.isNotEmpty ? '${str[0].toUpperCase()}${str.substring(1)}' : '')
        .join(' ');
  }

  void _confirmDelete(BuildContext context, WidgetRef ref, DiaryRecord record) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Entry?'),
        content: Text('Are you sure you want to delete "${record.title}"? This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(ctx);
              final user = ref.read(userProfileProvider);
              if (user != null) {
                final repo = ref.read(diaryRecordRepositoryProvider);
                await repo.deleteRecord(
                  userId: user.uid,
                  diaryId: diaryId,
                  recordId: record.id,
                );
              }
              if (context.mounted) {
                context.pop();
              }
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
