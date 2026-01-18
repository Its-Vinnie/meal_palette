import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import 'package:meal_palette/model/cook_along_session.dart';
import 'package:meal_palette/model/detailed_recipe_model.dart';
import 'package:meal_palette/model/instruction_step_model.dart';
import 'package:meal_palette/service/cook_along_service.dart';
import 'package:meal_palette/service/claude_conversation_service.dart';
import 'package:meal_palette/service/user_profile_service.dart';
import 'package:meal_palette/service/auth_service.dart';

/// Cook Along interaction mode
enum CookAlongMode {
  manual,  // Traditional button-based navigation
  voice,   // Voice command navigation with AI assistant
}

/// State management for Cook Along Mode
class CookAlongState extends ChangeNotifier {
  static CookAlongState? _instance;
  final _uuid = const Uuid();

  CookAlongSession? _session;
  bool _isListening = false;
  bool _isSpeaking = false;
  String? _currentQuestion;
  bool _isProcessingQuestion = false;
  bool _isProcessingCommand = false;
  bool _hasStartedCooking = false;

  // Mode toggle - voice or manual
  CookAlongMode _mode = CookAlongMode.voice;

  // Audio level for voice animation sync (0.0 to 1.0)
  double _audioLevel = 0.0;

  // Callback for exit request
  Function()? onExitRequested;

  // Private constructor
  CookAlongState._();

  // Singleton factory
  factory CookAlongState() {
    _instance ??= CookAlongState._();
    return _instance!;
  }

  // Getters
  CookAlongSession? get session => _session;
  bool get isListening => _isListening;
  bool get isSpeaking => _isSpeaking;
  bool get isActive => _session != null && !(_session?.isCompleted ?? true);
  bool get isPaused => _session?.isPaused ?? false;
  String? get currentQuestion => _currentQuestion;
  bool get isProcessingQuestion => _isProcessingQuestion;
  bool get hasStartedCooking => _hasStartedCooking;
  CookAlongMode get mode => _mode;
  double get audioLevel => _audioLevel;
  bool get isVoiceMode => _mode == CookAlongMode.voice;
  bool get isManualMode => _mode == CookAlongMode.manual;

  InstructionStep? get currentStep => _session?.currentStep;
  int get currentStepIndex => _session?.currentStepIndex ?? 0;
  int get totalSteps => _session?.totalSteps ?? 0;
  double get progress => _session?.progress ?? 0.0;
  List<StepTimer> get activeTimers => _session?.activeTimers ?? [];
  List<ChatMessage> get conversationHistory =>
      _session?.conversationHistory ?? [];

  /// Switch between voice and manual mode
  void switchMode(CookAlongMode newMode) {
    if (_mode == newMode) return;

    _mode = newMode;
    print('🔄 Switched to ${newMode == CookAlongMode.voice ? "voice" : "manual"} mode');

    if (newMode == CookAlongMode.manual) {
      // Stop voice features when switching to manual
      cookAlongService.stopHandsFreeListening();
      _isListening = false;
    } else {
      // Enable hands-free voice features when switching to voice mode
      if (_hasStartedCooking) {
        cookAlongService.startHandsFreeListening();
        _isListening = true;
      }
    }

    notifyListeners();
  }

  /// Update audio level for voice animation sync
  void updateAudioLevel(double level) {
    _audioLevel = level.clamp(0.0, 1.0);
    notifyListeners();
  }

  /// Start a new Cook Along session
  Future<void> startSession(RecipeDetail recipe, {CookAlongMode initialMode = CookAlongMode.voice}) async {
    _mode = initialMode;
    try {
      print('🎬 Starting Cook Along session for: ${recipe.title}');

      // Load and apply user's voice settings
      try {
        final userId = authService.currentUser?.uid;
        if (userId != null) {
          final userProfile = await userProfileService.getUserProfile(userId);
          if (userProfile?.voiceSettings != null) {
            await cookAlongService.updateVoiceSettings(userProfile!.voiceSettings!);
            print('✅ Applied user voice settings');
          }
        }
      } catch (e) {
        print('⚠️ Failed to load voice settings, using defaults: $e');
      }

      // Create new session
      _session = CookAlongSession(
        recipe: recipe,
        currentStepIndex: 0,
      );

      // Initialize speech recognition and ensure it's ready
      final speechInitialized = await cookAlongService.initializeSpeech();
      if (!speechInitialized) {
        print('⚠️ Speech recognition not available, voice commands disabled');
      }

      // Set up voice command callback
      cookAlongService.onVoiceCommand = _handleVoiceCommand;
      cookAlongService.onRecognizedText = (text) {
        print('🎤 Voice input: $text');
        // Sync listening state with service
        if (cookAlongService.handsFreeModeActive && !_isListening) {
          _isListening = true;
          notifyListeners();
        }
      };

      // Set up audio level callback for animation sync
      cookAlongService.onAudioLevelChange = (level) {
        _audioLevel = level.clamp(0.0, 1.0);
        // Also sync listening state
        _isListening = cookAlongService.handsFreeModeActive || cookAlongService.isListening;
        notifyListeners();
      };

      // Speak welcome message
      final welcomeMessage = claudeConversationService.generateWelcomeMessage(recipe);
      await _speakAndWait(welcomeMessage);

      // Add welcome message to conversation history
      _addMessage(
        content: welcomeMessage,
        role: ChatMessageRole.assistant,
      );

      // Enable hands-free listening after welcome message (only in voice mode)
      if (_mode == CookAlongMode.voice) {
        await cookAlongService.startHandsFreeListening();
        _isListening = true;
      }

      notifyListeners();
      print('✅ Cook Along session started with hands-free listening');
    } catch (e) {
      print('❌ Error starting session: $e');
      rethrow;
    }
  }

  /// Move to next step
  Future<void> nextStep() async {
    if (_session == null || !_session!.hasNextStep) return;

    try {
      print('➡️ Moving to next step');

      // Stop current speech
      await cookAlongService.stopSpeaking();

      // Update step index
      _session = _session!.copyWith(
        currentStepIndex: _session!.currentStepIndex + 1,
      );

      // Speak the new step
      await _speakCurrentStep();

      // Check for timers in the step
      await _checkAndCreateTimer();

      notifyListeners();
    } catch (e) {
      print('❌ Error moving to next step: $e');
    }
  }

  /// Move to previous step
  Future<void> previousStep() async {
    if (_session == null || !_session!.hasPreviousStep) return;

    try {
      print('⬅️ Moving to previous step');

      await cookAlongService.stopSpeaking();

      _session = _session!.copyWith(
        currentStepIndex: _session!.currentStepIndex - 1,
      );

      await _speakCurrentStep();

      notifyListeners();
    } catch (e) {
      print('❌ Error moving to previous step: $e');
    }
  }

  /// Repeat current step
  Future<void> repeatStep() async {
    if (_session == null) return;

    try {
      print('🔁 Repeating current step');
      await _speakCurrentStep();
    } catch (e) {
      print('❌ Error repeating step: $e');
    }
  }

  /// Pause the cooking session
  Future<void> pauseSession() async {
    if (_session == null) return;

    try {
      print('⏸️ Pausing session');

      _session = _session!.copyWith(isPaused: true);

      // Pause all timers
      for (final timer in _session!.activeTimers) {
        if (timer.status == TimerStatus.running) {
          timer.pause();
        }
      }

      await cookAlongService.stopSpeaking();
      await cookAlongService.speak('Session paused. Say "resume" when you\'re ready to continue.');

      notifyListeners();
    } catch (e) {
      print('❌ Error pausing session: $e');
    }
  }

  /// Resume the cooking session
  Future<void> resumeSession() async {
    if (_session == null || !_session!.isPaused) return;

    try {
      print('▶️ Resuming session');

      _session = _session!.copyWith(isPaused: false);

      // Resume all paused timers
      for (final timer in _session!.activeTimers) {
        if (timer.status == TimerStatus.paused) {
          timer.resume();
        }
      }

      await cookAlongService.speak('Resuming cooking. Let\'s continue!');
      await _speakCurrentStep();

      notifyListeners();
    } catch (e) {
      print('❌ Error resuming session: $e');
    }
  }

  /// Start cooking from step 1 (after welcome message)
  Future<void> startFirstStep() async {
    if (_session == null) return;

    try {
      print('🎬 Starting from step 1');

      _hasStartedCooking = true;

      // Speak step 1 (index 0)
      await _speakCurrentStep();

      // Check for timers in the step
      await _checkAndCreateTimer();

      notifyListeners();
    } catch (e) {
      print('❌ Error starting first step: $e');
    }
  }

  /// Exit gracefully with goodbye message
  Future<void> exitGracefully() async {
    try {
      print('👋 Exiting gracefully');

      await cookAlongService.stopSpeaking();

      final goodbyeMessage = 'Okay, I\'ll stop now. See you next time! Happy cooking!';
      await cookAlongService.speak(goodbyeMessage);

      // Wait for goodbye message to finish
      await Future.delayed(const Duration(seconds: 3));

      // Clean up
      cookAlongService.stopSpeaking();
      cookAlongService.stopListening();
      cookAlongService.cancelAllTimers();

      _session = null;
      _isListening = false;
      _isSpeaking = false;
      _hasStartedCooking = false;

      notifyListeners();

      // Trigger exit callback
      onExitRequested?.call();
    } catch (e) {
      print('❌ Error during graceful exit: $e');
      onExitRequested?.call();
    }
  }

  /// Complete the cooking session
  Future<void> completeSession() async {
    if (_session == null) return;

    try {
      print('🎉 Completing session');

      _session = _session!.copyWith(isCompleted: true);

      // Cancel all timers
      cookAlongService.cancelAllTimers();

      // Speak completion message
      final completionMessage =
          claudeConversationService.generateCompletionMessage(_session!.recipe);
      await cookAlongService.speak(completionMessage);

      _addMessage(
        content: completionMessage,
        role: ChatMessageRole.assistant,
      );

      notifyListeners();
    } catch (e) {
      print('❌ Error completing session: $e');
    }
  }

  /// End the cooking session
  void endSession() {
    print('🛑 Ending session');

    // Stop hands-free listening and all voice features
    cookAlongService.stopHandsFreeListening();
    cookAlongService.stopSpeaking();
    cookAlongService.cancelAllTimers();

    _session = null;
    _isListening = false;
    _isSpeaking = false;
    _currentQuestion = null;
    _isProcessingQuestion = false;
    _isProcessingCommand = false;
    _hasStartedCooking = false;
    _audioLevel = 0.0;
    _mode = CookAlongMode.voice;

    notifyListeners();
  }

  /// End session with a graceful goodbye
  Future<void> endSessionGracefully() async {
    print('👋 Ending session gracefully');

    await cookAlongService.stopSpeaking();

    final goodbyeMessage = 'Okay, I\'ll stop now. See you next time! Happy cooking!';
    await cookAlongService.speak(goodbyeMessage);

    // Wait for goodbye message
    await Future.delayed(const Duration(seconds: 3));

    endSession();
  }

  /// Ask a question to the AI assistant
  Future<void> askQuestion(String question) async {
    if (_session == null) return;

    try {
      print('❓ User question: $question');

      _currentQuestion = question;
      _isProcessingQuestion = true;
      notifyListeners();

      // Add user message
      _addMessage(content: question, role: ChatMessageRole.user);

      // Get AI response
      final response = await claudeConversationService.askCookingQuestion(
        question: question,
        recipe: _session!.recipe,
        currentStepNumber: _session!.currentStepIndex,
        conversationHistory: _session!.conversationHistory,
      );

      // Add assistant response
      _addMessage(content: response, role: ChatMessageRole.assistant);

      // Speak the response
      await cookAlongService.speak(response);

      _currentQuestion = null;
      _isProcessingQuestion = false;
      notifyListeners();
    } catch (e) {
      print('❌ Error asking question: $e');
      _currentQuestion = null;
      _isProcessingQuestion = false;
      notifyListeners();
    }
  }

  /// Start hands-free listening for voice input
  /// This enables continuous listening that automatically detects speech and silence
  Future<void> startListening() async {
    if (_isListening) return;

    try {
      // Ensure speech is initialized
      if (!cookAlongService.isSpeechAvailable) {
        final initialized = await cookAlongService.initializeSpeech();
        if (!initialized) {
          print('❌ Cannot start listening: Speech recognition not available');
          return;
        }
      }

      _isListening = true;
      notifyListeners();

      // Use hands-free listening mode for a hands-free cooking experience
      await cookAlongService.startHandsFreeListening(
        onResult: (text) {
          // If it's a question (not a command), ask it
          if (!_isVoiceCommand(text)) {
            askQuestion(text);
          }
        },
      );
    } catch (e) {
      print('❌ Error starting listening: $e');
      _isListening = false;
      notifyListeners();
    }
  }

  /// Stop hands-free listening for voice input
  Future<void> stopListening() async {
    if (!_isListening && !cookAlongService.handsFreeModeActive) return;

    await cookAlongService.stopHandsFreeListening();
    _isListening = false;
    notifyListeners();
  }

  /// Handle voice commands
  void _handleVoiceCommand(VoiceCommand command) {
    print('🎤 Voice command: $command');

    // Prevent duplicate command processing
    if (_isProcessingCommand) {
      print('⚠️ Already processing a command, ignoring');
      return;
    }
    _isProcessingCommand = true;

    switch (command) {
      case VoiceCommand.start:
        startFirstStep();
        break;
      case VoiceCommand.next:
        nextStep();
        break;
      case VoiceCommand.repeat:
        repeatStep();
        break;
      case VoiceCommand.back:
        previousStep();
        break;
      case VoiceCommand.pause:
        pauseSession();
        break;
      case VoiceCommand.resume:
        resumeSession();
        break;
      case VoiceCommand.help:
        startListening();
        break;
      case VoiceCommand.stopListening:
        stopListening();
        break;
      case VoiceCommand.complete:
        completeSession();
        break;
      case VoiceCommand.exit:
        exitGracefully();
        break;
      case VoiceCommand.unknown:
        break;
    }

    // Reset command processing flag after a delay
    Future.delayed(const Duration(milliseconds: 500), () {
      _isProcessingCommand = false;
    });
  }

  /// Speak the current step
  Future<void> _speakCurrentStep() async {
    if (_session == null) return;

    final step = _session!.currentStep;
    if (step == null) {
      // No more steps - complete the session
      await completeSession();
      return;
    }

    final stepNumber = _session!.currentStepIndex + 1;
    final totalSteps = _session!.totalSteps;

    final message = 'Step $stepNumber of $totalSteps: ${step.step}';

    _addMessage(
      content: message,
      role: ChatMessageRole.assistant,
      type: ChatMessageType.stepNavigation,
    );

    await _speakAndWait(message);
  }

  /// Speak text and wait for completion
  /// Uses the service's speakAndWait which properly tracks TTS completion
  Future<void> _speakAndWait(String text) async {
    _isSpeaking = true;
    notifyListeners();

    // Use the service method that properly waits for TTS completion
    await cookAlongService.speakAndWait(text);

    _isSpeaking = false;
    notifyListeners();
  }

  /// Check and create timer if step contains time reference
  Future<void> _checkAndCreateTimer() async {
    if (_session == null) return;

    final step = _session!.currentStep;
    if (step == null) return;

    final duration = cookAlongService.detectTimerInText(step.step);
    if (duration != null) {
      final description = cookAlongService.extractTimerDescription(
        step.step,
        duration,
      );

      final timer = StepTimer(
        id: _uuid.v4(),
        stepNumber: _session!.currentStepIndex + 1,
        duration: duration,
        description: description,
      );

      // Add timer to session
      final updatedTimers = [..._session!.activeTimers, timer];
      _session = _session!.copyWith(activeTimers: updatedTimers);

      // Create timer stream
      cookAlongService.createTimer(timer);

      // Announce timer
      await cookAlongService.speak('I\'ve started a timer for $description');

      notifyListeners();
    }
  }

  /// Add a message to conversation history
  void _addMessage({
    required String content,
    required ChatMessageRole role,
    ChatMessageType type = ChatMessageType.text,
  }) {
    if (_session == null) return;

    final message = ChatMessage(
      id: _uuid.v4(),
      content: content,
      role: role,
      type: type,
    );

    final updatedHistory = [..._session!.conversationHistory, message];
    _session = _session!.copyWith(conversationHistory: updatedHistory);
  }

  /// Check if text is a voice command
  bool _isVoiceCommand(String text) {
    final lowerText = text.toLowerCase();
    return lowerText.contains('next') ||
        lowerText.contains('repeat') ||
        lowerText.contains('back') ||
        lowerText.contains('pause') ||
        lowerText.contains('resume') ||
        lowerText.contains('stop');
  }

  /// Check ingredient as ready
  void checkIngredient(String ingredient) {
    if (_session == null) return;

    final updatedIngredients = [..._session!.checkedIngredients, ingredient];
    _session = _session!.copyWith(checkedIngredients: updatedIngredients);

    notifyListeners();
  }

  /// Uncheck ingredient
  void uncheckIngredient(String ingredient) {
    if (_session == null) return;

    final updatedIngredients = _session!.checkedIngredients
        .where((i) => i != ingredient)
        .toList();
    _session = _session!.copyWith(checkedIngredients: updatedIngredients);

    notifyListeners();
  }

  /// Check if ingredient is checked
  bool isIngredientChecked(String ingredient) {
    return _session?.checkedIngredients.contains(ingredient) ?? false;
  }

  /// Cancel a specific timer
  void cancelTimer(String timerId) {
    if (_session == null) return;

    // Find and cancel the timer
    final timer = _session!.activeTimers.firstWhere(
      (t) => t.id == timerId,
      orElse: () => throw Exception('Timer not found'),
    );

    timer.cancel();
    cookAlongService.cancelTimer(timerId);

    notifyListeners();
  }
}

/// Global singleton instance
final cookAlongState = CookAlongState();