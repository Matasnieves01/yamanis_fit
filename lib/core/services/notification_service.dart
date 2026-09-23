import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  static bool _isInitialized = false;

  // Claves para SharedPreferences
  static const String _prefRemindersEnabled = 'workout_reminders_enabled';
  static const String _prefReminderHour = 'workout_reminder_hour';
  static const String _prefReminderMinute = 'workout_reminder_minute';

  static const String _channelId = 'workout_reminders_channel';
  static const String _channelName = 'Recordatorios de Rutina';
  static const String _channelDesc =
      'Notificaciones que te recuerdan tus entrenamientos del día.';

  /// Inicializa el servicio de notificaciones locales y la base de datos de zonas horarias
  static Future<void> init() async {
    if (_isInitialized) return;

    try {
      // 1. Inicializar zonas horarias
      tz.initializeTimeZones();

      // 2. Configuración para Android
      const AndroidInitializationSettings androidSettings =
          AndroidInitializationSettings('@mipmap/launcher_icon');

      // 3. Configuración para iOS / macOS
      const DarwinInitializationSettings iosSettings =
          DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      );

      const InitializationSettings initSettings = InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      );

      await _notificationsPlugin.initialize(
        settings: initSettings,
        onDidReceiveNotificationResponse: (NotificationResponse response) {
          // Acción al tocar la notificación (por defecto abre la app)
          debugPrint('Notificación tocada: ${response.payload}');
        },
      );

      // Crear canal de notificación de alta importancia en Android
      if (Platform.isAndroid) {
        final androidImpl = _notificationsPlugin
            .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin>();

        const AndroidNotificationChannel channel = AndroidNotificationChannel(
          _channelId,
          _channelName,
          description: _channelDesc,
          importance: Importance.high,
          playSound: true,
          enableVibration: true,
        );

        await androidImpl?.createNotificationChannel(channel);
      }

      _isInitialized = true;
      debugPrint('[NotificationService] Inicializado correctamente.');
    } catch (e) {
      debugPrint('[NotificationService] Error al inicializar: $e');
    }
  }

  /// Solicita permisos de notificación al usuario (iOS y Android 13+)
  static Future<bool> requestPermissions() async {
    try {
      if (Platform.isIOS) {
        final iosImpl = _notificationsPlugin
            .resolvePlatformSpecificImplementation<
                IOSFlutterLocalNotificationsPlugin>();
        final granted = await iosImpl?.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );
        return granted ?? false;
      } else if (Platform.isAndroid) {
        final androidImpl = _notificationsPlugin
            .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin>();
        final granted = await androidImpl?.requestNotificationsPermission();
        return granted ?? false;
      }
      return true;
    } catch (e) {
      debugPrint('[NotificationService] Error al solicitar permisos: $e');
      return false;
    }
  }

  /// Comprueba si los recordatorios están activados en preferencias (por defecto true)
  static Future<bool> areRemindersEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_prefRemindersEnabled) ?? true;
  }

  /// Activa o desactiva los recordatorios en preferencias
  static Future<void> setRemindersEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefRemindersEnabled, enabled);
  }

  /// Obtiene la hora configurada para el recordatorio (por defecto 08:00 AM)
  static Future<TimeOfDay> getReminderTime() async {
    final prefs = await SharedPreferences.getInstance();
    final hour = prefs.getInt(_prefReminderHour) ?? 8;
    final minute = prefs.getInt(_prefReminderMinute) ?? 0;
    return TimeOfDay(hour: hour, minute: minute);
  }

  /// Guarda la hora configurada para el recordatorio
  static Future<void> setReminderTime(int hour, int minute) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_prefReminderHour, hour);
    await prefs.setInt(_prefReminderMinute, minute);
  }

  /// Genera un ID entero determinista único por fecha (YYYYMMDD)
  static int _getNotificationIdForDate(DateTime date) {
    return (date.year % 100) * 10000 + date.month * 100 + date.day;
  }

  /// Configuración de los detalles de notificación
  static NotificationDetails _notificationDetails() {
    return const NotificationDetails(
      android: AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: _channelDesc,
        importance: Importance.high,
        priority: Priority.high,
        icon: '@mipmap/launcher_icon',
        playSound: true,
        enableVibration: true,
      ),
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    );
  }

  /// Programa las notificaciones de recordatorio para las rutinas pendientes del usuario.
  /// Si los recordatorios están desactivados, cancela todas las alertas programadas.
  static Future<void> scheduleWorkoutRemindersForRoutines({
    required List<Map<String, dynamic>> allRoutines,
    required Set<String> completedRoutineIds,
  }) async {
    if (!_isInitialized) {
      await init();
    }
    if (!_isInitialized) {
      debugPrint('[NotificationService] No disponible o no inicializado en esta plataforma.');
      return;
    }

    final isEnabled = await areRemindersEnabled();
    if (!isEnabled) {
      debugPrint('[NotificationService] Recordatorios desactivados por el usuario. Cancelando alertas.');
      await cancelAllReminders();
      return;
    }

    final reminderTime = await getReminderTime();
    final now = DateTime.now();

    final details = _notificationDetails();
    int scheduledCount = 0;

    for (final routine in allRoutines) {
      final routineId = (routine['id'] ?? '').toString();
      final dateTs = routine['date'] as Timestamp?;
      if (dateTs == null) continue;

      final routineDate = dateTs.toDate();
      final localDate = DateTime(routineDate.year, routineDate.month, routineDate.day);

      // Si la rutina ya fue completada, cancelamos cualquier alerta pendiente para esa fecha
      if (routineId.isNotEmpty && completedRoutineIds.contains(routineId)) {
        await cancelReminderForDate(localDate);
        continue;
      }

      // Calculamos el momento exacto de la notificación
      final scheduledDateTime = DateTime(
        localDate.year,
        localDate.month,
        localDate.day,
        reminderTime.hour,
        reminderTime.minute,
      );

      // Si la fecha y hora ya pasaron, no programamos para el pasado
      if (scheduledDateTime.isBefore(now)) {
        continue;
      }

      final notificationId = _getNotificationIdForDate(localDate);
      final routineName = (routine['name'] ?? 'Entrenamiento del día').toString();

      try {
        final tzScheduled = tz.TZDateTime.from(scheduledDateTime, tz.local);

        await _notificationsPlugin.zonedSchedule(
          id: notificationId,
          title: '¡Hoy se entrena! 💪',
          body: 'Tienes programada tu rutina: $routineName',
          scheduledDate: tzScheduled,
          notificationDetails: details,
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          payload: routineId,
        );
        scheduledCount++;
      } catch (e) {
        // Fallback por si la zona horaria falla o no tiene permisos de alarma exacta
        try {
          final tzScheduled = tz.TZDateTime.from(scheduledDateTime, tz.local);
          await _notificationsPlugin.zonedSchedule(
            id: notificationId,
            title: '¡Hoy se entrena! 💪',
            body: 'Tienes programada tu rutina: $routineName',
            scheduledDate: tzScheduled,
            notificationDetails: details,
            androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
            payload: routineId,
          );
          scheduledCount++;
        } catch (innerError) {
          debugPrint('[NotificationService] No se pudo programar recordatorio para $localDate: $innerError');
        }
      }
    }

    debugPrint('[NotificationService] Programadas $scheduledCount notificaciones de rutina.');
  }

  /// Cancela la notificación para una fecha específica
  static Future<void> cancelReminderForDate(DateTime date) async {
    if (!_isInitialized) return;
    try {
      final id = _getNotificationIdForDate(date);
      await _notificationsPlugin.cancel(id: id);
    } catch (e) {
      debugPrint('[NotificationService] No se pudo cancelar recordatorio para $date: $e');
    }
  }

  /// Cancela todas las notificaciones programadas
  static Future<void> cancelAllReminders() async {
    if (!_isInitialized) return;
    try {
      await _notificationsPlugin.cancelAll();
    } catch (e) {
      debugPrint('[NotificationService] No se pudieron cancelar recordatorios: $e');
    }
  }

  /// Muestra una notificación instantánea de prueba
  static Future<void> showInstantTestNotification() async {
    if (!_isInitialized) await init();
    if (!_isInitialized) return;
    try {
      await requestPermissions();

      await _notificationsPlugin.show(
        id: 999999,
        title: '¡Recordatorios activos! 🔔',
        body: 'Te notificaremos los días que tengas una rutina asignada a la hora configurada.',
        notificationDetails: _notificationDetails(),
      );
    } catch (e) {
      debugPrint('[NotificationService] No se pudo mostrar notificación de prueba: $e');
    }
  }
}
