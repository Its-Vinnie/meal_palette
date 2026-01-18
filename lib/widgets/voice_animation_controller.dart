// lib/widgets/voice_animation_controller.dart

import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'package:meal_palette/theme/theme_design.dart';

/// Controller for managing voice animation with real audio level synchronization
class VoiceAnimationController extends ChangeNotifier {
  double _amplitude = 0.0;
  bool _isAnimating = false;
  bool _isAISpeaking = false;
  bool _isUserSpeaking = false;

  double get amplitude => _amplitude;
  bool get isAnimating => _isAnimating;
  bool get isAISpeaking => _isAISpeaking;
  bool get isUserSpeaking => _isUserSpeaking;

  /// Update amplitude from audio level (0.0 to 1.0)
  void updateAmplitude(double level) {
    _amplitude = level.clamp(0.0, 1.0);
    notifyListeners();
  }

  /// Start AI speaking animation
  void startAISpeaking() {
    _isAnimating = true;
    _isAISpeaking = true;
    _isUserSpeaking = false;
    notifyListeners();
  }

  /// Start user speaking animation
  void startUserSpeaking() {
    _isAnimating = true;
    _isUserSpeaking = true;
    _isAISpeaking = false;
    notifyListeners();
  }

  /// Stop all animations
  void stopAnimation() {
    _isAnimating = false;
    _isAISpeaking = false;
    _isUserSpeaking = false;
    _amplitude = 0.0;
    notifyListeners();
  }

  /// Set idle state (subtle animation)
  void setIdle() {
    _isAnimating = false;
    _isAISpeaking = false;
    _isUserSpeaking = false;
    notifyListeners();
  }
}

/// Beautiful AI Voice Orb Widget - matches the design inspiration screenshots
/// A glowing 3D-like sphere that pulses with voice activity
class VoiceOrbWidget extends StatefulWidget {
  final VoiceAnimationController? controller;
  final double size;
  final bool isAISpeaking;
  final bool isUserSpeaking;
  final bool isListening;
  final bool isProcessing;
  final double audioLevel;
  final Color? primaryColor;
  final Color? secondaryColor;

  const VoiceOrbWidget({
    super.key,
    this.controller,
    this.size = 160,
    this.isAISpeaking = false,
    this.isUserSpeaking = false,
    this.isListening = false,
    this.isProcessing = false,
    this.audioLevel = 0.0,
    this.primaryColor,
    this.secondaryColor,
  });

  @override
  State<VoiceOrbWidget> createState() => _VoiceOrbWidgetState();
}

class _VoiceOrbWidgetState extends State<VoiceOrbWidget>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _glowController;
  late AnimationController _rotationController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _glowAnimation;

  @override
  void initState() {
    super.initState();

    // Smooth pulse animation
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Glow intensity animation
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _glowAnimation = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOut),
    );

    // Rotation for ambient effect
    _rotationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    )..repeat();

    // Listen to controller if provided
    widget.controller?.addListener(_onControllerUpdate);
  }

  void _onControllerUpdate() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    widget.controller?.removeListener(_onControllerUpdate);
    _pulseController.dispose();
    _glowController.dispose();
    _rotationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isActive = widget.isAISpeaking ||
        widget.isUserSpeaking ||
        widget.isListening ||
        widget.isProcessing ||
        (widget.controller?.isAnimating ?? false);

    final effectiveAudioLevel = widget.controller?.amplitude ?? widget.audioLevel;
    final primaryColor = widget.primaryColor ?? AppColors.primaryAccent;
    final secondaryColor = widget.secondaryColor ?? AppColors.secondaryAccent;

    return AnimatedBuilder(
      animation: Listenable.merge([
        _pulseAnimation,
        _glowAnimation,
        _rotationController,
      ]),
      builder: (context, child) {
        final pulseScale = _pulseAnimation.value;
        final glowIntensity = _glowAnimation.value;
        final rotation = _rotationController.value * 2 * math.pi;

        // Calculate dynamic scale based on audio level
        final audioScale = isActive ? 1.0 + (effectiveAudioLevel * 0.15) : 1.0;
        final totalScale = pulseScale * audioScale;

        return SizedBox(
          width: widget.size * 1.5,
          height: widget.size * 1.5,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Outer glow rings
              if (isActive) ...[
                _buildGlowRing(
                  size: widget.size * totalScale * 1.4,
                  opacity: 0.1 * glowIntensity * (1 + effectiveAudioLevel),
                  color: primaryColor,
                ),
                _buildGlowRing(
                  size: widget.size * totalScale * 1.25,
                  opacity: 0.15 * glowIntensity * (1 + effectiveAudioLevel),
                  color: primaryColor,
                ),
                _buildGlowRing(
                  size: widget.size * totalScale * 1.1,
                  opacity: 0.2 * glowIntensity * (1 + effectiveAudioLevel),
                  color: primaryColor,
                ),
              ],

              // Main orb with gradient
              CustomPaint(
                size: Size(widget.size * totalScale, widget.size * totalScale),
                painter: _OrbPainter(
                  primaryColor: primaryColor,
                  secondaryColor: secondaryColor,
                  glowIntensity: glowIntensity,
                  audioLevel: effectiveAudioLevel,
                  rotation: rotation,
                  isActive: isActive,
                  isAISpeaking: widget.isAISpeaking ||
                      (widget.controller?.isAISpeaking ?? false),
                  isUserSpeaking: widget.isUserSpeaking ||
                      (widget.controller?.isUserSpeaking ?? false),
                  isProcessing: widget.isProcessing,
                ),
              ),

              // Inner highlight
              Positioned(
                top: widget.size * totalScale * 0.15,
                left: widget.size * totalScale * 0.25,
                child: Container(
                  width: widget.size * totalScale * 0.25,
                  height: widget.size * totalScale * 0.15,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(100),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Colors.white.withValues(alpha: 0.4 * glowIntensity),
                        Colors.white.withValues(alpha: 0.0),
                      ],
                    ),
                  ),
                ),
              ),

              // Sound wave bars when speaking
              if (widget.isAISpeaking ||
                  (widget.controller?.isAISpeaking ?? false))
                _buildSoundWaveBars(effectiveAudioLevel, primaryColor),
            ],
          ),
        );
      },
    );
  }

  Widget _buildGlowRing({
    required double size,
    required double opacity,
    required Color color,
  }) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: color.withValues(alpha: opacity.clamp(0.0, 1.0)),
          width: 2,
        ),
      ),
    );
  }

  Widget _buildSoundWaveBars(double audioLevel, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(5, (index) {
        final phase = (index / 5) * math.pi;
        final height = 8 +
            (audioLevel * 20) *
                math.sin(_glowController.value * math.pi * 2 + phase).abs();
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 2),
          width: 4,
          height: height,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.9),
            borderRadius: BorderRadius.circular(2),
          ),
        );
      }),
    );
  }
}

/// Custom painter for the 3D-like orb effect
class _OrbPainter extends CustomPainter {
  final Color primaryColor;
  final Color secondaryColor;
  final double glowIntensity;
  final double audioLevel;
  final double rotation;
  final bool isActive;
  final bool isAISpeaking;
  final bool isUserSpeaking;
  final bool isProcessing;

  _OrbPainter({
    required this.primaryColor,
    required this.secondaryColor,
    required this.glowIntensity,
    required this.audioLevel,
    required this.rotation,
    required this.isActive,
    required this.isAISpeaking,
    required this.isUserSpeaking,
    required this.isProcessing,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // Create the main gradient for 3D effect
    final mainGradient = RadialGradient(
      center: const Alignment(-0.3, -0.3),
      radius: 1.2,
      colors: [
        _lightenColor(primaryColor, 0.4),
        primaryColor,
        _darkenColor(primaryColor, 0.3),
        _darkenColor(primaryColor, 0.5),
      ],
      stops: const [0.0, 0.3, 0.7, 1.0],
    );

    // Draw outer glow when active
    if (isActive) {
      final glowPaint = Paint()
        ..maskFilter = MaskFilter.blur(
          BlurStyle.normal,
          20 + (audioLevel * 15),
        )
        ..color = primaryColor.withValues(
          alpha: (0.3 + audioLevel * 0.3) * glowIntensity,
        );
      canvas.drawCircle(center, radius * 1.05, glowPaint);
    }

    // Draw main orb
    final mainPaint = Paint()
      ..shader = mainGradient.createShader(
        Rect.fromCircle(center: center, radius: radius),
      );
    canvas.drawCircle(center, radius * 0.95, mainPaint);

    // Draw inner glow/reflection
    final innerGlowGradient = RadialGradient(
      center: const Alignment(-0.4, -0.4),
      radius: 0.8,
      colors: [
        Colors.white.withValues(alpha: 0.3 * glowIntensity),
        Colors.white.withValues(alpha: 0.1 * glowIntensity),
        Colors.transparent,
      ],
      stops: const [0.0, 0.3, 1.0],
    );

    final innerGlowPaint = Paint()
      ..shader = innerGlowGradient.createShader(
        Rect.fromCircle(center: center, radius: radius),
      );
    canvas.drawCircle(center, radius * 0.9, innerGlowPaint);

    // Draw subtle rim light
    final rimPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..shader = SweepGradient(
        center: Alignment.center,
        startAngle: rotation,
        endAngle: rotation + math.pi * 2,
        colors: [
          Colors.white.withValues(alpha: 0.0),
          Colors.white.withValues(alpha: 0.2 * glowIntensity),
          Colors.white.withValues(alpha: 0.4 * glowIntensity),
          Colors.white.withValues(alpha: 0.2 * glowIntensity),
          Colors.white.withValues(alpha: 0.0),
        ],
        stops: const [0.0, 0.25, 0.5, 0.75, 1.0],
      ).createShader(
        Rect.fromCircle(center: center, radius: radius * 0.95),
      );
    canvas.drawCircle(center, radius * 0.95, rimPaint);

    // Draw processing indicator if needed
    if (isProcessing) {
      _drawProcessingIndicator(canvas, center, radius);
    }
  }

  void _drawProcessingIndicator(Canvas canvas, Offset center, double radius) {
    final processingPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..color = Colors.white.withValues(alpha: 0.8);

    final rect = Rect.fromCircle(center: center, radius: radius * 0.4);
    canvas.drawArc(rect, rotation * 3, math.pi * 1.5, false, processingPaint);
  }

  Color _lightenColor(Color color, double amount) {
    final hsl = HSLColor.fromColor(color);
    return hsl
        .withLightness((hsl.lightness + amount).clamp(0.0, 1.0))
        .toColor();
  }

  Color _darkenColor(Color color, double amount) {
    final hsl = HSLColor.fromColor(color);
    return hsl
        .withLightness((hsl.lightness - amount).clamp(0.0, 1.0))
        .toColor();
  }

  @override
  bool shouldRepaint(_OrbPainter oldDelegate) {
    return oldDelegate.glowIntensity != glowIntensity ||
        oldDelegate.audioLevel != audioLevel ||
        oldDelegate.rotation != rotation ||
        oldDelegate.isActive != isActive ||
        oldDelegate.isAISpeaking != isAISpeaking ||
        oldDelegate.isUserSpeaking != isUserSpeaking ||
        oldDelegate.isProcessing != isProcessing;
  }
}

/// Compact voice orb for inline use
class CompactVoiceOrb extends StatefulWidget {
  final bool isActive;
  final bool isSpeaking;
  final double audioLevel;
  final double size;
  final Color? color;

  const CompactVoiceOrb({
    super.key,
    this.isActive = false,
    this.isSpeaking = false,
    this.audioLevel = 0.0,
    this.size = 48,
    this.color,
  });

  @override
  State<CompactVoiceOrb> createState() => _CompactVoiceOrbState();
}

class _CompactVoiceOrbState extends State<CompactVoiceOrb>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.color ?? AppColors.primaryAccent;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final scale = widget.isActive
            ? 1.0 + (_controller.value * 0.1) + (widget.audioLevel * 0.15)
            : 1.0;

        return Container(
          width: widget.size * scale,
          height: widget.size * scale,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              center: const Alignment(-0.3, -0.3),
              colors: [
                color.withValues(alpha: 0.8),
                color,
                color.withValues(alpha: 0.6),
              ],
            ),
            boxShadow: widget.isActive
                ? [
                    BoxShadow(
                      color: color.withValues(
                        alpha: 0.3 + (widget.audioLevel * 0.3),
                      ),
                      blurRadius: 15 + (widget.audioLevel * 10),
                      spreadRadius: 2,
                    ),
                  ]
                : null,
          ),
          child: widget.isSpeaking
              ? Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: List.generate(3, (i) {
                      final height = 6 +
                          (widget.audioLevel * 10) *
                              math.sin(_controller.value * math.pi * 2 + i)
                                  .abs();
                      return Container(
                        margin: const EdgeInsets.symmetric(horizontal: 1),
                        width: 3,
                        height: height,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(1.5),
                        ),
                      );
                    }),
                  ),
                )
              : null,
        );
      },
    );
  }
}
