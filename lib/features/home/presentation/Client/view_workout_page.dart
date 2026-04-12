import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

class ViewWorkoutPage extends StatefulWidget {
  final String workoutId;
  final bool isAdmin;

  const ViewWorkoutPage({
    super.key,
    required this.workoutId,
    this.isAdmin = false,
  });

  @override
  State<ViewWorkoutPage> createState() => _ViewWorkoutPageState();
}

class _ViewWorkoutPageState extends State<ViewWorkoutPage> {
  Map<String, dynamic>? workoutData;
  bool isLoading = true;
  YoutubePlayerController? _controller;

  final Color backgroundColor = const Color(0xFF11151C);
  final Color surfaceColor = const Color(0xFF55768C);
  final Color primaryColor = const Color(0xFFAEE084);

  @override
  void initState() {
    super.initState();
    loadWorkout();
  }

  Future<void> loadWorkout() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('workouts')
          .doc(widget.workoutId)
          .get();

      if (doc.exists) {
        workoutData = doc.data();
        final String videoUrl = workoutData?['videoUrl'] ?? "";
        final videoId = YoutubePlayer.convertUrlToId(videoUrl);

        if (videoId != null) {
          _controller = YoutubePlayerController(
            initialVideoId: videoId,
            flags: const YoutubePlayerFlags(
              autoPlay: false,
              mute: false,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint("Error loading workout: $e");
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  Future<void> _openInYoutube() async {
    final String url = workoutData?['videoUrl'] ?? "";
    if (url.isEmpty) return;

    final Uri uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo abrir YouTube')),
        );
      }
    }
  }

  Future<void> _deleteWorkout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: backgroundColor,
        title: const Text('Eliminar Ejercicio', style: TextStyle(color: Colors.white)),
        content: const Text('¿Estás seguro de que quieres eliminar este ejercicio?',
            style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('CANCELAR', style: TextStyle(color: Colors.white60)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('ELIMINAR', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await FirebaseFirestore.instance.collection('workouts').doc(widget.workoutId).delete();
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Ejercicio eliminado')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e')),
          );
        }
      }
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Scaffold(
        backgroundColor: backgroundColor,
        body: Center(child: CircularProgressIndicator(color: primaryColor)),
      );
    }

    if (workoutData == null) {
      return Scaffold(
        backgroundColor: backgroundColor,
        appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0),
        body: const Center(child: Text("Ejercicio no encontrado", style: TextStyle(color: Colors.white))),
      );
    }

    return Scaffold(
      backgroundColor: backgroundColor,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(
          (workoutData?['name'] ?? "EJERCICIO").toString().toUpperCase(),
          style: const TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.5, fontSize: 16),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(Icons.cast, color: primaryColor),
            tooltip: 'Transmitir a TV (Abre YouTube)',
            onPressed: _openInYoutube,
          ),
          if (widget.isAdmin)
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
              onPressed: _deleteWorkout,
            ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_controller != null)
              Container(
                decoration: BoxDecoration(
                  boxShadow: [
                    BoxShadow(
                      color: primaryColor.withValues(alpha: 0.1),
                      blurRadius: 20,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                child: YoutubePlayer(
                  controller: _controller!,
                  showVideoProgressIndicator: true,
                  progressIndicatorColor: primaryColor,
                  progressColors: ProgressBarColors(
                    playedColor: primaryColor,
                    handleColor: primaryColor,
                  ),
                ),
              )
            else
              Container(
                height: 200,
                width: double.infinity,
                color: surfaceColor.withValues(alpha: 0.1),
                child: const Center(
                  child: Icon(Icons.videocam_off, color: Colors.white24, size: 50),
                ),
              ),
            const SizedBox(height: 32),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: primaryColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: primaryColor.withValues(alpha: 0.2)),
                        ),
                        child: Text(
                          "DESCRIPCIÓN",
                          style: TextStyle(
                            color: primaryColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 10,
                            letterSpacing: 2,
                          ),
                        ),
                      ),
                      TextButton.icon(
                        onPressed: _openInYoutube,
                        icon: const Icon(Icons.open_in_new, size: 16),
                        label: const Text("Abrir en YouTube", style: TextStyle(fontSize: 12)),
                        style: TextButton.styleFrom(foregroundColor: primaryColor),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: surfaceColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: surfaceColor.withValues(alpha: 0.1)),
                    ),
                    child: Text(
                      workoutData?['description'] ?? "No hay descripción disponible para este ejercicio.",
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.9),
                        fontSize: 16,
                        height: 1.6,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
