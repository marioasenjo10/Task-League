import 'dart:async' show unawaited;
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'firebase_options.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'core/l10n/app_localizations.dart';
import 'core/l10n/locale_provider.dart';
import 'core/config/app_config.dart';
import 'core/services/consent_service.dart';
import 'core/widgets/maintenance_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  // AdMob is only supported on Android/iOS - never on web (would throw).
  if (!kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS)) {
    // Gather UMP/GDPR consent first (required before serving ads in the EEA),
    // then initialize the Mobile Ads SDK. Both run in the background so they
    // never delay the first frame.
    unawaited(
      ConsentService.gatherConsent().whenComplete(
        () => MobileAds.instance.initialize(),
      ),
    );
  }
  // Load prefs BEFORE building the widget tree so the locale is correct on
  // the very first frame — no flicker, no reset on login.
  final prefs = await SharedPreferences.getInstance();
  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
      ],
      child: const FightTaskApp(),
    ),
  );
}

class FightTaskApp extends ConsumerWidget {
  const FightTaskApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch(localeProvider);
    return MaterialApp.router(
      title: 'Task League',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      routerConfig: AppRouter.router,
      locale: locale,
      supportedLocales: kSupportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      // Global maintenance gate: when an admin sets `config/app.maintenanceMode`
      // to true in Firestore, every user sees the maintenance screen instead of
      // the app — including the login screen.
      builder: (context, child) {
        final config = ref.watch(appConfigProvider).valueOrNull;
        if (config?.maintenanceMode == true) {
          return MaintenanceScreen(
            title: config!.maintenanceTitle,
            message: config.maintenanceMessage,
          );
        }
        return child ?? const SizedBox.shrink();
      },
    );
  }
}
