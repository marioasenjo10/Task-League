import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/task_service.dart';
import '../services/google_calendar_service.dart';
import '../repositories/task_repository.dart';
import '../../auth/repositories/user_repository.dart';
import '../../history/repositories/task_event_repository.dart';

final googleCalendarServiceProvider = Provider<GoogleCalendarService>(
  (ref) => GoogleCalendarService(),
);

final taskServiceProvider = Provider<TaskService>((ref) {
  return TaskService(
    userRepo: UserRepository(),
    taskRepo: TaskRepository(),
    eventRepo: TaskEventRepository(),
    calendarService: ref.watch(googleCalendarServiceProvider),
  );
});
