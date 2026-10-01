import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:googleapis_auth/googleapis_auth.dart' as auth;
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:otzaria/settings/settings_exports.dart';
import 'package:otzaria/tools/calendar/bloc/calendar_cubit.dart';
import 'package:otzaria/tools/calendar/services/google_calendar_service.dart';
import 'package:otzaria/tools/calendar/services/notification_service.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;

class _Settings implements SettingsRepository {
  int? lastSync;

  @override
  Future<Map<String, dynamic>> loadSettings() async => {
    'calendarType': 'combined',
    'selectedCity': 'ירושלים',
    'calendarEvents': '[]',
    'calendarNotificationsEnabled': false,
    'calendarNotificationTime': 60,
    'calendarNotificationSound': false,
    'calendarZmanAlerts': '{}',
    'calendarEnabledZmanim': '',
    'calendarDayTransition': 'sunset',
    'googleCalendarEnabled': true,
    'googleCalendarSelectedIds': 'primary',
    'googleCalendarSyncPastDays': 60,
    'googleCalendarSyncFutureDays': 365,
    'googleCalendarLastSync': 0,
  };

  @override
  Future<void> updateCalendarEvents(String json) async {}

  @override
  Future<void> updateGoogleCalendarLastSync(int value) async =>
      lastSync = value;

  @override
  String getCalendarEventNotificationIdsJson() => '[]';

  @override
  Future<void> updateCalendarEventNotificationIdsJson(String json) async {}

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

class _Notifications implements NotificationService {
  @override
  bool get isInitialized => true;

  @override
  Future<void> cancelNotification(int id) async {}

  @override
  Future<bool> checkPermissions() async => false;

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

/// Hands out a client over [handler], or fails the way the test asks.
class _Google extends GoogleCalendarService {
  _Google({this.handler, this.error});

  final MockClientHandler? handler;
  final Object? error;

  @override
  Future<bool> isSignedIn() async => handler != null;

  @override
  Future<GoogleCalendarApiClient?> getApiClient({
    bool interactive = false,
  }) async {
    if (error != null) throw error!;
    if (handler == null) return null;
    final credentials = auth.AccessCredentials(
      auth.AccessToken(
        'Bearer',
        'token',
        DateTime.now().toUtc().add(const Duration(hours: 1)),
      ),
      null,
      const [],
    );
    return GoogleCalendarApiClient(
      client: auth.authenticatedClient(MockClient(handler!), credentials),
    );
  }
}

http.Response _json(Object body, [int status = 200]) => http.Response(
  jsonEncode(body),
  status,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  tz_data.initializeTimeZones();

  Future<(CalendarCubit, _Settings)> build(_Google google) async {
    final settings = _Settings();
    final cubit = CalendarCubit(
      settingsRepository: settings,
      notificationService: _Notifications(),
      googleCalendarService: google,
    );
    addTearDown(cubit.close);
    await Future<void>.delayed(const Duration(milliseconds: 100));
    return (cubit, settings);
  }

  test('without an authorized client the sync reports it', () async {
    final (cubit, _) = await build(_Google());

    await cubit.syncGoogleCalendar(interactive: false);

    expect(
      cubit.state.googleCalendarSyncError,
      'לא הצלחנו להתחבר לחשבון Google.',
    );
    expect(cubit.state.googleCalendarConnected, isFalse);
    expect(cubit.state.googleCalendarSyncInProgress, isFalse);
  });

  test('an error while getting the client is shown as is', () async {
    final (cubit, _) = await build(_Google(error: Exception('ההרשאה נדחתה')));

    await cubit.syncGoogleCalendar(interactive: false);

    expect(cubit.state.googleCalendarSyncError, 'ההרשאה נדחתה');
    expect(cubit.state.googleCalendarConnected, isFalse);
  });

  test('a successful sync merges the events', () async {
    final (cubit, settings) = await build(
      _Google(
        handler: (request) async {
          if (request.url.path.contains('calendarList')) {
            return _json({'items': []});
          }
          return _json({
            'items': [
              {
                'id': 'g1',
                'summary': 'פגישה',
                'start': {'date': '2026-10-05'},
                'end': {'date': '2026-10-06'},
              },
            ],
          });
        },
      ),
    );

    await cubit.syncGoogleCalendar(interactive: false);

    expect(cubit.state.events.map((e) => e.title), contains('פגישה'));
    expect(cubit.state.googleCalendarConnected, isTrue);
    expect(cubit.state.googleCalendarSyncError, isNull);
    expect(settings.lastSync, isNotNull);
  });

  test('a calendar that fails to load is skipped', () async {
    final (cubit, _) = await build(
      _Google(handler: (request) async => _json({'error': 'boom'}, 500)),
    );

    await cubit.syncGoogleCalendar(interactive: false);

    expect(cubit.state.googleCalendarConnected, isTrue);
    expect(cubit.state.googleCalendarSyncError, isNull);
    expect(cubit.state.events, isEmpty);
  });
}
