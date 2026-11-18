import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/app_providers.dart';
import '../notifications/providers/notification_providers.dart';

class AppScaffold extends ConsumerStatefulWidget {
  final Widget child;

  const AppScaffold({super.key, required this.child});

  @override
  ConsumerState<AppScaffold> createState() => _AppScaffoldState();
}

class _AppScaffoldState extends ConsumerState<AppScaffold> {
  DateTime? _lastBackPressTime;

  static int _calculateSelectedIndex(BuildContext context) {
    final String location = GoRouterState.of(context).uri.path;
    if (location == '/') return 0;
    if (location.startsWith('/diaries') || location.startsWith('/diary-records')) return 1;
    if (location.startsWith('/shared-diaries')) return 2;
    if (location.startsWith('/circles')) return 3;
    if (location.startsWith('/reminders') || location.startsWith('/calendar')) return 4;
    return 0; // Default to My Day
  }

  void _onItemTapped(int index, BuildContext context) {
    switch (index) {
      case 0:
        context.go('/');
        break;
      case 1:
        context.go('/diaries');
        break;
      case 2:
        context.go('/shared-diaries');
        break;
      case 3:
        context.go('/circles');
        break;
      case 4:
        context.go('/reminders');
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width >= 900;
    final selectedIndex = _calculateSelectedIndex(context);
    final user = ref.watch(userProfileProvider);
    final notificationCount = ref.watch(notificationBadgeCountProvider);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;

        // 1. If an active modal, dialog, sheet, or route can pop, pop it
        if (Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
          return;
        }
        if (context.canPop()) {
          context.pop();
          return;
        }

        // 2. Check current route location and navigate to parent
        final currentLocation = GoRouterState.of(context).uri.path;

        // Sub-form / action screens -> navigate back to their diary dashboard
        if (currentLocation.startsWith('/warranty/')) {
          context.go('/warranty');
          return;
        }
        if (currentLocation.startsWith('/vehicle/')) {
          context.go('/vehicle');
          return;
        }
        if (currentLocation.startsWith('/school-fees/')) {
          context.go('/school-fees');
          return;
        }
        if (currentLocation.startsWith('/bills/')) {
          context.go('/bills');
          return;
        }
        if (currentLocation.startsWith('/diaries/category/')) {
          context.go('/diaries');
          return;
        }

        // Specialized diary modules -> navigate back to Diaries Hub
        const specializedDiaries = [
          '/personal',
          '/vehicle',
          '/finance',
          '/household',
          '/school-fees',
          '/property',
          '/warranty',
          '/bills',
          '/domestic-help',
          '/cash-forecast',
          '/family-workspace',
        ];
        if (specializedDiaries.contains(currentLocation)) {
          context.go('/diaries');
          return;
        }

        // Secondary hub screens -> navigate back to My Day (Home)
        if (currentLocation == '/diaries' ||
            currentLocation == '/shared-diaries' ||
            currentLocation == '/circles' ||
            currentLocation == '/calendar' ||
            currentLocation == '/payments' ||
            currentLocation == '/reports' ||
            currentLocation == '/documents' ||
            currentLocation == '/reminders' ||
            currentLocation == '/profile') {
          context.go('/');
          return;
        }

        // Already on root '/' -> double-tap to exit safely
        final now = DateTime.now();
        if (_lastBackPressTime == null ||
            now.difference(_lastBackPressTime!) > const Duration(seconds: 2)) {
          _lastBackPressTime = now;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Press back again to exit Magic Diary'),
              duration: Duration(seconds: 2),
              behavior: SnackBarBehavior.floating,
            ),
          );
          return;
        }

        // Confirmed second press within 2s -> exit app
        SystemNavigator.pop();
      },
      child: Scaffold(
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Image.asset(
                    'assets/images/app_logo.png',
                    width: 44,
                    height: 44,
                    errorBuilder: (ctx, err, stack) => const Icon(Icons.auto_stories_rounded, size: 44, color: Colors.white),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Magic Diary',
                    style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const Text(
                    'Your Life. Your Records. Your Reminders.',
                    style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    'Mahato Software · in.mahato.magicdiary',
                    style: TextStyle(color: Colors.white70, fontSize: 10),
                  ),
                ],
              ),
            ),

            // The 3 Primary Pillars
            const Padding(
              padding: EdgeInsets.only(left: 16, top: 8, bottom: 4),
              child: Text('PRIMARY PLATFORM', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey)),
            ),
            ListTile(
              leading: const Icon(Icons.auto_stories_rounded, color: Colors.purple),
              title: const Text('My Diaries'),
              subtitle: const Text('45 predefined & custom personal diaries'),
              selected: selectedIndex == 1,
              onTap: () {
                Navigator.pop(context);
                context.go('/diaries');
              },
            ),
            ListTile(
              leading: const Icon(Icons.share_rounded, color: Colors.blue),
              title: const Text('Shared Diaries'),
              subtitle: const Text('Shared with me & shared by me'),
              selected: selectedIndex == 2,
              onTap: () {
                Navigator.pop(context);
                context.go('/shared-diaries');
              },
            ),
            ListTile(
              leading: const Icon(Icons.groups_rounded, color: Colors.deepPurple),
              title: const Text('Magic Circles'),
              subtitle: const Text('Family, Household, Travel & group collaboration'),
              selected: selectedIndex == 3,
              onTap: () {
                Navigator.pop(context);
                context.go('/circles');
              },
            ),
            const Divider(),
            const Padding(
              padding: EdgeInsets.only(left: 16, top: 4, bottom: 4),
              child: Text('CORE SERVICES & HUBS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey)),
            ),
            ListTile(
              leading: const Icon(Icons.today_rounded, color: Colors.teal),
              title: const Text('My Day'),
              subtitle: const Text('Today\'s reminders, payments & activities'),
              selected: selectedIndex == 0,
              onTap: () {
                Navigator.pop(context);
                context.go('/');
              },
            ),
            ListTile(
              leading: const Icon(Icons.calendar_month_rounded, color: Colors.indigo),
              title: const Text('Universal Calendar'),
              subtitle: const Text('All events, deadlines & schedules'),
              onTap: () {
                Navigator.pop(context);
                context.push('/calendar');
              },
            ),
            ListTile(
              leading: const Icon(Icons.alarm_rounded, color: Colors.red),
              title: const Text('My Reminders'),
              subtitle: const Text('Active alerts, deferral & schedule'),
              selected: selectedIndex == 4,
              onTap: () {
                Navigator.pop(context);
                context.go('/reminders');
              },
            ),
            ListTile(
              leading: const Icon(Icons.payment_rounded, color: Colors.orange),
              title: const Text('My Payments'),
              subtitle: const Text('Bills, EMIs, subscriptions & history'),
              onTap: () {
                Navigator.pop(context);
                context.push('/payments');
              },
            ),
            ListTile(
              leading: const Icon(Icons.analytics_rounded, color: Colors.cyan),
              title: const Text('Reports & Analytics'),
              subtitle: const Text('Financial summary, trends & budgets'),
              onTap: () {
                Navigator.pop(context);
                context.push('/reports');
              },
            ),
            ListTile(
              leading: const Icon(Icons.notifications_active_rounded, color: Colors.deepPurple),
              title: const Text('Notification Centre'),
              subtitle: const Text('Centralized inbox, overdue & snooze'),
              onTap: () {
                Navigator.pop(context);
                context.push('/notifications');
              },
            ),
            ListTile(
              leading: const Icon(Icons.tune_rounded, color: Colors.blueGrey),
              title: const Text('Notification Settings'),
              subtitle: const Text('Intervals, quiet hours, sound & privacy'),
              onTap: () {
                Navigator.pop(context);
                context.push('/notification-settings');
              },
            ),

            const Divider(),

            // Specialized Diary Modules
            const Padding(
              padding: EdgeInsets.only(left: 16, top: 4, bottom: 4),
              child: Text('SPECIALIZED DIARIES', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey)),
            ),
            ListTile(
              leading: const Icon(Icons.menu_book_rounded, color: Colors.purple),
              title: const Text('Personal Diary'),
              onTap: () {
                Navigator.pop(context);
                context.push('/personal');
              },
            ),
            ListTile(
              leading: const Icon(Icons.directions_car_rounded, color: Colors.red),
              title: const Text('Vehicle Diary'),
              onTap: () {
                Navigator.pop(context);
                context.push('/vehicle');
              },
            ),
            ListTile(
              leading: const Icon(Icons.account_balance_wallet_rounded, color: Colors.green),
              title: const Text('Financial Diary'),
              onTap: () {
                Navigator.pop(context);
                context.push('/finance');
              },
            ),
            ListTile(
              leading: const Icon(Icons.home_work_rounded, color: Colors.teal),
              title: const Text('Household Diary'),
              onTap: () {
                Navigator.pop(context);
                context.push('/household');
              },
            ),
            ListTile(
              leading: const Icon(Icons.clean_hands_rounded, color: Colors.cyan),
              title: const Text('Domestic Help & Services'),
              onTap: () {
                Navigator.pop(context);
                context.push('/domestic-help');
              },
            ),
            ListTile(
              leading: const Icon(Icons.family_restroom_rounded, color: Colors.amber),
              title: const Text('Family Workspace'),
              onTap: () {
                Navigator.pop(context);
                context.push('/family-workspace');
              },
            ),
            ListTile(
              leading: const Icon(Icons.trending_up_rounded, color: Colors.blueAccent),
              title: const Text('Cash Commitment Forecast'),
              onTap: () {
                Navigator.pop(context);
                context.push('/cash-forecast');
              },
            ),
            ListTile(
              leading: const Icon(Icons.school_rounded, color: Colors.deepOrange),
              title: const Text('Education Diary'),
              onTap: () {
                Navigator.pop(context);
                context.push('/school-fees');
              },
            ),
            ListTile(
              leading: const Icon(Icons.apartment_rounded, color: Colors.indigo),
              title: const Text('Property Diary'),
              onTap: () {
                Navigator.pop(context);
                context.push('/property');
              },
            ),
            ListTile(
              leading: const Icon(Icons.verified_rounded, color: Colors.blue),
              title: const Text('Warranty Diary'),
              onTap: () {
                Navigator.pop(context);
                context.push('/warranty');
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.person_rounded, color: Colors.blueGrey),
              title: const Text('Profile & Settings'),
              onTap: () {
                Navigator.pop(context);
                context.go('/profile');
              },
            ),
          ],
        ),
      ),
      appBar: AppBar(
        title: Row(
          children: [
            Image.asset(
              'assets/images/app_logo.png',
              width: 28,
              height: 28,
              errorBuilder: (ctx, err, stack) => const Icon(Icons.auto_stories_rounded, color: Colors.blueAccent),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                'Magic Diary',
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search_rounded),
            tooltip: 'Global Search',
            onPressed: () => _showGlobalSearchModal(context, ref),
          ),
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.notifications_outlined),
                tooltip: 'Notification Centre',
                onPressed: () => context.push('/notifications'),
              ),
              if (notificationCount > 0)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                    constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                    alignment: Alignment.center,
                    child: Text(
                      '$notificationCount',
                      style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 8),
          Padding(
            padding: const EdgeInsets.only(right: 12.0),
            child: InkWell(
              onTap: () => context.go('/profile'),
              borderRadius: BorderRadius.circular(20),
              child: CircleAvatar(
                radius: 16,
                backgroundColor: Theme.of(context).primaryColor,
                child: Text(
                  (user?.displayName.isNotEmpty ?? false)
                      ? user!.displayName[0].toUpperCase()
                      : 'U',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ),
        ],
      ),
      body: Row(
        children: [
          if (isWide)
            NavigationRail(
              selectedIndex: selectedIndex,
              onDestinationSelected: (index) => _onItemTapped(index, context),
              labelType: NavigationRailLabelType.all,
              leading: const Padding(
                padding: EdgeInsets.symmetric(vertical: 8.0),
                child: Icon(Icons.bookmark_outline_rounded, size: 32, color: Colors.blueAccent),
              ),
              destinations: const [
                NavigationRailDestination(
                  icon: Icon(Icons.today_outlined),
                  selectedIcon: Icon(Icons.today_rounded),
                  label: Text('My Day'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.auto_stories_outlined),
                  selectedIcon: Icon(Icons.auto_stories_rounded),
                  label: Text('My Diaries'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.share_outlined),
                  selectedIcon: Icon(Icons.share_rounded),
                  label: Text('Shared'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.groups_outlined),
                  selectedIcon: Icon(Icons.groups_rounded),
                  label: Text('Circles'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.alarm_outlined),
                  selectedIcon: Icon(Icons.alarm_rounded),
                  label: Text('Reminders'),
                ),
              ],
            ),
          if (isWide) const VerticalDivider(thickness: 1, width: 1),
          Expanded(
            child: SafeArea(
              top: false,
              bottom: true,
              child: widget.child,
            ),
          ),
        ],
      ),
      bottomNavigationBar: isWide
          ? null
          : BottomNavigationBar(
              currentIndex: selectedIndex,
              onTap: (index) => _onItemTapped(index, context),
              type: BottomNavigationBarType.fixed,
              selectedItemColor: Theme.of(context).primaryColor,
              unselectedItemColor: Colors.grey,
              items: const [
                BottomNavigationBarItem(
                  icon: Icon(Icons.today_outlined),
                  activeIcon: Icon(Icons.today_rounded),
                  label: 'My Day',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.auto_stories_outlined),
                  activeIcon: Icon(Icons.auto_stories_rounded),
                  label: 'My Diaries',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.share_outlined),
                  activeIcon: Icon(Icons.share_rounded),
                  label: 'Shared',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.groups_outlined),
                  activeIcon: Icon(Icons.groups_rounded),
                  label: 'Circles',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.alarm_outlined),
                  activeIcon: Icon(Icons.alarm_rounded),
                  label: 'Reminders',
                ),
              ],
            ),
      ),
    );
  }

  void _showGlobalSearchModal(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.9,
        minChildSize: 0.5,
        expand: false,
        builder: (context, scrollController) => Container(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              TextField(
                autofocus: true,
                decoration: InputDecoration(
                  hintText: 'Search journals, payments, bills, documents...',
                  prefixIcon: const Icon(Icons.search_rounded),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onChanged: (val) {
                  ref.read(searchQueryProvider.notifier).state = val;
                },
              ),
              const SizedBox(height: 16),
              Expanded(
                child: Consumer(
                  builder: (context, ref, child) {
                    final query = ref.watch(searchQueryProvider).toLowerCase();
                    final journals = ref.watch(journalEntriesProvider).value ?? [];
                    final products = ref.watch(productsProvider).value ?? [];
                    final bills = ref.watch(billsProvider).value ?? [];

                    if (query.isEmpty) {
                      return const Center(
                        child: Text('Type to search across all Magic Diary hubs & modules'),
                      );
                    }

                    final matchedJournals = journals.where((j) =>
                        j.title.toLowerCase().contains(query) ||
                        j.content.toLowerCase().contains(query)).toList();

                    final matchedProds = products.where((p) =>
                        p.name.toLowerCase().contains(query) ||
                        p.brand.toLowerCase().contains(query)).toList();

                    final matchedBills = bills.where((b) =>
                        b.billPeriod.toLowerCase().contains(query)).toList();

                    return ListView(
                      controller: scrollController,
                      children: [
                        if (matchedJournals.isNotEmpty) ...[
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 8),
                            child: Text('Personal Journal Entries', style: TextStyle(fontWeight: FontWeight.bold)),
                          ),
                          ...matchedJournals.map((j) => ListTile(
                                leading: const Icon(Icons.menu_book_rounded, color: Colors.purple),
                                title: Text(j.title),
                                subtitle: Text(j.content, maxLines: 1, overflow: TextOverflow.ellipsis),
                                onTap: () {
                                  Navigator.pop(context);
                                  context.push('/personal');
                                },
                              )),
                        ],
                        if (matchedProds.isNotEmpty) ...[
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 8),
                            child: Text('Products & Warranties', style: TextStyle(fontWeight: FontWeight.bold)),
                          ),
                          ...matchedProds.map((p) => ListTile(
                                leading: const Icon(Icons.verified_outlined, color: Colors.blue),
                                title: Text(p.name),
                                subtitle: Text(p.brand),
                                onTap: () {
                                  Navigator.pop(context);
                                  context.push('/warranty');
                                },
                              )),
                        ],
                        if (matchedBills.isNotEmpty) ...[
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 8),
                            child: Text('Bills & Expenses', style: TextStyle(fontWeight: FontWeight.bold)),
                          ),
                          ...matchedBills.map((b) => ListTile(
                                leading: const Icon(Icons.receipt_long_outlined, color: Colors.orange),
                                title: Text('Bill (${b.billPeriod})'),
                                subtitle: Text('Amount: ₹${b.amount}'),
                                onTap: () {
                                  Navigator.pop(context);
                                  context.push('/payments');
                                },
                              )),
                        ],
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
