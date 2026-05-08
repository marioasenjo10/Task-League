import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/calendar/v3.dart' as gcal;

const _webClientId =
    '553825765711-fnrmfath78ug8scdjb6n388guot2geb1.apps.googleusercontent.com';

/// Single shared GoogleSignIn instance with ALL required scopes.
/// Both AuthService (Firebase login) and GoogleCalendarService use this,
/// so the user only ever goes through one OAuth consent screen that grants
/// both Firebase auth AND Calendar access at the same time.
final googleSignInClient = kIsWeb
    ? GoogleSignIn(
        clientId: _webClientId,
        scopes: [gcal.CalendarApi.calendarScope],
      )
    : GoogleSignIn(
        scopes: [gcal.CalendarApi.calendarScope],
      );
