import 'package:flutter/material.dart';
import '../models/frequent_contact.dart';

/// Horizontal chip list for 1-tap selection of top frequently used contacts
class FrequentContactChipsRow extends StatelessWidget {
  final List<FrequentContact> contacts;
  final ValueChanged<FrequentContact> onContactSelected;
  final String? selectedEmail;

  const FrequentContactChipsRow({
    super.key,
    required this.contacts,
    required this.onContactSelected,
    this.selectedEmail,
  });

  @override
  Widget build(BuildContext context) {
    if (contacts.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.bolt_rounded, size: 16, color: Colors.amber.shade800),
            const SizedBox(width: 4),
            Text(
              'Frequently Shared Contacts',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 38,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: contacts.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final c = contacts[index];
              final isSelected = selectedEmail != null &&
                  selectedEmail!.trim().toLowerCase() == c.email.toLowerCase();

              return ActionChip(
                avatar: CircleAvatar(
                  backgroundColor: isSelected ? Colors.teal : Colors.teal.shade100,
                  child: Text(
                    c.initials,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: isSelected ? Colors.white : Colors.teal.shade900,
                    ),
                  ),
                ),
                label: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      c.name.isNotEmpty ? c.name : c.email.split('@').first,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                        color: isSelected ? Colors.teal.shade900 : Colors.black87,
                      ),
                    ),
                    if (c.useCount > 1) ...[
                      const SizedBox(width: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade200,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '${c.useCount}x',
                          style: TextStyle(fontSize: 10, color: Colors.grey.shade700),
                        ),
                      ),
                    ],
                  ],
                ),
                backgroundColor: isSelected ? Colors.teal.shade50 : Colors.grey.shade50,
                side: BorderSide(
                  color: isSelected ? Colors.teal : Colors.grey.shade300,
                  width: isSelected ? 1.5 : 1.0,
                ),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(19)),
                onPressed: () => onContactSelected(c),
              );
            },
          ),
        ),
      ],
    );
  }
}

/// Autocomplete dropdown/card showing matching frequent contacts for real-time lookup
class FrequentContactSuggestionsCard extends StatelessWidget {
  final List<FrequentContact> suggestions;
  final ValueChanged<FrequentContact> onContactSelected;

  const FrequentContactSuggestionsCard({
    super.key,
    required this.suggestions,
    required this.onContactSelected,
  });

  @override
  Widget build(BuildContext context) {
    if (suggestions.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(top: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.teal.shade200, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      constraints: const BoxConstraints(maxHeight: 200),
      child: Material(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: ListView.separated(
          shrinkWrap: true,
          padding: EdgeInsets.zero,
          itemCount: suggestions.length,
          separatorBuilder: (_, __) => Divider(height: 1, color: Colors.grey.shade200),
          itemBuilder: (context, index) {
            final c = suggestions[index];
            return ListTile(
              dense: true,
              visualDensity: VisualDensity.compact,
              leading: CircleAvatar(
                radius: 16,
                backgroundColor: Colors.teal.shade100,
                child: Text(
                  c.initials,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Colors.teal.shade900,
                  ),
                ),
              ),
              title: Row(
                children: [
                  Expanded(
                    child: Text(
                      c.name.isNotEmpty ? c.name : c.email,
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (c.username != null && c.username!.isNotEmpty) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.purple.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.purple.shade200, width: 0.8),
                      ),
                      child: Text(
                        '@${c.username}',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Colors.purple.shade800,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              subtitle: Text(
                c.email,
                style: TextStyle(fontSize: 11.5, color: Colors.grey.shade600),
                overflow: TextOverflow.ellipsis,
              ),
              trailing: Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.teal.shade50,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${c.useCount} share${c.useCount > 1 ? 's' : ''}',
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                    color: Colors.teal.shade800,
                  ),
                ),
              ),
              onTap: () => onContactSelected(c),
            );
          },
        ),
      ),
    ),
  );
  }
}
