import 'package:flutter/material.dart';
import 'package:meal_palette/theme/theme_design.dart';

/// Animated error message that slides in from top
/// Features:
/// - Smooth slide animation
/// - Auto-dismiss after duration
/// - Tap to dismiss
/// - Beautiful design matching app theme
class AnimatedErrorMessage extends StatefulWidget {
  final String message;
  final VoidCallback? onDismiss;
  final Duration duration;
  final IconData icon;

  const AnimatedErrorMessage({
    super.key,
    required this.message,
    this.onDismiss,
    this.duration = const Duration(seconds: 4),
    this.icon = Icons.error_outline,
  });

  @override
  State<AnimatedErrorMessage> createState() => _AnimatedErrorMessageState();
}

class _AnimatedErrorMessageState extends State<AnimatedErrorMessage>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();

    //* Setup animation controller
    _controller = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );

    //* Slide animation from top
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, -1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.elasticOut,
    ));

    //* Fade animation
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeIn,
    ));

    //* Start animation
    _controller.forward();

    //* Auto dismiss after duration
    Future.delayed(widget.duration, () {
      if (mounted) {
        _dismiss();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _dismiss() async {
    await _controller.reverse();
    if (mounted) {
      widget.onDismiss?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    return SlideTransition(
      position: _slideAnimation,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: GestureDetector(
          onTap: _dismiss,
          child: Container(
            margin: EdgeInsets.all(AppSpacing.lg),
            padding: EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              color: AppColors.favorite,
              borderRadius: BorderRadius.circular(AppRadius.lg),
              boxShadow: [
                BoxShadow(
                  color: AppColors.favorite.withValues(alpha:0.3),
                  blurRadius: 20,
                  offset: Offset(0, 8),
                ),
              ],
            ),
            child: Row(
              children: [
                //* Error icon
                Container(
                  padding: EdgeInsets.all(AppSpacing.sm),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha:0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    widget.icon,
                    color: Colors.white,
                    size: 24,
                  ),
                ),

                SizedBox(width: AppSpacing.lg),

                //* Error message
                Expanded(
                  child: Text(
                    widget.message,
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),

                //* Close button
                IconButton(
                  icon: Icon(Icons.close, color: Colors.white),
                  onPressed: _dismiss,
                  padding: EdgeInsets.zero,
                  constraints: BoxConstraints(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Success message variant
class AnimatedSuccessMessage extends StatefulWidget {
  final String message;
  final VoidCallback? onDismiss;
  final Duration duration;

  const AnimatedSuccessMessage({
    super.key,
    required this.message,
    this.onDismiss,
    this.duration = const Duration(seconds: 3),
  });

  @override
  State<AnimatedSuccessMessage> createState() => _AnimatedSuccessMessageState();
}

class _AnimatedSuccessMessageState extends State<AnimatedSuccessMessage>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, -1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.elasticOut,
    ));

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeIn,
    ));

    _controller.forward();

    Future.delayed(widget.duration, () {
      if (mounted) {
        _dismiss();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _dismiss() async {
    await _controller.reverse();
    if (mounted) {
      widget.onDismiss?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    return SlideTransition(
      position: _slideAnimation,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: GestureDetector(
          onTap: _dismiss,
          child: Container(
            margin: EdgeInsets.all(AppSpacing.lg),
            padding: EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              color: AppColors.success,
              borderRadius: BorderRadius.circular(AppRadius.lg),
              boxShadow: [
                BoxShadow(
                  color: AppColors.success.withValues(alpha:0.3),
                  blurRadius: 20,
                  offset: Offset(0, 8),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(AppSpacing.sm),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha:0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.check_circle_outline,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                SizedBox(width: AppSpacing.lg),
                Expanded(
                  child: Text(
                    widget.message,
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.close, color: Colors.white),
                  onPressed: _dismiss,
                  padding: EdgeInsets.zero,
                  constraints: BoxConstraints(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Overlay entry helper to show error messages
class ErrorMessageOverlay {
  static OverlayEntry? _currentEntry;

  /// Show error message as overlay
  static void showError(BuildContext context, String message) {
    //* Remove existing error if any
    _currentEntry?.remove();

    //* Create new overlay entry
    _currentEntry = OverlayEntry(
      builder: (context) => Positioned(
        top: MediaQuery.of(context).padding.top,
        left: 0,
        right: 0,
        child: AnimatedErrorMessage(
          message: message,
          onDismiss: () {
            _currentEntry?.remove();
            _currentEntry = null;
          },
        ),
      ),
    );

    //* Insert overlay
    Overlay.of(context).insert(_currentEntry!);
  }

  /// Show success message as overlay
  static void showSuccess(BuildContext context, String message) {
    //* Remove existing message if any
    _currentEntry?.remove();

    //* Create new overlay entry
    _currentEntry = OverlayEntry(
      builder: (context) => Positioned(
        top: MediaQuery.of(context).padding.top,
        left: 0,
        right: 0,
        child: AnimatedSuccessMessage(
          message: message,
          onDismiss: () {
            _currentEntry?.remove();
            _currentEntry = null;
          },
        ),
      ),
    );

    //* Insert overlay
    Overlay.of(context).insert(_currentEntry!);
  }

  /// Remove current overlay
  static void dismiss() {
    _currentEntry?.remove();
    _currentEntry = null;
  }
}