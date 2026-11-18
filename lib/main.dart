import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'firebase_options.dart';
import 'config/theme.dart';
import 'config/routes.dart';
import 'core/ads/ad_manager.dart';
import 'core/notifications/services/notification_manager.dart';
import 'core/notifications/services/notification_fcm_service.dart';
import 'core/security/security.dart';
import 'core/services/home_widget_service.dart';
import 'core/version/widgets/app_update_gate.dart';
import 'package:google_sign_in/google_sign_in.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Global uncaught error handlers to prevent fatal application crashes
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    debugPrint('[FlutterError] ${details.exceptionAsString()}');
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    debugPrint('[PlatformDispatcher Error] $error\n$stack');
    return true; // Handled safely, prevents crash
  };

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    debugPrint('Firebase initialization note: $e');
  }

  try {
    FirebaseFirestore.instance.settings = const Settings(
      persistenceEnabled: true,
      cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
    );
  } catch (e) {
    debugPrint('Firestore settings note: $e');
  }

  try {
    await FirebaseAppCheckService.initialize();
  } catch (e) {
    debugPrint('AppCheck note: $e');
  }

  // Initialize Google Sign-In SDK
  try {
    await GoogleSignIn.instance.initialize(
      serverClientId: '290081663609-9af1iqk2uhk3ah244at9sioelhv16rda.apps.googleusercontent.com',
    );
  } catch (e) {
    debugPrint('GoogleSignIn initialization note: $e');
  }

  // Initialize Google Mobile Ads SDK (AdMob)
  try {
    await AdManager.instance.initialize();
  } catch (e) {
    debugPrint('AdMob initialization note: $e');
  }

  // Register background FCM message handler
  try {
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  } catch (e) {
    debugPrint('FCM onBackgroundMessage note: $e');
  }

  // Initialize Central Notification Framework
  try {
    await NotificationManager().initialize(
      currentUserId: FirebaseAuth.instance.currentUser?.uid,
      navigationHandler: (route, {extra}) {
        router.push(route, extra: extra);
      },
    );
  } catch (e) {
    debugPrint('NotificationManager initialization note: $e');
  }

  // Initialize Home Screen Widget Service
  try {
    await HomeWidgetService.initialize(router);
  } catch (e) {
    debugPrint('HomeWidget initialization note: $e');
  }

  runApp(
    const ProviderScope(
      child: MagicDiaryApp(),
    ),
  );
}

class MagicDiaryApp extends StatelessWidget {
  const MagicDiaryApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Magic Diary',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,
      routerConfig: router,
      builder: (context, child) {
        return AppUpdateGate(
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
  }
}
