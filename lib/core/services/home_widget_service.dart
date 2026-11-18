import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import 'package:home_widget/home_widget.dart';
import 'package:intl/intl.dart';

class HomeWidgetService {
  static const String appGroupId = 'group.in.mahato.magicdiary';
  static const String androidWidgetProvider = 'MagicDiaryWidgetProvider';
  static const String iOSWidget = 'MagicDiaryWidget';

  static StreamSubscription<Uri?>? _sub;
  static bool _initialized = false;

  /// Initializes deep link click listener for home screen widgets
  static Future<void> initialize(GoRouter router) async {
    if (kIsWeb) return;
    if (_initialized) return;
    _initialized = true;

    try {
      await HomeWidget.setAppGroupId(appGroupId);

      // 1. Handle app launch from widget click
      final launchUri = await HomeWidget.initiallyLaunchedFromHomeWidget();
      if (launchUri != null) {
        _handleDeepLink(launchUri, router);
      }

      // 2. Handle clicks while app is in background/foreground
      _sub?.cancel();
      _sub = HomeWidget.widgetClicked.listen(
        (uri) {
          if (uri != null) {
            _handleDeepLink(uri, router);
          }
        },
        onError: (err) {
          debugPrint('HomeWidget click listener error: $err');
        },
      );
    } catch (e) {
      debugPrint('HomeWidget initialization note: $e');
    }
  }

  /// Routes incoming deep links from home screen widgets
  static void _handleDeepLink(Uri uri, GoRouter router) {
    final host = uri.host.isNotEmpty ? uri.host : uri.path.replaceAll('/', '');

    switch (host) {
      case 'add-expense':
        router.go('/finance');
        break;
      case 'add-note':
        router.go('/diaries');
        break;
      case 'bills':
        router.go('/bills');
        break;
      case 'record-meter':
        router.go('/bills');
        break;
      case 'home':
      default:
        router.go('/');
        break;
    }
  }

  /// Updates data displayed on the home screen widget
  static Future<void> updateWidgetData({
    required int pendingBillsCount,
    required double pendingBillsTotal,
    required int pendingRemindersCount,
    String? nextDueBillName,
  }) async {
    if (kIsWeb) return;

    try {
      await HomeWidget.setAppGroupId(appGroupId);
      final now = DateTime.now();
      final dateFormatted = DateFormat('EEE, d MMM').format(now);

      final billsText = pendingBillsCount > 0
          ? '$pendingBillsCount Due (₹${pendingBillsTotal.toStringAsFixed(0)})'
          : 'All bills paid';

      final remindersText = pendingRemindersCount > 0
          ? '$pendingRemindersCount Pending Tasks'
          : 'All caught up';

      await HomeWidget.saveWidgetData<String>('widget_title', 'Magic Diary 📔');
      await HomeWidget.saveWidgetData<String>('widget_date', dateFormatted);
      await HomeWidget.saveWidgetData<String>('pending_bills', billsText);
      await HomeWidget.saveWidgetData<String>('pending_reminders', remindersText);

      await HomeWidget.updateWidget(
        androidName: androidWidgetProvider,
        iOSName: iOSWidget,
      );
    } catch (e) {
      debugPrint('Failed to update home widget: $e');
    }
  }

  static void dispose() {
    _sub?.cancel();
    _sub = null;
    _initialized = false;
  }
}
