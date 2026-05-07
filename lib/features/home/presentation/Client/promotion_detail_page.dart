import 'package:flutter/material.dart';
import 'package:yamanis_fit/models/promotion.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';

class PromotionDetailPage extends StatefulWidget {
  final Promotion promotion;

  const PromotionDetailPage({super.key, required this.promotion});

  @override
  State<PromotionDetailPage> createState() => _PromotionDetailPageState();
}

class _PromotionDetailPageState extends State<PromotionDetailPage> {
  final Color backgroundColor = const Color(0xFF11151C);
  final Color surfaceColor = const Color(0xFF55768C);
  final Color primaryColor = const Color(0xFFAEE084);

  late PageController _pageController;
  int _currentVideoIndex = 0;
  late List<YoutubePlayerController> _youtubeControllers;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();

    // Initialize YouTube controllers for each video
    _youtubeControllers = widget.promotion.videoUrls.map((videoId) {
      return YoutubePlayerController(
        initialVideoId: videoId,
        flags: const YoutubePlayerFlags(
          autoPlay: false,
          mute: false,
          isLive: false,
          forceHD: false,
        ),
      );
    }).toList();
  }

  @override
  void dispose() {
    _pageController.dispose();
    for (var controller in _youtubeControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: const Text('PROMOCIÓN', style: TextStyle(fontWeight: FontWeight.w900)),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image header
            if (widget.promotion.imageUrl.isNotEmpty)
              ClipRRect(
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(24)),
                child: Image.network(
                  widget.promotion.imageUrl,
                  width: double.infinity,
                  height: 280,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Container(
                    width: double.infinity,
                    height: 280,
                    color: surfaceColor.withValues(alpha: 0.2),
                    child: const Icon(Icons.image_outlined, color: Colors.white24, size: 80),
                  ),
                ),
              ),

            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title
                  Text(
                    widget.promotion.title.toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.greenAccent.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.greenAccent.withValues(alpha: 0.35)),
                    ),
                    child: const Text(
                      'DISPONIBLE GRATIS',
                      style: TextStyle(color: Colors.greenAccent, fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Description title
                  const Text(
                    'SOBRE ESTA PROMOCIÓN',
                    style: TextStyle(color: Colors.white54, fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 1.2),
                  ),
                  const SizedBox(height: 12),

                  // Description
                  Text(
                    widget.promotion.description,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 15,
                      height: 1.6,
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Videos section
                  Text(
                    'VIDEOS (${widget.promotion.videoUrls.length})',
                    style: const TextStyle(color: Colors.white54, fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 1.2),
                  ),
                  const SizedBox(height: 16),

                  // Video player with carousel
                  if (widget.promotion.videoUrls.isNotEmpty)
                    Column(
                      children: [
                        // Video player
                        Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            color: Colors.black,
                          ),
                          child: YoutubePlayer(
                            controller: _youtubeControllers[_currentVideoIndex],
                            showVideoProgressIndicator: true,
                            progressIndicatorColor: primaryColor,
                            onReady: () {},
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Video indicators and navigation
                        if (widget.promotion.videoUrls.length > 1)
                          Column(
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: List.generate(
                                  widget.promotion.videoUrls.length,
                                  (index) => GestureDetector(
                                    onTap: () {
                                      setState(() => _currentVideoIndex = index);
                                      _youtubeControllers[index].play();
                                    },
                                    child: Container(
                                      margin: const EdgeInsets.symmetric(horizontal: 4),
                                      width: 10,
                                      height: 10,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: _currentVideoIndex == index
                                            ? primaryColor
                                            : Colors.white.withValues(alpha: 0.3),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'Video ${_currentVideoIndex + 1} de ${widget.promotion.videoUrls.length}',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.6),
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                      ],
                    )
                  else
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(40),
                      decoration: BoxDecoration(
                        color: surfaceColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: surfaceColor.withValues(alpha: 0.2)),
                      ),
                      child: const Center(
                        child: Text(
                          'No hay videos disponibles',
                          style: TextStyle(color: Colors.white70, fontSize: 14),
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

