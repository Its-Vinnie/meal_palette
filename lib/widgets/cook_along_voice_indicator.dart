import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:meal_palette/state/cook_along_state.dart';
import 'package:meal_palette/service/cook_along_service.dart';
import 'package:meal_palette/theme/theme_design.dart';

/// Visual indicator showing voice listening status with ambient wave animation
class CookAlongVoiceIndicator extends StatefulWidget {
  const CookAlongVoiceIndicator({super.key});

  @override
  State<CookAlongVoiceIndicator> createState() =>
      _CookAlongVoiceIndicatorState();
}

class _CookAlongVoiceIndicatorState extends State<CookAlongVoiceIndicator>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _waveController;
  late AnimationController _speakingController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();

    // Pulse animation for the central orb
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(
        parent: _pulseController,
        curve: Curves.easeInOut,
      ),
    );

    // Wave animation for the ambient waves
    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    )..repeat();

    // Speaking animation (faster pulse)
    _speakingController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _waveController.dispose();
    _speakingController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: cookAlongState,
      builder: (context, _) {
        final isListening = cookAlongState.isListening;
        final isSpeaking = cookAlongService.isSpeaking;
        final isProcessing = cookAlongState.isProcessingQuestion;

        // Always show the indicator (for ambient effect), but change state
        return Column(
          children: [
            // Status text
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: Text(
                _getStatusText(isListening, isSpeaking, isProcessing),
                key: ValueKey('${isListening}_${isSpeaking}_$isProcessing'),
                style: AppTextStyles.labelLarge.copyWith(
                  color: _getStatusColor(isListening, isSpeaking, isProcessing),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Voice wave visualization
            SizedBox(
              height: 120,
              width: double.infinity,
              child: AnimatedBuilder(
                animation: Listenable.merge([
                  _waveController,
                  _pulseAnimation,
                  _speakingController,
                ]),
                builder: (context, child) {
                  return CustomPaint(
                    painter: _VoiceWavePainter(
                      waveProgress: _waveController.value,
                      pulseScale: _pulseAnimation.value,
                      speakingProgress: _speakingController.value,
                      isListening: isListening,
                      isSpeaking: isSpeaking,
                      isProcessing: isProcessing,
                      primaryColor: AppColors.primaryAccent,
                      secondaryColor: AppColors.warning,
                    ),
                  );
                },
              ),
            ),

            // Voice command hints
            if (isListening && !isSpeaking && !isProcessing)
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  alignment: WrapAlignment.center,
                  children: [
                    _buildCommandHint('Next'),
                    _buildCommandHint('Repeat'),
                    _buildCommandHint('Back'),
                    _buildCommandHint('Pause'),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }

  String _getStatusText(bool isListening, bool isSpeaking, bool isProcessing) {
    if (isProcessing) return 'Thinking...';
    if (isSpeaking) return 'Speaking...';
    if (isListening) return 'Listening...';
    return 'Say a command or tap the mic';
  }

  Color _getStatusColor(bool isListening, bool isSpeaking, bool isProcessing) {
    if (isProcessing) return AppColors.warning;
    if (isSpeaking) return AppColors.success;
    if (isListening) return AppColors.info;
    return AppColors.textSecondary;
  }

  Widget _buildCommandHint(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.textTertiary.withValues(alpha: 0.3),
        ),
      ),
      child: Text(
        '"$text"',
        style: AppTextStyles.labelMedium.copyWith(
          color: AppColors.textSecondary,
          fontStyle: FontStyle.italic,
        ),
      ),
    );
  }
}

/// Custom painter for the voice wave visualization
class _VoiceWavePainter extends CustomPainter {
  final double waveProgress;
  final double pulseScale;
  final double speakingProgress;
  final bool isListening;
  final bool isSpeaking;
  final bool isProcessing;
  final Color primaryColor;
  final Color secondaryColor;

  _VoiceWavePainter({
    required this.waveProgress,
    required this.pulseScale,
    required this.speakingProgress,
    required this.isListening,
    required this.isSpeaking,
    required this.isProcessing,
    required this.primaryColor,
    required this.secondaryColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final centerX = size.width / 2;
    final centerY = size.height / 2;

    // Draw ambient waves at the bottom
    _drawAmbientWaves(canvas, size);

    // Draw the central visualization
    if (isListening || isSpeaking || isProcessing) {
      _drawActiveVisualization(canvas, centerX, centerY);
    } else {
      _drawIdleVisualization(canvas, centerX, centerY);
    }
  }

  void _drawAmbientWaves(Canvas canvas, Size size) {
    final path = Path();
    path.moveTo(0, size.height);

    // Create multiple wave layers
    for (int wave = 0; wave < 3; wave++) {
      final waveOffset = wave * 0.2;
      final waveAmplitude = (15 + wave * 8) * (isListening ? 1.5 : 1.0);
      final waveSpeed = 1.0 + wave * 0.3;

      path.reset();
      path.moveTo(0, size.height);

      for (double x = 0; x <= size.width; x += 2) {
        final normalizedX = x / size.width;
        final y = size.height -
            20 -
            wave * 15 -
            math.sin((normalizedX * 4 * math.pi) +
                    (waveProgress * 2 * math.pi * waveSpeed) +
                    waveOffset) *
                waveAmplitude *
                (isSpeaking ? (1 + speakingProgress * 0.5) : 1);
        path.lineTo(x, y);
      }

      path.lineTo(size.width, size.height);
      path.close();

      final layerPaint = Paint()
        ..style = PaintingStyle.fill
        ..color = primaryColor.withValues(
            alpha: (0.1 + wave * 0.05) * (isListening ? 2 : 1));

      canvas.drawPath(path, layerPaint);
    }
  }

  void _drawActiveVisualization(Canvas canvas, double cx, double cy) {
    // Draw pulsing circles
    for (int i = 3; i >= 0; i--) {
      final radius = (20 + i * 12) * pulseScale;
      final alpha = (0.3 - i * 0.07) * (isSpeaking ? 1.5 : 1.0);

      final paint = Paint()
        ..style = PaintingStyle.fill
        ..color = (isProcessing ? secondaryColor : primaryColor)
            .withValues(alpha: alpha.clamp(0.0, 1.0));

      canvas.drawCircle(Offset(cx, cy - 10), radius, paint);
    }

    // Draw sound wave bars if speaking
    if (isSpeaking) {
      _drawSoundBars(canvas, cx, cy - 10);
    }

    // Draw listening indicator dots if listening
    if (isListening && !isSpeaking) {
      _drawListeningDots(canvas, cx, cy - 10);
    }

    // Draw processing spinner if processing
    if (isProcessing) {
      _drawProcessingSpinner(canvas, cx, cy - 10);
    }
  }

  void _drawIdleVisualization(Canvas canvas, double cx, double cy) {
    // Subtle idle animation
    final radius = 25 * pulseScale;

    final paint = Paint()
      ..style = PaintingStyle.fill
      ..color = primaryColor.withValues(alpha: 0.2);

    canvas.drawCircle(Offset(cx, cy - 10), radius, paint);

    // Inner circle
    final innerPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = primaryColor.withValues(alpha: 0.4);

    canvas.drawCircle(Offset(cx, cy - 10), radius * 0.6, innerPaint);
  }

  void _drawSoundBars(Canvas canvas, double cx, double cy) {
    final barPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = Colors.white;

    const barCount = 5;
    const barWidth = 4.0;
    const barSpacing = 6.0;
    const maxBarHeight = 30.0;

    final totalWidth = barCount * barWidth + (barCount - 1) * barSpacing;
    final startX = cx - totalWidth / 2;

    for (int i = 0; i < barCount; i++) {
      // Create varied heights based on speaking progress
      final phase = (i / barCount) * 2 * math.pi;
      final heightFactor = 0.3 +
          0.7 * math.sin(speakingProgress * 2 * math.pi + phase).abs();
      final barHeight = maxBarHeight * heightFactor;

      final rect = RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(startX + i * (barWidth + barSpacing) + barWidth / 2, cy),
          width: barWidth,
          height: barHeight,
        ),
        const Radius.circular(2),
      );

      canvas.drawRRect(rect, barPaint);
    }
  }

  void _drawListeningDots(Canvas canvas, double cx, double cy) {
    final dotPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = Colors.white;

    const dotCount = 3;
    const dotRadius = 4.0;
    const dotSpacing = 12.0;

    final totalWidth = dotCount * dotRadius * 2 + (dotCount - 1) * dotSpacing;
    final startX = cx - totalWidth / 2 + dotRadius;

    for (int i = 0; i < dotCount; i++) {
      final phase = (i / dotCount) * 2 * math.pi;
      final scale = 0.5 + 0.5 * math.sin(waveProgress * 2 * math.pi + phase);

      canvas.drawCircle(
        Offset(startX + i * (dotRadius * 2 + dotSpacing), cy),
        dotRadius * scale,
        dotPaint,
      );
    }
  }

  void _drawProcessingSpinner(Canvas canvas, double cx, double cy) {
    final spinnerPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..color = Colors.white;

    const radius = 15.0;
    final rect = Rect.fromCircle(center: Offset(cx, cy), radius: radius);

    // Draw spinning arc
    canvas.drawArc(
      rect,
      waveProgress * 2 * math.pi,
      math.pi * 1.5,
      false,
      spinnerPaint,
    );
  }

  @override
  bool shouldRepaint(_VoiceWavePainter oldDelegate) {
    return oldDelegate.waveProgress != waveProgress ||
        oldDelegate.pulseScale != pulseScale ||
        oldDelegate.speakingProgress != speakingProgress ||
        oldDelegate.isListening != isListening ||
        oldDelegate.isSpeaking != isSpeaking ||
        oldDelegate.isProcessing != isProcessing;
  }
}
