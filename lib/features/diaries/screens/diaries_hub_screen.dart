import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class DiariesHubScreen extends StatelessWidget {
  const DiariesHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Diaries 📔'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Select a Specialized Diary',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            const Text(
              'Organize every aspect of your personal life, vehicles, finances, property & records.',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 16),

            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: MediaQuery.of(context).size.width > 900 ? 3 : MediaQuery.of(context).size.width > 600 ? 2 : 1,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 2.4,
              children: [
                _DiaryCategoryCard(
                  title: 'Personal Diary',
                  subtitle: 'Daily journals, mood notes, goals & special events',
                  icon: Icons.menu_book_rounded,
                  color: Colors.purple,
                  onTap: () => context.go('/personal'),
                ),
                _DiaryCategoryCard(
                  title: 'Vehicle Diary',
                  subtitle: 'Car & bike maintenance, PUC, insurance & FASTag',
                  icon: Icons.directions_car_rounded,
                  color: Colors.red,
                  onTap: () => context.go('/vehicle'),
                ),
                _DiaryCategoryCard(
                  title: 'Financial Diary',
                  subtitle: 'Income, expenses, investments, FDs & loan EMIs',
                  icon: Icons.account_balance_wallet_rounded,
                  color: Colors.green,
                  onTap: () => context.go('/finance'),
                ),
                _DiaryCategoryCard(
                  title: 'Household Diary',
                  subtitle: 'Electricity, water, gas, internet & maid salaries',
                  icon: Icons.home_work_rounded,
                  color: Colors.teal,
                  onTap: () => context.go('/household'),
                ),
                _DiaryCategoryCard(
                  title: 'Education Diary',
                  subtitle: 'School fee schedules, child profiles & transport',
                  icon: Icons.school_rounded,
                  color: Colors.deepOrange,
                  onTap: () => context.go('/school-fees'),
                ),
                _DiaryCategoryCard(
                  title: 'Property Diary',
                  subtitle: 'Home ownership, property tax & renovation logs',
                  icon: Icons.apartment_rounded,
                  color: Colors.indigo,
                  onTap: () => context.go('/property'),
                ),
                _DiaryCategoryCard(
                  title: 'Warranty Diary',
                  subtitle: 'Purchased products, invoices & OCR scanner',
                  icon: Icons.verified_rounded,
                  color: Colors.blue,
                  onTap: () => context.go('/warranty'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DiaryCategoryCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _DiaryCategoryCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: color.withValues(alpha: 0.12),
                child: Icon(icon, color: color, size: 26),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: Colors.grey.shade400),
            ],
          ),
        ),
      ),
    );
  }
}
