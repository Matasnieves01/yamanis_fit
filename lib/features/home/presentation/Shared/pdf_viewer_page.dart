import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:yamanis_fit/models/pdf_resource.dart';

class PdfViewerPage extends StatelessWidget {
  final PdfResource resource;
  const PdfViewerPage({super.key, required this.resource});

  @override
  Widget build(BuildContext context) {
    final Color backgroundColor = const Color(0xFF11151C);
    final Color primaryColor = const Color(0xFFAEE084);

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: Text(
          resource.name,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: PdfViewer.uri(
        Uri.parse(resource.url),
        params: PdfViewerParams(
          loadingBannerBuilder: (context, bytesDownloaded, totalBytes) {
            return Center(
              child: CircularProgressIndicator(
                value: totalBytes != null ? bytesDownloaded / totalBytes : null,
                color: primaryColor,
              ),
            );
          },
          errorBannerBuilder: (context, error, stackTrace, documentRef) {
            return Center(
              child: Text(
                'Error al cargar PDF: $error',
                style: const TextStyle(color: Colors.redAccent),
              ),
            );
          },
        ),
      ),
    );
  }
}
