import 'package:flutter/foundation.dart';
import 'package:shorebird_code_push/shorebird_code_push.dart';

class OtaService {
  static final ShorebirdUpdater _updater = ShorebirdUpdater();

  /// Indica si el motor de Shorebird está activo en esta compilación.
  /// Será false en modo debug / emulador y true cuando se compile con shorebird release.
  static bool get isAvailable => _updater.isAvailable;

  /// Obtiene el número del parche actual si existe (ej. parche #1, #2...).
  static Future<int?> getCurrentPatchNumber() async {
    if (!isAvailable) return null;
    try {
      final patch = await _updater.readCurrentPatch();
      return patch?.number;
    } catch (e) {
      debugPrint('[OtaService] Error al leer el parche actual: $e');
      return null;
    }
  }

  /// Comprueba si hay actualizaciones y las descarga silenciosamente en segundo plano.
  /// Las actualizaciones de Dart se aplican automáticamente en el próximo inicio de la app.
  static Future<UpdateStatus> checkAndDownloadUpdate({
    void Function(UpdateStatus status)? onStatusChange,
  }) async {
    if (!isAvailable) {
      debugPrint('[OtaService] Shorebird inactivo en este entorno (normal en desarrollo local).');
      return UpdateStatus.unavailable;
    }

    try {
      final status = await _updater.checkForUpdate();
      onStatusChange?.call(status);

      if (status == UpdateStatus.outdated) {
        debugPrint('[OtaService] Nuevo parche OTA detectado. Descargando...');
        await _updater.update();
        debugPrint('[OtaService] Parche instalado. Se activará en el próximo reinicio.');
        onStatusChange?.call(UpdateStatus.restartRequired);
        return UpdateStatus.restartRequired;
      }

      return status;
    } on UpdateException catch (e) {
      debugPrint('[OtaService] Excepción de actualización: ${e.message} (${e.reason})');
      return UpdateStatus.unavailable;
    } catch (e) {
      debugPrint('[OtaService] Error al verificar actualización OTA: $e');
      return UpdateStatus.unavailable;
    }
  }
}
