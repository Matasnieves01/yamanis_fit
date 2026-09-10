import 'package:flutter_test/flutter_test.dart';
import 'package:yamanis_fit/core/services/pdf_cache_service.dart';

void main() {
  group('PdfCacheService Tests', () {
    test('normalizeDriveUrl correctly converts /file/d/ links', () {
      const inputUrl = 'https://drive.google.com/file/d/1a2b3c4d5e/view?usp=sharing';
      final result = PdfCacheService.normalizeDriveUrl(inputUrl);
      expect(result, 'https://drive.google.com/uc?export=download&id=1a2b3c4d5e&confirm=t');
    });

    test('normalizeDriveUrl correctly converts id query parameter links', () {
      const inputUrl = 'https://drive.google.com/open?id=xyz987654';
      final result = PdfCacheService.normalizeDriveUrl(inputUrl);
      expect(result, 'https://drive.google.com/uc?export=download&id=xyz987654&confirm=t');
    });

    test('normalizeDriveUrl keeps non-Drive URLs unchanged', () {
      const inputUrl = 'https://firebasestorage.googleapis.com/v0/b/app/test.pdf';
      final result = PdfCacheService.normalizeDriveUrl(inputUrl);
      expect(result, inputUrl);
    });
  });
}
