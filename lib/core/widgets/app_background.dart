import 'package:flutter/material.dart';

/// Widget de fondo unificado para toda la aplicación Yamanis Fit / YO Fit.
/// Proporciona el fondo OLED oscuro con degradado y resplandores ambientales
/// superiores (magenta/rosa de la marca) e inferiores (verde lima).
class AppBackground extends StatelessWidget {
  final Widget child;
  final bool showTopGlow;
  final bool showBottomGlow;

  const AppBackground({
    super.key,
    required this.child,
    this.showTopGlow = true,
    this.showBottomGlow = true,
  });

  static const Color backgroundColor = Color(0xFF11151C);
  static const Color primaryColor = Color(0xFFAEE084);
  static const Color brandRose = Color(0xFFE11D48);

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Base dark background gradient
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0xFF141923),
                backgroundColor,
              ],
            ),
          ),
        ),

        // Ambient glow top (soft magenta/rose matching the YO Fit brand)
        if (showTopGlow)
          Positioned(
            top: -60,
            left: 0,
            right: 0,
            child: IgnorePointer(
              child: Center(
                child: Container(
                  width: 320,
                  height: 320,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        brandRose.withValues(alpha: 0.16),
                        const Color(0xFFBE123C).withValues(alpha: 0.05),
                        Colors.transparent,
                      ],
                      stops: const [0.0, 0.5, 1.0],
                    ),
                  ),
                ),
              ),
            ),
          ),

        // Ambient glow bottom-right (soft lime green accent)
        if (showBottomGlow)
          Positioned(
            bottom: -50,
            right: -50,
            child: IgnorePointer(
              child: Container(
                width: 260,
                height: 260,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      primaryColor.withValues(alpha: 0.10),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ),

        // Child content
        child,
      ],
    );
  }
}
