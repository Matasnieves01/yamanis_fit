import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yamanis_fit/core/services/notification_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('NotificationService Preferences & Configuration', () {
    test('Valores por defecto de recordatorios', () async {
      final isEnabled = await NotificationService.areRemindersEnabled();
      final time = await NotificationService.getReminderTime();

      expect(isEnabled, isTrue);
      expect(time.hour, equals(8));
      expect(time.minute, equals(0));
    });

    test('Guardar y recuperar activación de recordatorios', () async {
      await NotificationService.setRemindersEnabled(false);
      expect(await NotificationService.areRemindersEnabled(), isFalse);

      await NotificationService.setRemindersEnabled(true);
      expect(await NotificationService.areRemindersEnabled(), isTrue);
    });

    test('Guardar y recuperar hora personalizada del recordatorio', () async {
      await NotificationService.setReminderTime(7, 30);
      final time = await NotificationService.getReminderTime();

      expect(time.hour, equals(7));
      expect(time.minute, equals(30));
    });
  });
}
