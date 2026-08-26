import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

/// Handles the Google User Messaging Platform (UMP) consent flow, required by
/// AdMob before showing ads in regions with privacy laws (EU/UK GDPR, etc.).
///
/// Call [gatherConsent] once at startup BEFORE serving ads. It requests the
/// latest consent info and shows the consent form only when it is required.
/// The whole flow is a no-op on web/desktop (AdMob unsupported) and never
/// throws — ad serving continues regardless so it can't block the app.
class ConsentService {
  /// Request consent info and show the consent form if the user's region
  /// requires it. Returns when the flow is done (or immediately if unsupported).
  static Future<void> gatherConsent() async {
    // AdMob / UMP only runs on mobile.
    if (kIsWeb ||
        (defaultTargetPlatform != TargetPlatform.android &&
            defaultTargetPlatform != TargetPlatform.iOS)) {
      return;
    }

    final completer = Completer<void>();

    // In debug you can force a geography to test the EEA form by adding a
    // ConsentDebugSettings with your test device id. Left empty for real runs.
    final params = ConsentRequestParameters();

    ConsentInformation.instance.requestConsentInfoUpdate(
      params,
      () async {
        try {
          // Loads and shows the form only if consent is required and available.
          await ConsentForm.loadAndShowConsentFormIfRequired((formError) {
            if (formError != null) {
              debugPrint(
                  'Consent form error: ${formError.errorCode} ${formError.message}');
            }
            if (!completer.isCompleted) completer.complete();
          });
        } catch (e) {
          debugPrint('Consent form exception: $e');
          if (!completer.isCompleted) completer.complete();
        }
      },
      (requestError) {
        debugPrint(
            'Consent info update error: ${requestError.errorCode} ${requestError.message}');
        if (!completer.isCompleted) completer.complete();
      },
    );

    return completer.future;
  }
}
