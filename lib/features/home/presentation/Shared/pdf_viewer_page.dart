import 'dart:io';
import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:yamanis_fit/core/services/pdf_cache_service.dart';
import 'package:yamanis_fit/core/widgets/app_back_button.dart';
import 'package:yamanis_fit/models/pdf_resource.dart';

class PdfViewerPage extends StatefulWidget {
  final PdfResource resource;
  const PdfViewerPage({super.key, required this.resource});

  @override
  State<PdfViewerPage> createState() => _PdfViewerPageState();
}

class _PdfViewerPageState extends State<PdfViewerPage> {
  File? _pdfFile;
  bool _isLoading = true;
  bool _isFromCache = false;
  String? _errorMessage;
  int _receivedBytes = 0;
  int? _totalBytes;

  final Color _backgroundColor = const Color(0xFF11151C);
  final Color _surfaceColor = const Color(0xFF1E2530);
  final Color _primaryColor = const Color(0xFFAEE084);

  @override
  void initState() {
    super.initState();
    _loadPdf();
  }

  Future<void> _loadPdf({bool forceRefresh = false}) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _receivedBytes = 0;
      _totalBytes = null;
    });

    try {
      if (forceRefresh) {
        await PdfCacheService.removeCachedFile(
          widget.resource.url,
          resourceId: widget.resource.id,
        );
      } else {
        // 1. Verificar si ya está en la caché local
        final cached = await PdfCacheService.getCachedFile(
          widget.resource.url,
          resourceId: widget.resource.id,
        );
        if (cached != null && mounted) {
          setState(() {
            _pdfFile = cached;
            _isLoading = false;
            _isFromCache = true;
          });
          return;
        }
      }

      // 2. Descargar y guardar en caché local
      final file = await PdfCacheService.downloadAndCachePdf(
        url: widget.resource.url,
        resourceId: widget.resource.id,
        onProgress: (received, total) {
          if (mounted) {
            setState(() {
              _receivedBytes = received;
              _totalBytes = total;
            });
          }
        },
      );

      if (mounted) {
        setState(() {
          _pdfFile = file;
          _isLoading = false;
          _isFromCache = false;
        });

        if (forceRefresh) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('PDF actualizado con éxito desde la nube'),
              duration: Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = e
              .toString()
              .replaceFirst('Exception: ', '')
              .replaceFirst('FormatException: ', '');
        });
      }
    }
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              widget.resource.name,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            if (!_isLoading && _pdfFile != null)
              Row(
                children: [
                  Icon(
                    _isFromCache ? Icons.bolt_rounded : Icons.cloud_done_rounded,
                    size: 12,
                    color: _primaryColor,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _isFromCache ? 'En memoria local (rápido)' : 'Descargado y guardado',
                    style: TextStyle(
                      fontSize: 11,
                      color: _primaryColor.withValues(alpha: 0.85),
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ),
          ],
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: const AppBackButton(),
        actions: [
          if (!_isLoading && _pdfFile != null)
            IconButton(
              icon: const Icon(Icons.refresh_rounded),
              tooltip: 'Volver a descargar desde la nube',
              onPressed: () => _loadPdf(forceRefresh: true),
            ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return _buildLoadingView();
    }

    if (_errorMessage != null) {
      return _buildErrorView();
    }

    if (_pdfFile != null) {
      return PdfViewer.file(
        _pdfFile!.path,
        params: PdfViewerParams(
          loadingBannerBuilder: (context, bytesDownloaded, totalBytes) {
            return Center(
              child: CircularProgressIndicator(
                value: totalBytes != null ? bytesDownloaded / totalBytes : null,
                color: _primaryColor,
              ),
            );
          },
          errorBannerBuilder: (context, error, stackTrace, documentRef) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.broken_image_outlined, size: 56, color: Colors.redAccent),
                    const SizedBox(height: 16),
                    Text(
                      'Error al renderizar PDF: $error',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.redAccent),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: () => _loadPdf(forceRefresh: true),
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('Reintentar descarga'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _primaryColor,
                        foregroundColor: _backgroundColor,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      );
    }

    return const SizedBox.shrink();
  }

  Widget _buildLoadingView() {
    double? progress;
    if (_totalBytes != null && _totalBytes! > 0) {
      progress = (_receivedBytes / _totalBytes!).clamp(0.0, 1.0);
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: _surfaceColor,
                shape: BoxShape.circle,
                border: Border.all(color: _primaryColor.withValues(alpha: 0.3), width: 2),
              ),
              child: Icon(Icons.picture_as_pdf_rounded, size: 48, color: _primaryColor),
            ),
            const SizedBox(height: 24),
            Text(
              'Preparando documento...',
              style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              progress != null
                  ? '${(progress * 100).toStringAsFixed(0)}% (${_formatBytes(_receivedBytes)} / ${_formatBytes(_totalBytes!)})'
                  : _receivedBytes > 0
                      ? '${_formatBytes(_receivedBytes)} descargados...'
                      : 'Conectando con el servidor...',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 13),
            ),
            const SizedBox(height: 20),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: progress,
                backgroundColor: _surfaceColor,
                valueColor: AlwaysStoppedAnimation<Color>(_primaryColor),
                minHeight: 6,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.info_outline, size: 14, color: Colors.white38),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    'Se guardará en tu dispositivo para abrirlo al instante en futuras visitas.',
                    style: TextStyle(color: Colors.white38, fontSize: 12),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.redAccent.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.error_outline_rounded, size: 50, color: Colors.redAccent),
            ),
            const SizedBox(height: 20),
            const Text(
              'No se pudo cargar el documento',
              style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            Text(
              _errorMessage ?? 'Ocurrió un error inesperado al descargar el archivo.',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.65), fontSize: 13),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => _loadPdf(forceRefresh: true),
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Reintentar'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _primaryColor,
                foregroundColor: _backgroundColor,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
