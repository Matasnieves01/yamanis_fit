import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class UploadPdfPage extends StatefulWidget {
  const UploadPdfPage({super.key});

  @override
  State<UploadPdfPage> createState() => _UploadPdfPageState();
}

class _UploadPdfPageState extends State<UploadPdfPage> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _urlController = TextEditingController();
  final TextEditingController _priceController = TextEditingController(text: '0.0');
  bool _isUploading = false;
  bool _isFree = true;

  final Color backgroundColor = const Color(0xFF11151C);
  final Color surfaceColor = const Color(0xFF55768C);
  final Color primaryColor = const Color(0xFFAEE084);
  final Color secondaryColor = const Color(0xFF89AC76);

  @override
  void dispose() {
    _nameController.dispose();
    _urlController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  Future<void> _saveResource() async {
    final name = _nameController.text.trim();
    final link = _urlController.text.trim();
    
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
      String finalUrl = link;

      // Conversión automática de Google Drive a enlace directo
      if (finalUrl.contains('drive.google.com')) {
        final uri = Uri.parse(finalUrl);
        String? fileId;
        if (uri.path.contains('/file/d/')) {
          fileId = uri.pathSegments[uri.pathSegments.indexOf('d') + 1];
        } else {
          fileId = uri.queryParameters['id'];
        }

        if (fileId != null) {
          finalUrl = 'https://drive.google.com/uc?export=download&id=$fileId';
          print('Enlace convertido a descarga directa: $finalUrl');
        }
      }

      final price = double.tryParse(_priceController.text) ?? 0.0;

      await FirebaseFirestore.instance.collection('resources').add({
        'name': name,
        'url': finalUrl,
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
      fillColor: Colors.white.withOpacity(0.05),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
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
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: const Text('AÑADIR RECURSO', style: TextStyle(fontWeight: FontWeight.w900)),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
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
              decoration: _inputDecoration('Nombre (Ej: Guía de Nutrición)', Icons.title_rounded),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _urlController,
              style: const TextStyle(color: Colors.white),
              decoration: _inputDecoration('Enlace de Google Drive', Icons.link_rounded).copyWith(
                helperText: 'Pega el enlace de "Compartir" de Google Drive',
                helperStyle: const TextStyle(color: Colors.white38),
              ),
            ),
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: surfaceColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
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
                        activeColor: primaryColor,
                      ),
                    ],
                  ),
                  if (!_isFree) ...[
                    const Divider(color: Colors.white10, height: 24),
                    TextField(
                      controller: _priceController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      style: const TextStyle(color: Colors.white),
                      decoration: _inputDecoration('Precio (\$)', Icons.attach_money_rounded),
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
