import 'dart:async';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

class PdfCacheService {
  static const String _cacheFolder = 'pdf_cache';

  /// Obtiene la carpeta local de caché para PDFs
  static Future<Directory> _getCacheDirectory() async {
    final baseDir = await getApplicationSupportDirectory();
    final cacheDir = Directory('${baseDir.path}/$_cacheFolder');
    if (!await cacheDir.exists()) {
      await cacheDir.create(recursive: true);
    }
    return cacheDir;
  }

  /// Normaliza URLs de Google Drive para descarga directa si es necesario
  static String normalizeDriveUrl(String url) {
    if (!url.contains('drive.google.com')) {
      return url;
    }

    try {
      final uri = Uri.parse(url);
      String? fileId;
      if (uri.path.contains('/file/d/')) {
        final segments = uri.pathSegments;
        final dIndex = segments.indexOf('d');
        if (dIndex != -1 && dIndex + 1 < segments.length) {
          fileId = segments[dIndex + 1];
        }
      } else {
        fileId = uri.queryParameters['id'];
      }

      if (fileId != null && fileId.isNotEmpty) {
        // &confirm=t ayuda a omitir pantallas de advertencia de virus en Drive
        return 'https://drive.google.com/uc?export=download&id=$fileId&confirm=t';
      }
    } catch (_) {
      // Si falla el parsing, se devuelve la URL original
    }
    return url;
  }

  /// Genera un nombre de archivo seguro y único para el recurso
  static String _getFileName(String url, {String? resourceId}) {
    if (resourceId != null && resourceId.trim().isNotEmpty) {
      final safeId = resourceId.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
      return 'pdf_$safeId.pdf';
    }
    // Si no hay resourceId, se usa un hash estable de la URL
    final hash = url.hashCode.abs();
    return 'pdf_$hash.pdf';
  }

  /// Obtiene el archivo en caché si ya existe y es válido
  static Future<File?> getCachedFile(String url, {String? resourceId}) async {
    try {
      final cacheDir = await _getCacheDirectory();
      final fileName = _getFileName(url, resourceId: resourceId);
      final file = File('${cacheDir.path}/$fileName');

      if (await file.exists() && await file.length() > 0) {
        return file;
      }
    } catch (e) {
      // Ignorar error al leer caché y proceder a descarga
    }
    return null;
  }

  /// Descarga el archivo PDF y lo almacena en la caché local.
  /// Informa el progreso a través de [onProgress] (bytesDescargados, totalBytes).
  static Future<File> downloadAndCachePdf({
    required String url,
    String? resourceId,
    void Function(int received, int? total)? onProgress,
  }) async {
    final cacheDir = await _getCacheDirectory();
    final fileName = _getFileName(url, resourceId: resourceId);
    final targetFile = File('${cacheDir.path}/$fileName');
    final tempFile = File('${cacheDir.path}/$fileName.tmp');

    // Si ya existe el archivo final, retornarlo inmediatamente
    if (await targetFile.exists() && await targetFile.length() > 0) {
      return targetFile;
    }

    // Limpiar temporal anterior si existía
    if (await tempFile.exists()) {
      await tempFile.delete();
    }

    final downloadUrl = normalizeDriveUrl(url);
    final httpClient = HttpClient()
      ..badCertificateCallback = (cert, host, port) => true;

    IOSink? sink;
    try {
      final uri = Uri.parse(downloadUrl);
      final request = await httpClient.getUrl(uri);
      request.headers.set(
        HttpHeaders.userAgentHeader,
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
      );
      request.headers.set(HttpHeaders.acceptHeader, '*/*');

      final response = await request.close();

      if (response.statusCode != HttpStatus.ok) {
        throw HttpException(
          'Servidor devolvió error ${response.statusCode}: ${response.reasonPhrase}',
          uri: uri,
        );
      }

      final totalBytes = response.contentLength >= 0 ? response.contentLength : null;
      int receivedBytes = 0;

      sink = tempFile.openWrite();

      await for (final chunk in response) {
        sink.add(chunk);
        receivedBytes += chunk.length;
        if (onProgress != null) {
          onProgress(receivedBytes, totalBytes);
        }
      }

      await sink.flush();
      await sink.close();
      sink = null;

      // Verificar que el archivo descargado sea un PDF legítimo (empieza con %PDF)
      final headerCheckBytes = await tempFile.openRead(0, 5).first;
      final header = String.fromCharCodes(headerCheckBytes);
      if (!header.startsWith('%PDF')) {
        await tempFile.delete();
        throw const FormatException(
          'El archivo descargado no es un PDF válido. Es posible que el enlace de Google Drive requiera permisos públicos o haya superado su cuota de acceso.',
        );
      }

      // Renombrado atómico: del temporal al archivo definitivo
      if (await targetFile.exists()) {
        await targetFile.delete();
      }
      await tempFile.rename(targetFile.path);

      return targetFile;
    } catch (e) {
      if (sink != null) {
        try {
          await sink.close();
        } catch (_) {}
      }
      if (await tempFile.exists()) {
        try {
          await tempFile.delete();
        } catch (_) {}
      }
      rethrow;
    } finally {
      httpClient.close();
    }
  }

  /// Elimina el archivo de caché correspondiente
  static Future<void> removeCachedFile(String url, {String? resourceId}) async {
    try {
      final cacheDir = await _getCacheDirectory();
      final fileName = _getFileName(url, resourceId: resourceId);
      final file = File('${cacheDir.path}/$fileName');
      if (await file.exists()) {
        await file.delete();
      }
    } catch (_) {}
  }
}
