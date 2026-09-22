import 'package:flutter/material.dart';
import 'package:yamanis_fit/core/services/biometrics_service.dart';

class QuickWeightDialog extends StatefulWidget {
  final String userId;
  final double? currentWeight;
  final VoidCallback onSaved;

  const QuickWeightDialog({
    super.key,
    required this.userId,
    required this.currentWeight,
    required this.onSaved,
  });

  static Future<void> show(
    BuildContext context, {
    required String userId,
    required double? currentWeight,
    required VoidCallback onSaved,
  }) {
    return showDialog(
      context: context,
      builder: (context) => QuickWeightDialog(
        userId: userId,
        currentWeight: currentWeight,
        onSaved: onSaved,
      ),
    );
  }

  @override
  State<QuickWeightDialog> createState() => _QuickWeightDialogState();
}

class _QuickWeightDialogState extends State<QuickWeightDialog> {
  late TextEditingController _weightController;
  bool _isLoading = false;

  final Color primaryColor = const Color(0xFFAEE084);
  final Color backgroundColor = const Color(0xFF11151C);
  final Color surfaceColor = const Color(0xFF1E2838);

  @override
  void initState() {
    super.initState();
    _weightController = TextEditingController(
      text: widget.currentWeight != null ? widget.currentWeight!.toStringAsFixed(1) : '',
    );
  }

  @override
  void dispose() {
    _weightController.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    final text = _weightController.text.trim().replaceAll(',', '.');
    final weight = double.tryParse(text);

    if (weight == null || weight <= 0 || weight > 350) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Por favor, ingresa un peso válido en kg (ej: 75.5)'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      await BiometricsService.quickLogWeight(widget.userId, weight);
      if (!mounted) return;
      Navigator.pop(context);
      widget.onSaved();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('¡Peso registrado: ${weight.toStringAsFixed(1)} kg!'),
          backgroundColor: primaryColor,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al guardar peso: $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: backgroundColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: primaryColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(Icons.scale_rounded, color: primaryColor, size: 22),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    "REGISTRAR PESO",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.1,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              "Ingresa tu peso corporal actual para calcular automáticamente tu progreso.",
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.6),
                fontSize: 12,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _weightController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              autofocus: true,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
              decoration: InputDecoration(
                labelText: "PESO EN KG",
                labelStyle: TextStyle(color: primaryColor, fontSize: 13, fontWeight: FontWeight.bold),
                hintText: "ej. 75.2",
                hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3)),
                suffixText: "kg",
                suffixStyle: TextStyle(color: primaryColor, fontSize: 18, fontWeight: FontWeight.bold),
                filled: true,
                fillColor: surfaceColor.withValues(alpha: 0.5),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: primaryColor, width: 1.5),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
              ),
            ),
            if (widget.currentWeight != null) ...[
              const SizedBox(height: 10),
              Text(
                "Último registro: ${widget.currentWeight!.toStringAsFixed(1)} kg",
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.4),
                  fontSize: 11,
                ),
              ),
            ],
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: _isLoading ? null : () => Navigator.pop(context),
                    child: Text(
                      "CANCELAR",
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _handleSave,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      foregroundColor: const Color(0xFF11151C),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF11151C)),
                          )
                        : const Text(
                            "GUARDAR",
                            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13),
                          ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
