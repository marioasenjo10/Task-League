import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/calendar/v3.dart' as gcal;

const _webClientId =
    '553825765711-fnrmfath78ug8scdjb6n388guot2geb1.apps.googleusercontent.com';

/// Single shared GoogleSignIn instance with ALL required scopes.
/// Both AuthService (Firebase login) and GoogleCalendarService use this,
/// so the user only ever goes through one OAuth consent screen that grants
/// both Firebase auth AND Calendar access at the same time.
///
/// We request only [calendarEventsScope] (create/edit events) rather than the
/// full [calendarScope]: the app only pushes task events to the calendar, so
/// the minimal scope reduces the OAuth consent warning and verification burden.
final googleSignInClient = kIsWeb
    ? GoogleSignIn(
        clientId: _webClientId,
        scopes: [gcal.CalendarApi.calendarEventsScope],
      )
    : GoogleSignIn(
        scopes: [gcal.CalendarApi.calendarEventsScope],
      );
