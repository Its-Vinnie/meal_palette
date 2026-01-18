import 'package:flutter/material.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:meal_palette/model/detailed_recipe_model.dart';
import 'package:meal_palette/model/cook_along_session.dart';
import 'package:meal_palette/state/cook_along_state.dart';
import 'package:meal_palette/service/cook_along_service.dart';
import 'package:meal_palette/theme/theme_design.dart';
import 'package:meal_palette/widgets/cook_along_timer_widget.dart';
import 'package:meal_palette/widgets/voice_animation_controller.dart';

/// Main Cook Along Mode screen with immersive voice-guided cooking interface
/// Supports both voice mode (AI-guided) and manual mode (button navigation)
class CookAlongScreen extends StatefulWidget {
  final RecipeDetail recipe;
  final CookAlongMode initialMode;

  const CookAlongScreen({
    super.key,
    required this.recipe,
    this.initialMode = CookAlongMode.voice,
  });

  @override
  State<CookAlongScreen> createState() => _CookAlongScreenState();
}

class _CookAlongScreenState extends State<CookAlongScreen>
    with WidgetsBindingObserver {
  final _questionController = TextEditingController();
  bool _showConversation = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeCookAlong();
  }

  Future<void> _initializeCookAlong() async {
    // Keep screen awake during cooking
    await WakelockPlus.enable();

    // Set up exit callback
    cookAlongState.onExitRequested = () {
      if (mounted) {
        Navigator.pop(context);
      }
    };

    // Request permissions first (only for voice mode)
    if (widget.initialMode == CookAlongMode.voice) {
      final hasPermissions = await cookAlongService.checkPermissions();
      if (!hasPermissions && mounted) {
        final granted = await cookAlongService.requestPermissions();
        if (!granted && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Microphone and speech recognition permissions are required for voice commands. '
                'Please enable them in Settings.',
              ),
              duration: Duration(seconds: 5),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
    }

    // Start Cook Along session with initial mode
    await cookAlongState.startSession(widget.recipe, initialMode: widget.initialMode);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    WakelockPlus.disable();
    _questionController.dispose();
    cookAlongState.onExitRequested = null;
    cookAlongState.endSession();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: ListenableBuilder(
          listenable: cookAlongState,
          builder: (context, _) {
            final session = cookAlongState.session;
            if (session == null) {
              return const Center(
                child: CircularProgressIndicator(
                  color: AppColors.primaryAccent,
                ),
              );
            }

            return Stack(
              children: [
                // Main content
                Column(
                  children: [
                    // Header with close, mode toggle, and progress
                    _buildHeader(session),

                    // Main step display
                    Expanded(
                      child: cookAlongState.isVoiceMode
                          ? _buildVoiceModeContent(session)
                          : _buildManualModeContent(session),
                    ),
                  ],
                ),

                // Conversation overlay
                if (_showConversation) _buildConversationOverlay(),

                // Completion overlay
                if (session.isCompleted) _buildCompletionOverlay(),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildHeader(CookAlongSession session) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.close, color: AppColors.textPrimary),
                onPressed: () => _showExitConfirmation(),
              ),
              Expanded(
                child: Column(
                  children: [
                    Text(
                      'Step ${session.currentStepIndex + 1} of ${session.totalSteps}',
                      style: AppTextStyles.labelMedium.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      session.recipe.title,
                      style: AppTextStyles.labelLarge.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              // Mode toggle
              _buildModeToggle(),
            ],
          ),
          const SizedBox(height: 12),
          LinearProgressIndicator(
            value: session.progress,
            backgroundColor: AppColors.background,
            valueColor: const AlwaysStoppedAnimation(AppColors.primaryAccent),
            minHeight: 6,
            borderRadius: BorderRadius.circular(3),
          ),
        ],
      ),
    );
  }

  Widget _buildModeToggle() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(24),
      ),
      padding: const EdgeInsets.all(4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildModeButton(
            icon: Icons.touch_app,
            isActive: cookAlongState.isManualMode,
            onTap: () => cookAlongState.switchMode(CookAlongMode.manual),
            tooltip: 'Manual',
          ),
          _buildModeButton(
            icon: Icons.mic,
            isActive: cookAlongState.isVoiceMode,
            onTap: () => cookAlongState.switchMode(CookAlongMode.voice),
            tooltip: 'Voice',
          ),
        ],
      ),
    );
  }

  Widget _buildModeButton({
    required IconData icon,
    required bool isActive,
    required VoidCallback onTap,
    required String tooltip,
  }) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: isActive ? AppColors.primaryAccent : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Icon(
            icon,
            color: isActive ? Colors.white : AppColors.textSecondary,
            size: 20,
          ),
        ),
      ),
    );
  }

  // Voice Mode Content - Immersive AI-guided experience
  Widget _buildVoiceModeContent(CookAlongSession session) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          const SizedBox(height: 32),

          // Voice Orb Animation - syncs with audio
          Center(
            child: VoiceOrbWidget(
              size: 140,
              isAISpeaking: cookAlongState.isSpeaking,
              isListening: cookAlongState.isListening,
              isProcessing: cookAlongState.isProcessingQuestion,
              audioLevel: cookAlongState.audioLevel,
            ),
          ),

          const SizedBox(height: 16),

          // Status text
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: Text(
              _getStatusText(),
              key: ValueKey(_getStatusText()),
              style: AppTextStyles.labelLarge.copyWith(
                color: _getStatusColor(),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),

          const SizedBox(height: 32),

          // Current step card
          _buildCurrentStep(session),

          const SizedBox(height: 24),

          // Active timers
          if (cookAlongState.activeTimers.isNotEmpty) ...[
            _buildTimersSection(),
            const SizedBox(height: 24),
          ],

          // Navigation buttons
          _buildNavigationButtons(session),

          const SizedBox(height: 24),

          // Voice command hints
          if (cookAlongState.isListening) _buildVoiceCommandHints(),

          const SizedBox(height: 24),

          // Quick actions
          _buildQuickActions(),

          const SizedBox(height: 100),
        ],
      ),
    );
  }

  // Manual Mode Content - Traditional button-based navigation
  Widget _buildManualModeContent(CookAlongSession session) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          const SizedBox(height: 24),

          // Current step card
          _buildCurrentStep(session),

          const SizedBox(height: 32),

          // Active timers
          if (cookAlongState.activeTimers.isNotEmpty) ...[
            _buildTimersSection(),
            const SizedBox(height: 32),
          ],

          // Navigation buttons
          _buildNavigationButtons(session),

          const SizedBox(height: 24),

          // Quick actions (manual mode version)
          _buildManualQuickActions(),

          const SizedBox(height: 100),
        ],
      ),
    );
  }

  String _getStatusText() {
    if (cookAlongState.isProcessingQuestion) return 'Thinking...';
    if (cookAlongState.isSpeaking) return 'Speaking...';
    if (cookAlongState.isListening) return 'Listening... (hands-free)';
    return 'Tap mic to start hands-free mode';
  }

  Color _getStatusColor() {
    if (cookAlongState.isProcessingQuestion) return AppColors.warning;
    if (cookAlongState.isSpeaking) return AppColors.success;
    if (cookAlongState.isListening) return AppColors.info;
    return AppColors.textSecondary;
  }

  Widget _buildVoiceCommandHints() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      alignment: WrapAlignment.center,
      children: [
        _buildCommandHint('Next'),
        _buildCommandHint('Repeat'),
        _buildCommandHint('Back'),
        _buildCommandHint('Pause'),
      ],
    );
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

  Widget _buildCurrentStep(CookAlongSession session) {
    final step = session.currentStep;
    if (step == null) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.primaryAccent.withValues(alpha: 0.3),
          width: 2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.primaryAccent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(
                    '${step.number}',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Current Step',
                  style: AppTextStyles.labelLarge.copyWith(
                    color: AppColors.primaryAccent,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (cookAlongState.isSpeaking)
                CompactVoiceOrb(
                  isActive: true,
                  isSpeaking: true,
                  audioLevel: cookAlongState.audioLevel,
                  size: 32,
                ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            step.step,
            style: const TextStyle(
              fontSize: 18,
              height: 1.6,
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimersSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(
              Icons.timer_outlined,
              color: AppColors.warning,
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              'Active Timers',
              style: AppTextStyles.labelLarge.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...cookAlongState.activeTimers
            .where((t) =>
                t.status == TimerStatus.running ||
                t.status == TimerStatus.paused)
            .map((timer) => CookAlongTimerWidget(timer: timer)),
      ],
    );
  }

  Widget _buildNavigationButtons(CookAlongSession session) {
    // Check if cooking hasn't started yet
    final hasStarted = cookAlongState.hasStartedCooking;

    if (!hasStarted) {
      // Show just the "Start" button
      return SizedBox(
        width: double.infinity,
        height: 56,
        child: ElevatedButton.icon(
          onPressed: () => cookAlongState.startFirstStep(),
          icon: const Icon(Icons.play_arrow),
          label: Text(cookAlongState.isVoiceMode ? 'Start Cooking' : 'Start'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primaryAccent,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            elevation: 0,
          ),
        ),
      );
    }

    return Row(
      children: [
        // Previous button
        Expanded(
          child: SizedBox(
            height: 56,
            child: OutlinedButton.icon(
              onPressed: session.hasPreviousStep
                  ? () => cookAlongState.previousStep()
                  : null,
              icon: const Icon(Icons.arrow_back),
              label: const Text('Previous'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.textPrimary,
                disabledForegroundColor: AppColors.textTertiary,
                side: BorderSide(
                  color: session.hasPreviousStep
                      ? AppColors.textSecondary
                      : AppColors.textTertiary,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),

        // Next/Complete button
        Expanded(
          flex: 2,
          child: SizedBox(
            height: 56,
            child: ElevatedButton.icon(
              onPressed: session.hasNextStep
                  ? () => cookAlongState.nextStep()
                  : () => cookAlongState.completeSession(),
              icon: Icon(
                session.hasNextStep ? Icons.arrow_forward : Icons.check_circle,
              ),
              label: Text(session.hasNextStep ? 'Next Step' : 'Complete'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryAccent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 0,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildQuickActions() {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      alignment: WrapAlignment.center,
      children: [
        _buildActionChip(
          'Repeat Step',
          Icons.replay,
          () => cookAlongState.repeatStep(),
        ),
        _buildActionChip(
          'Ask Question',
          Icons.question_answer,
          () => setState(() => _showConversation = true),
        ),
        _buildActionChip(
          cookAlongState.isListening ? 'Stop Hands-free' : 'Start Hands-free',
          cookAlongState.isListening ? Icons.mic_off : Icons.mic,
          () {
            if (cookAlongState.isListening) {
              cookAlongState.stopListening();
            } else {
              cookAlongState.startListening();
            }
          },
        ),
      ],
    );
  }

  Widget _buildManualQuickActions() {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      alignment: WrapAlignment.center,
      children: [
        _buildActionChip(
          'Repeat Step',
          Icons.replay,
          () => cookAlongState.repeatStep(),
        ),
        _buildActionChip(
          'Ask Question',
          Icons.question_answer,
          () => setState(() => _showConversation = true),
        ),
        _buildActionChip(
          cookAlongState.session?.isPaused == true ? 'Resume' : 'Pause',
          cookAlongState.session?.isPaused == true ? Icons.play_arrow : Icons.pause,
          () {
            if (cookAlongState.session?.isPaused == true) {
              cookAlongState.resumeSession();
            } else {
              cookAlongState.pauseSession();
            }
          },
        ),
      ],
    );
  }

  Widget _buildActionChip(String label, IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: AppColors.textTertiary.withValues(alpha: 0.3),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: AppColors.textSecondary),
            const SizedBox(width: 8),
            Text(
              label,
              style: AppTextStyles.labelMedium.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConversationOverlay() {
    return Container(
      color: AppColors.background.withValues(alpha: 0.95),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 10,
                ),
              ],
            ),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.close, color: AppColors.textPrimary),
                  onPressed: () => setState(() => _showConversation = false),
                ),
                const Expanded(
                  child: Text(
                    'Ask AI Chef',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                // Small voice orb indicator
                CompactVoiceOrb(
                  isActive: cookAlongState.isSpeaking || cookAlongState.isListening,
                  isSpeaking: cookAlongState.isSpeaking,
                  audioLevel: cookAlongState.audioLevel,
                  size: 36,
                ),
              ],
            ),
          ),

          // Conversation history
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: cookAlongState.conversationHistory.length,
              itemBuilder: (context, index) {
                final message = cookAlongState.conversationHistory[index];
                return _buildChatBubble(message);
              },
            ),
          ),

          // Input area
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 10,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _questionController,
                    style: const TextStyle(color: AppColors.textPrimary),
                    decoration: InputDecoration(
                      hintText: 'Ask a question...',
                      hintStyle: TextStyle(color: AppColors.textTertiary),
                      filled: true,
                      fillColor: AppColors.background,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                    maxLines: null,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (text) => _sendQuestion(),
                  ),
                ),
                const SizedBox(width: 12),
                IconButton(
                  icon: const Icon(Icons.send, color: AppColors.primaryAccent),
                  onPressed: _sendQuestion,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChatBubble(ChatMessage message) {
    final isUser = message.role == ChatMessageRole.user;

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        decoration: BoxDecoration(
          color: isUser ? AppColors.primaryAccent : AppColors.surface,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          message.content,
          style: TextStyle(
            color: isUser ? Colors.white : AppColors.textPrimary,
            fontSize: 14,
            height: 1.4,
          ),
        ),
      ),
    );
  }

  Widget _buildCompletionOverlay() {
    return Container(
      color: AppColors.background.withValues(alpha: 0.95),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_circle,
                  size: 60,
                  color: AppColors.success,
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Cooking Complete!',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'You\'ve successfully completed ${cookAlongState.session?.recipe.title ?? "the recipe"}!',
                style: AppTextStyles.bodyLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryAccent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: const Text(
                    'Done',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _sendQuestion() {
    if (_questionController.text.trim().isEmpty) return;

    cookAlongState.askQuestion(_questionController.text);
    _questionController.clear();
  }

  Future<void> _showExitConfirmation() async {
    final shouldExit = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text(
          'Exit Cook Along?',
          style: TextStyle(color: AppColors.textPrimary),
        ),
        content: const Text(
          'Are you sure you want to exit? Your progress will be lost.',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text(
              'Cancel',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Exit',
              style: TextStyle(color: AppColors.primaryAccent),
            ),
          ),
        ],
      ),
    );

    if (shouldExit == true && mounted) {
      // Exit gracefully with goodbye message
      await cookAlongState.endSessionGracefully();
      if (mounted) {
        Navigator.pop(context);
      }
    }
  }
}
