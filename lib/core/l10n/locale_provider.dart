import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app_localizations.dart';

const _kLocaleKey = 'app_locale';

// ─────────────────────────────────────────────────────────────────────────────
// SharedPreferences provider — loaded once at startup, injected via override
// ─────────────────────────────────────────────────────────────────────────────

final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('SharedPreferences must be overridden in main()');
});

// ─────────────────────────────────────────────────────────────────────────────
// Locale notifier — reads/writes directly from the injected prefs instance
// ─────────────────────────────────────────────────────────────────────────────

class LocaleNotifier extends StateNotifier<Locale> {
  final SharedPreferences _prefs;

  LocaleNotifier(this._prefs)
      : super(_load(_prefs));

  static Locale _load(SharedPreferences prefs) {
    final saved = prefs.getString(_kLocaleKey);
    if (saved != null && kSupportedLocales.any((l) => l.languageCode == saved)) {
      return Locale(saved);
    }
    return const Locale('en');
  }

  void setLocale(Locale locale) {
    if (!kSupportedLocales.any((l) => l.languageCode == locale.languageCode)) return;
    state = locale;
    _prefs.setString(_kLocaleKey, locale.languageCode);
  }

  void toggle() {
    setLocale(state.languageCode == 'en' ? const Locale('es') : const Locale('en'));
  }
}

final localeProvider = StateNotifierProvider<LocaleNotifier, Locale>(
  (ref) {
    final prefs = ref.watch(sharedPreferencesProvider);
    return LocaleNotifier(prefs);
  },
);
