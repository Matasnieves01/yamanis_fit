import 'package:flutter/material.dart';

class BrandedLoadingScreen extends StatelessWidget {
  const BrandedLoadingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    const Color brandBackground = Color(0xFF11151C);
    const Color brandPrimary = Color(0xFFAEE084);

    return Scaffold(
      backgroundColor: brandBackground,
      body: SizedBox(
        width: double.infinity,
        height: double.infinity,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Logo circular perfecto
            ClipOval(
              child: Image.asset(
                'assets/logos/logo_padding.png',
                height: 160,
                width: 160,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Container(
                  height: 160,
                  width: 160,
                  color: brandPrimary.withOpacity(0.1),
                  child: const Icon(Icons.fitness_center_rounded,
                      size: 64, color: brandPrimary),
                ),
              ),
            ),
            const SizedBox(height: 32),
            const CircularProgressIndicator(
              strokeWidth: 3,
              valueColor: AlwaysStoppedAnimation<Color>(brandPrimary),
            ),
          ],
        ),
      ),
    );
  }
}
