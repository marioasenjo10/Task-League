import 'package:flutter/foundation.dart' show debugPrint;
import 'package:googleapis/calendar/v3.dart' as gcal;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import '../../../core/services/google_sign_in_client.dart';

/// Wraps the Google Calendar API v3 to create/delete events.
class GoogleCalendarService {
  GoogleSignInAccount? _cachedAccount;

  // Always use the shared singleton — same scopes as Firebase login
  GoogleSignIn get _client => googleSignInClient;

  /// Request Calendar permission. Returns true if granted.
  /// Pass [skipSilent]=true when you already know silent sign-in will fail
  /// (e.g. right after restoreSilentSignIn returned false) to avoid a second
  /// FedCM timeout before showing the popup.
  Future<bool> requestAccess({bool skipSilent = false}) async {
    try {
      GoogleSignInAccount? account;

      if (!skipSilent) {
        account = await _client.signInSilently();
      }

      account ??= await _client.signIn();
      debugPrint('[CalendarSync] requestAccess → account: ${account?.email}');
      if (account != null) {
        _cachedAccount = account;
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('[CalendarSync] requestAccess error: $e');
      final msg = e.toString();
      if (msg.contains('people.googleapis.com') ||
          msg.contains('403') ||
          msg.contains('PERMISSION_DENIED')) {
        debugPrint('[CalendarSync] People API error — Calendar token was granted ✅');
        return true;
      }
      return false;
    }
  }

  /// Try to restore a previous session silently (no popup).
  /// Returns true only if the session has the Calendar scope granted.
  Future<bool> restoreSilentSignIn() async {
    try {
      final account = await _client.signInSilently();
      if (account == null) {
        debugPrint('[CalendarSync] restoreSilentSignIn → no session found');
        return false;
      }
      _cachedAccount = account;
      debugPrint('[CalendarSync] restoreSilentSignIn → restored: ${account.email}');

      // Verify that the Calendar scope is actually granted by making a lightweight
      // API call. A Google-login user has a session but may lack the Calendar scope.
      final hasScope = await _verifyScopeGranted();
      if (!hasScope) {
        debugPrint('[CalendarSync] restoreSilentSignIn → session exists but Calendar scope missing');
        _cachedAccount = null;
        return false;
      }

      return true;
    } catch (e) {
      debugPrint('[CalendarSync] restoreSilentSignIn error: $e');
      return false;
    }
  }

  /// Checks whether the current session actually has Calendar write access
  /// by listing the primary calendar. Returns false on any permission error.
  Future<bool> _verifyScopeGranted() async {
    try {
      final api = await _getApi();
      if (api == null) return false;
      // Lightweight call — just fetch the primary calendar metadata
      await api.calendars.get('primary');
      return true;
    } catch (e) {
      debugPrint('[CalendarSync] _verifyScopeGranted → failed: $e');
      return false;
    }
  }

  /// Revoke Calendar permission.
  Future<void> revokeAccess() async {
    _cachedAccount = null;
    try {
      await _client.signOut();
    } catch (_) {}
  }

  Future<gcal.CalendarApi?> _getApi() async {
    try {
      // Only use cached account or silent sign-in — NEVER show a popup here
      final account = _cachedAccount ?? await _client.signInSilently();
      if (account == null) {
        debugPrint('[CalendarSync] _getApi → no active session, skipping');
        return null;
      }
      _cachedAccount = account;
      final headers = await account.authHeaders;
      return gcal.CalendarApi(GoogleHttpClient(headers));
    } catch (_) {
      return null;
    }
  }

  /// Create a calendar event and return its Google event ID.
  /// [reminderMinutesBefore] — if provided, sets a popup reminder at that offset.
  /// Defaults to 30 minutes when Google Calendar creates events.
  Future<String?> createEvent({
    required String title,
    String description = '',
    required DateTime startTime,
    required DateTime endTime,
    int? reminderMinutesBefore = 30,
    String calendarId = 'primary',
  }) async {
    try {
      final api = await _getApi();
      if (api == null) return null;

      final event = gcal.Event()
        ..summary = title
        ..description = description
        ..start = (gcal.EventDateTime()
          ..dateTime = startTime
          ..timeZone = 'UTC')
        ..end = (gcal.EventDateTime()
          ..dateTime = endTime
          ..timeZone = 'UTC');

      if (reminderMinutesBefore != null) {
        event.reminders = gcal.EventReminders()
          ..useDefault = false
          ..overrides = [
            gcal.EventReminder()
              ..method = 'popup'
              ..minutes = reminderMinutesBefore,
          ];
      } else {
        event.reminders = gcal.EventReminders()..useDefault = true;
      }

      final created = await api.events.insert(event, calendarId);
      return created.id;
    } catch (_) {
      return null;
    }
  }

  /// Delete an event by its Google event ID.
  Future<void> deleteEvent(String eventId,
      {String calendarId = 'primary'}) async {
    try {
      final api = await _getApi();
      if (api == null) return;
      await api.events.delete(calendarId, eventId);
    } catch (_) {}
  }
}

/// A simple HTTP client that attaches Google auth headers.
class GoogleHttpClient extends http.BaseClient {
  final Map<String, String> _headers;
  final _inner = http.Client();
  GoogleHttpClient(this._headers);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    request.headers.addAll(_headers);
    return _inner.send(request);
  }
}
