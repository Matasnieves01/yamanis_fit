import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:yamanis_fit/core/services/pdf_cache_service.dart';
import 'package:yamanis_fit/core/widgets/app_back_button.dart';

class UploadPdfPage extends StatefulWidget {
  const UploadPdfPage({super.key});

  @override
  State<UploadPdfPage> createState() => _UploadPdfPageState();
}

class _UploadPdfPageState extends State<UploadPdfPage> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _urlController = TextEditingController();
  final TextEditingController _coverController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();
  bool _isUploading = false;
  bool _isFree = true;

  final Color backgroundColor = const Color(0xFF11151C);
  final Color surfaceColor = const Color(0xFF1A222D);
  final Color primaryColor = const Color(0xFFAEE084);
  final Color secondaryColor = const Color(0xFF89AC76);

  @override
  void initState() {
    super.initState();
    _urlController.addListener(() => setState(() {}));
    _coverController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _nameController.dispose();
    _urlController.dispose();
    _coverController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  String? _getPreviewCoverUrl() {
    final customCover = _coverController.text.trim();
    if (customCover.isNotEmpty) return customCover;

    final driveUrl = _urlController.text.trim();
    return PdfCacheService.getDriveThumbnailUrl(driveUrl, width: 800);
  }

  Future<void> _saveResource() async {
    final name = _nameController.text.trim();
    final link = _urlController.text.trim();
    final cover = _coverController.text.trim();

    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor, ingresa un nombre para el recurso')),
      );
      return;
    }

    if (link.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor, pega un enlace de Google Drive o similar')),
      );
      return;
    }

    setState(() => _isUploading = true);

    try {
      final finalUrl = PdfCacheService.normalizeDriveUrl(link);
      double price = 0.0;
      if (!_isFree) {
        final cleanPrice = _priceController.text.trim().replaceAll(',', '.');
        price = double.tryParse(cleanPrice) ?? 0.0;
        if (price <= 0.0) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Por favor, ingresa un precio válido mayor a 0 para el recurso')),
          );
          return;
        }
      }

      await FirebaseFirestore.instance.collection('resources').add({
        'name': name,
        'url': finalUrl,
        if (cover.isNotEmpty) 'thumbnailUrl': cover,
        'createdAt': FieldValue.serverTimestamp(),
        'price': _isFree ? 0.0 : price,
        'isFree': _isFree,
      });

      if (!mounted) return;
      Navigator.pop(context, true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Recurso guardado con éxito')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al guardar: $e')),
      );
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  InputDecoration _inputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: primaryColor),
      filled: true,
      fillColor: Colors.white.withValues(alpha: 0.05),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: primaryColor, width: 2),
      ),
      labelStyle: TextStyle(color: primaryColor),
    );
  }

  @override
  Widget build(BuildContext context) {
    final previewUrl = _getPreviewCoverUrl();

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('AÑADIR RECURSO', style: TextStyle(fontWeight: FontWeight.w900)),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: const AppBackButton(),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Detalles del Recurso',
              style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 18),
            TextField(
              controller: _nameController,
              style: const TextStyle(color: Colors.white),
              decoration: _inputDecoration('Nombre (Ej: Guía de Hipertrofia)', Icons.title_rounded),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _urlController,
              style: const TextStyle(color: Colors.white),
              decoration: _inputDecoration('Enlace de Google Drive', Icons.link_rounded).copyWith(
                helperText: 'Pega el enlace de "Compartir" de Google Drive',
                helperStyle: const TextStyle(color: Colors.white38),
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _coverController,
              style: const TextStyle(color: Colors.white),
              decoration: _inputDecoration('URL de Portada (Opcional)', Icons.image_rounded).copyWith(
                helperText: 'Opcional. Si es Google Drive, la portada se genera sola',
                helperStyle: const TextStyle(color: Colors.white38),
              ),
            ),

            // Vista previa en vivo de la portada del PDF
            if (previewUrl != null) ...[
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: surfaceColor,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: primaryColor.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        width: 70,
                        height: 95,
                        color: Colors.black26,
                        child: Image.network(
                          previewUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => Center(
                            child: Icon(Icons.picture_as_pdf_rounded, color: primaryColor, size: 36),
                          ),
                          loadingBuilder: (context, child, progress) {
                            if (progress == null) return child;
                            return Center(
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: primaryColor,
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.check_circle_rounded, color: primaryColor, size: 16),
                              const SizedBox(width: 6),
                              Text(
                                'Portada Detectada',
                                style: TextStyle(
                                  color: primaryColor,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Esta imagen se mostrará automáticamente como la carátula de tu guía en la biblioteca.',
                            style: TextStyle(color: Colors.white70, fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: surfaceColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      const Text('Acceso Gratuito', style: TextStyle(color: Colors.white70, fontSize: 16)),
                      const Spacer(),
                      Switch(
                        value: _isFree,
                        onChanged: (val) => setState(() => _isFree = val),
                        activeThumbColor: primaryColor,
                        activeTrackColor: primaryColor.withValues(alpha: 0.4),
                      ),
                    ],
                  ),
                  if (!_isFree) ...[
                    const Divider(color: Colors.white10, height: 24),
                    TextField(
                      controller: _priceController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      style: const TextStyle(color: Colors.white),
                      decoration: _inputDecoration('Precio (\$ USD)', Icons.attach_money_rounded).copyWith(
                        hintText: 'Ej: 15.00',
                        hintStyle: const TextStyle(color: Colors.white38),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _isUploading ? null : _saveResource,
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  foregroundColor: backgroundColor,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 0,
                ),
                child: _isUploading
                    ? const CircularProgressIndicator(color: Color(0xFF11151C))
                    : const Text(
                        'GUARDAR RECURSO',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
