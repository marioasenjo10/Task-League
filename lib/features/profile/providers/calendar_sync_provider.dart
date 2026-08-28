import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/models/user_model.dart';
import '../../auth/providers/auth_providers.dart';
import '../../league/providers/league_providers.dart';
import '../../tasks/providers/task_service_provider.dart';

/// True while the OAuth popup / bulk-sync is in progress (toggle interaction).
final calendarSyncLoadingProvider = StateProvider<bool>((ref) => false);

/// True while the app-startup Google session restore is running.
/// HomeScreen shows a blocking overlay until this is false.
final calendarSyncInitializingProvider = StateProvider<bool>((ref) => false);

/// Notifier that manages Google Calendar sync toggle.
class CalendarSyncNotifier extends Notifier<bool> {
  @override
  bool build() {
    final authUser = ref.watch(authStateProvider).valueOrNull;
    if (authUser == null) {
      ref.read(googleCalendarServiceProvider).revokeAccess().catchError((_) {});
      return false;
    }

    final user = ref.watch(currentUserProvider).valueOrNull;
    final savedEnabled = user?.calendarSync ?? false;
    debugPrint('[CalendarSync] build → uid=${authUser.uid}, calendarSync=$savedEnabled');

    if (savedEnabled) {
      // On every login with sync=true: restore session + full calendar sync.
      // We mark isInitializing=true so HomeScreen blocks navigation until done.
      Future.microtask(() => _initializeSession(user!));
    }

    return savedEnabled;
  }

  /// Called at login when calendarSync=true.
  /// Restores Google session (with popup if needed) then bulk-syncs tasks.
  Future<void> _initializeSession(UserModel user) async {
    ref.read(calendarSyncInitializingProvider.notifier).state = true;
    try {
      final calendarService = ref.read(googleCalendarServiceProvider);

      // 1. Try silent restore first
      bool sessionReady = await calendarService
          .restoreSilentSignIn()
          .timeout(const Duration(seconds: 15), onTimeout: () => false);
      debugPrint('[CalendarSync] silent restore → $sessionReady');        // 2. If silent failed, show the Google popup directly (no extra silent attempt)
        if (!sessionReady) {
          debugPrint('[CalendarSync] silent failed → requesting access with popup');
          sessionReady = await calendarService
              .requestAccess(skipSilent: true)
              .timeout(const Duration(seconds: 60), onTimeout: () => false);
          debugPrint('[CalendarSync] popup result → $sessionReady');
        }

      if (!sessionReady) {
        // User dismissed the popup — reset flag
        debugPrint('[CalendarSync] access denied → resetting flag');
        state = false;
        ref.read(userRepositoryProvider).saveUser(
          user.copyWith(calendarSync: false),
        ).catchError((_) {});
        return;
      }

      // 3. Bulk-sync all assigned future tasks missing a calendar event
      try {
        final leagues = await ref.read(userLeaguesProvider.future);
        final leagueIds = leagues.map((l) => l.id).toList();
        if (leagueIds.isNotEmpty) {
          final synced = await ref
              .read(taskServiceProvider)
              .syncExistingTasksToCalendar(
                userId: user.id,
                leagueIds: leagueIds,
              );
          debugPrint('[CalendarSync] login sync → $synced tasks pushed to Calendar');
        }
      } catch (e) {
        debugPrint('[CalendarSync] login sync error (non-fatal): $e');
      }
    } finally {
      ref.read(calendarSyncInitializingProvider.notifier).state = false;
    }
  }

  Future<void> toggle(bool enable, UserModel user) async {
    ref.read(calendarSyncLoadingProvider.notifier).state = true;
    try {
      final calendarService = ref.read(googleCalendarServiceProvider);

      if (enable) {
        // skipSilent=true → go straight to popup, avoid FedCM timeout
        final granted = await calendarService.requestAccess(skipSilent: true);
        debugPrint('[CalendarSync] toggle → granted: $granted');
        if (!granted) return;

        try {
          final leagues = await ref.read(userLeaguesProvider.future);
          final leagueIds = leagues.map((l) => l.id).toList();
          if (leagueIds.isNotEmpty) {
            final synced = await ref
                .read(taskServiceProvider)
                .syncExistingTasksToCalendar(
                  userId: user.id,
                  leagueIds: leagueIds,
                );
            debugPrint('[CalendarSync] bulk sync → $synced tasks added to Calendar');
          }
        } catch (e) {
          debugPrint('[CalendarSync] bulk sync error (non-fatal): $e');
        }
      } else {
        await calendarService.revokeAccess();
      }

      await ref.read(userRepositoryProvider).saveUser(
        user.copyWith(calendarSync: enable),
      );
      state = enable;
      debugPrint('[CalendarSync] saved calendarSync=$enable ✅');
    } catch (e) {
      debugPrint('[CalendarSync] ERROR: $e');
    } finally {
      ref.read(calendarSyncLoadingProvider.notifier).state = false;
    }
  }
}

final calendarSyncProvider = NotifierProvider<CalendarSyncNotifier, bool>(
  CalendarSyncNotifier.new,
);
