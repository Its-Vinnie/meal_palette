import 'dart:async';
import 'package:flutter/material.dart';
import 'package:meal_palette/model/cook_along_session.dart';
import 'package:meal_palette/state/cook_along_state.dart';
import 'package:meal_palette/theme/theme_design.dart';

/// Widget to display an active cooking timer
class CookAlongTimerWidget extends StatefulWidget {
  final StepTimer timer;

  const CookAlongTimerWidget({
    super.key,
    required this.timer,
  });

  @override
  State<CookAlongTimerWidget> createState() => _CookAlongTimerWidgetState();
}

class _CookAlongTimerWidgetState extends State<CookAlongTimerWidget> {
  Timer? _updateTimer;

  @override
  void initState() {
    super.initState();
    // Update UI every second
    _updateTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _updateTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final remaining = widget.timer.remaining;
    final progress = widget.timer.progress;
    final isPaused = widget.timer.status == TimerStatus.paused;
    final isFinished = widget.timer.isFinished;

    final hours = remaining.inHours;
    final minutes = remaining.inMinutes % 60;
    final seconds = remaining.inSeconds % 60;

    String timeDisplay;
    if (hours > 0) {
      timeDisplay = '${hours}h ${minutes}m ${seconds}s';
    } else if (minutes > 0) {
      timeDisplay = '${minutes}m ${seconds}s';
    } else {
      timeDisplay = '${seconds}s';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isFinished
              ? AppColors.success
              : isPaused
                  ? AppColors.warning.withValues(alpha: 0.5)
                  : AppColors.warning.withValues(alpha: 0.3),
          width: 2,
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              // Timer icon
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: isFinished
                      ? AppColors.success.withValues(alpha: 0.2)
                      : isPaused
                          ? AppColors.warning.withValues(alpha: 0.2)
                          : AppColors.warning.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  isFinished
                      ? Icons.check_circle
                      : isPaused
                          ? Icons.pause_circle
                          : Icons.timer,
                  color: isFinished
                      ? AppColors.success
                      : isPaused
                          ? AppColors.warning
                          : AppColors.warning,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),

              // Timer description
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.timer.description,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Step ${widget.timer.stepNumber}',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textTertiary,
                      ),
                    ),
                  ],
                ),
              ),

              // Time display
              Text(
                timeDisplay,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: isFinished
                      ? AppColors.success
                      : isPaused
                          ? AppColors.warning
                          : AppColors.textPrimary,
                ),
              ),

              // Cancel button
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.close, size: 20),
                color: AppColors.textTertiary,
                onPressed: () => cookAlongState.cancelTimer(widget.timer.id),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),

          // Progress bar
          if (!isFinished) ...[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress,
                backgroundColor: AppColors.background,
                valueColor: AlwaysStoppedAnimation(
                  isPaused ? AppColors.warning : AppColors.primaryAccent,
                ),
                minHeight: 6,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
