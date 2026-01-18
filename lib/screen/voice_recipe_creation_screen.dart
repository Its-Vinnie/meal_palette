import 'dart:async';
import 'package:flutter/material.dart';
import 'package:meal_palette/model/custom_recipe_model.dart';
import 'package:meal_palette/model/ingredient_model.dart';
import 'package:meal_palette/model/instruction_step_model.dart';
import 'package:meal_palette/service/auth_service.dart';
import 'package:meal_palette/service/cook_along_service.dart';
import 'package:meal_palette/state/custom_recipes_state.dart';
import 'package:meal_palette/theme/theme_design.dart';
import 'package:meal_palette/widgets/voice_animation_controller.dart';
import 'package:uuid/uuid.dart';

/// Voice conversation message model
class VoiceMessage {
  final String id;
  final String content;
  final bool isUser;
  final DateTime timestamp;

  VoiceMessage({
    required this.id,
    required this.content,
    required this.isUser,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();
}

/// Voice conversation state
enum VoiceState {
  idle,
  listening,
  processing,
  speaking,
}

/// Voice-based recipe creation screen with AI conversation
/// Modern ChatGPT/Claude-style UI with animated visualizations
class VoiceRecipeCreationScreen extends StatefulWidget {
  const VoiceRecipeCreationScreen({super.key});

  @override
  State<VoiceRecipeCreationScreen> createState() => _VoiceRecipeCreationScreenState();
}

class _VoiceRecipeCreationScreenState extends State<VoiceRecipeCreationScreen> {
  final _authService = authService;
  final _cookAlongService = cookAlongService;
  final _recipesState = customRecipesState;
  final _uuid = const Uuid();
  final _scrollController = ScrollController();

  // Voice state
  VoiceState _voiceState = VoiceState.idle;
  bool _isInVoiceMode = true;
  bool _isSaving = false;
  String _currentStep = 'ready';
  final List<VoiceMessage> _messages = [];

  // Speech recognition state
  String _currentSpeechText = '';
  bool _handsFreeModeActive = false;

  // Audio level for voice animation sync (0.0 to 1.0)
  double _audioLevel = 0.0;

  // Recipe data
  String _title = '';
  final List<String> _ingredients = [];
  final List<String> _instructions = [];
  int? _servings;
  int? _prepTime;
  int? _cookTime;
  String? _category;

  // Word to number mapping
  static const Map<String, int> _wordNumbers = {
    'zero': 0, 'one': 1, 'two': 2, 'three': 3, 'four': 4,
    'five': 5, 'six': 6, 'seven': 7, 'eight': 8, 'nine': 9,
    'ten': 10, 'eleven': 11, 'twelve': 12, 'thirteen': 13,
    'fourteen': 14, 'fifteen': 15, 'sixteen': 16, 'seventeen': 17,
    'eighteen': 18, 'nineteen': 19, 'twenty': 20, 'thirty': 30,
    'forty': 40, 'fifty': 50, 'sixty': 60, 'seventy': 70,
    'eighty': 80, 'ninety': 90, 'hundred': 100,
  };

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    // Check permissions
    final hasPermissions = await _cookAlongService.checkPermissions();
    if (!hasPermissions && mounted) {
      final granted = await _cookAlongService.requestPermissions();
      if (!granted && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Microphone permission is required for voice commands'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }

    // Set up audio level callback for animation sync
    _cookAlongService.onAudioLevelChange = (level) {
      if (mounted) {
        setState(() {
          _audioLevel = level.clamp(0.0, 1.0);
          // Sync listening state with service
          if (_cookAlongService.handsFreeModeActive && _voiceState != VoiceState.speaking && _voiceState != VoiceState.processing) {
            _voiceState = VoiceState.listening;
            _handsFreeModeActive = true;
          }
        });
      }
    };

    // Initialize with welcome message
    final welcomeMessage = "Hi! I'm here to help you create a recipe using just your voice. Let's start with the recipe name. What would you like to call this recipe?";
    _addMessage(welcomeMessage, isUser: false);
    _currentStep = 'title';

    setState(() => _voiceState = VoiceState.speaking);
    await _speakMessage(welcomeMessage);
    setState(() => _voiceState = VoiceState.idle);
  }

  void _addMessage(String content, {required bool isUser}) {
    setState(() {
      _messages.add(VoiceMessage(
        id: _uuid.v4(),
        content: content,
        isUser: isUser,
      ));
    });

    // Scroll to bottom
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _speakMessage(String message) async {
    // Use speakAndWait which properly tracks TTS completion and audio levels
    await _cookAlongService.speakAndWait(message, interrupt: true, useNatural: true);
  }

  int? _parseNumber(String text) {
    final lowerText = text.toLowerCase().trim();
    final directParse = int.tryParse(lowerText.replaceAll(RegExp(r'[^0-9]'), ''));
    if (directParse != null && directParse > 0) return directParse;

    for (final entry in _wordNumbers.entries) {
      if (lowerText.contains(entry.key)) return entry.value;
    }
    return null;
  }

  /// Start hands-free listening mode
  /// The system will continuously listen and automatically process speech
  /// when the user stops talking - no need to tap to send
  Future<void> _startHandsFreeListening() async {
    if (_voiceState == VoiceState.processing || _handsFreeModeActive) return;

    setState(() {
      _voiceState = VoiceState.listening;
      _currentSpeechText = '';
      _handsFreeModeActive = true;
    });

    // Set up the recognized text callback for UI updates
    _cookAlongService.onRecognizedText = (text) {
      if (text.isNotEmpty && mounted) {
        setState(() => _currentSpeechText = text);
      }
    };

    try {
      // Use hands-free listening which automatically:
      // 1. Detects when user stops speaking
      // 2. Processes the speech
      // 3. Resumes listening after AI responds
      await _cookAlongService.startHandsFreeListening(
        onResult: (text) {
          if (text.isNotEmpty && mounted) {
            _handleUserResponse(text);
          }
        },
      );
    } catch (e) {
      print('Error starting hands-free listening: $e');
      setState(() {
        _voiceState = VoiceState.idle;
        _handsFreeModeActive = false;
      });
    }
  }

  /// Stop hands-free listening mode
  Future<void> _stopHandsFreeListening() async {
    await _cookAlongService.stopHandsFreeListening();
    setState(() {
      _voiceState = VoiceState.idle;
      _handsFreeModeActive = false;
      _currentSpeechText = '';
    });
  }

  Future<void> _handleUserResponse(String response) async {
    if (_voiceState == VoiceState.processing) return;

    setState(() {
      _voiceState = VoiceState.processing;
      _currentSpeechText = '';
    });
    _addMessage(response, isUser: true);

    String aiResponse = '';

    switch (_currentStep) {
      case 'title':
        _title = response;
        aiResponse = "Great! '$_title' sounds delicious. Now, let's add the ingredients. Tell me the first ingredient with its quantity and unit. For example: '2 cups flour' or '1 pound chicken'.";
        _currentStep = 'ingredients';
        break;

      case 'ingredients':
        if (response.toLowerCase().contains('done') ||
            response.toLowerCase().contains('finished') ||
            response.toLowerCase().contains('that\'s all')) {
          if (_ingredients.isEmpty) {
            aiResponse = "You haven't added any ingredients yet. Please tell me at least one ingredient.";
          } else {
            aiResponse = "Perfect! I've noted ${_ingredients.length} ingredients. Now let's move to the cooking instructions. What's the first step?";
            _currentStep = 'instructions';
          }
        } else {
          _ingredients.add(response);
          aiResponse = "Got it! '${response}' added. Tell me the next ingredient, or say 'done' if you've finished adding ingredients.";
        }
        break;

      case 'instructions':
        if (response.toLowerCase().contains('done') ||
            response.toLowerCase().contains('finished') ||
            response.toLowerCase().contains('that\'s all')) {
          if (_instructions.isEmpty) {
            aiResponse = "You haven't added any instructions yet. Please tell me at least one step.";
          } else {
            aiResponse = "Excellent! I have ${_instructions.length} steps. Now, a few quick questions: How many servings does this recipe make?";
            _currentStep = 'servings';
          }
        } else {
          _instructions.add(response);
          aiResponse = "Step ${_instructions.length} noted. What's the next step? Or say 'done' if you've finished.";
        }
        break;

      case 'servings':
        final servings = _parseNumber(response);
        if (servings != null && servings > 0) {
          _servings = servings;
          aiResponse = "Got it, $servings servings. How long does it take to prep? Say the time in minutes, like '15 minutes' or 'skip' if you don't know.";
          _currentStep = 'prepTime';
        } else {
          aiResponse = "I didn't catch that. Please tell me how many servings, like '4' or 'six'.";
        }
        break;

      case 'prepTime':
        if (response.toLowerCase().contains('skip')) {
          aiResponse = "No problem. How long does it take to cook? Say the time in minutes or 'skip'.";
          _currentStep = 'cookTime';
        } else {
          final time = _parseNumber(response);
          if (time != null && time > 0) {
            _prepTime = time;
            aiResponse = "Great, $time minutes prep time. And how long to cook?";
            _currentStep = 'cookTime';
          } else {
            aiResponse = "I didn't catch that. Tell me the prep time in minutes, like '15' or 'skip'.";
          }
        }
        break;

      case 'cookTime':
        if (response.toLowerCase().contains('skip')) {
          aiResponse = "Alright! Last question: What category is this recipe? Like breakfast, lunch, dinner, dessert, or snack?";
          _currentStep = 'category';
        } else {
          final time = _parseNumber(response);
          if (time != null && time > 0) {
            _cookTime = time;
            aiResponse = "Perfect! What category is this recipe? Like breakfast, lunch, dinner, dessert, or snack?";
            _currentStep = 'category';
          } else {
            aiResponse = "I didn't catch that. Tell me the cooking time in minutes, like '30' or 'skip'.";
          }
        }
        break;

      case 'category':
        _category = response.toLowerCase();
        aiResponse = "Wonderful! I have all the information I need. Let me save your recipe '$_title' now.";
        _currentStep = 'complete';
        _addMessage(aiResponse, isUser: false);
        setState(() => _voiceState = VoiceState.speaking);
        await _speakMessage(aiResponse);
        await _saveRecipe();
        return;
    }

    _addMessage(aiResponse, isUser: false);
    setState(() => _voiceState = VoiceState.speaking);
    await _speakMessage(aiResponse);

    // Resume hands-free listening after AI finishes speaking
    if (_handsFreeModeActive && mounted) {
      setState(() => _voiceState = VoiceState.listening);
      // The service will automatically resume listening via TTS completion handler
    } else {
      setState(() => _voiceState = VoiceState.idle);
    }
  }

  Future<void> _saveRecipe() async {
    final user = _authService.currentUser;
    if (user == null) return;

    setState(() => _isSaving = true);

    try {
      final ingredients = _ingredients.map((ing) {
        final parts = ing.split(' ');
        final amount = double.tryParse(parts.first) ?? 0.0;
        final unit = parts.length > 1 ? parts[1] : '';
        final name = parts.length > 2 ? parts.sublist(2).join(' ') : ing;

        return Ingredient(
          id: 0,
          name: name,
          original: ing,
          amount: amount,
          unit: unit,
        );
      }).toList();

      final instructions = _instructions
          .asMap()
          .entries
          .map((entry) => InstructionStep(
                number: entry.key + 1,
                step: entry.value,
              ))
          .toList();

      final recipe = CustomRecipe(
        id: _uuid.v4(),
        userId: user.uid,
        title: _title,
        ingredients: ingredients,
        instructions: instructions,
        servings: _servings,
        prepTime: _prepTime,
        cookTime: _cookTime,
        category: _category,
        createdAt: DateTime.now(),
        source: 'voice',
      );

      final recipeId = await _recipesState.createRecipe(user.uid, recipe);

      if (recipeId != null && mounted) {
        final successMessage = "Your recipe has been saved successfully! You can find it in 'My Recipes'. Goodbye!";
        _addMessage(successMessage, isUser: false);
        setState(() => _voiceState = VoiceState.speaking);
        await _speakMessage(successMessage);

        // Wait for TTS to actually finish (estimate based on message length)
        // Average TTS speaks ~150 words per minute, so ~2.5 words/second
        final wordCount = successMessage.split(' ').length;
        final estimatedDuration = Duration(milliseconds: (wordCount / 2.5 * 1000).toInt() + 1000);
        await Future.delayed(estimatedDuration);

        setState(() => _voiceState = VoiceState.idle);

        if (mounted) Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save recipe: $e'),
            backgroundColor: AppColors.favorite,
          ),
        );
      }
    } finally {
      setState(() => _isSaving = false);
    }
  }

  void _toggleVoiceMode() {
    setState(() {
      _isInVoiceMode = !_isInVoiceMode;
      if (!_isInVoiceMode) {
        _cookAlongService.stopListening();
        _voiceState = VoiceState.idle;
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _cookAlongService.stopHandsFreeListening();
    _cookAlongService.stopSpeaking();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: _isInVoiceMode ? _buildVoiceMode() : _buildChatMode(),
      ),
    );
  }

  /// Full-screen voice conversation mode (like Claude/ChatGPT)
  Widget _buildVoiceMode() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppColors.background,
            AppColors.surface.withValues(alpha: 0.3),
            AppColors.background,
          ],
        ),
      ),
      child: Column(
        children: [
          // Top bar
          _buildTopBar(),

          // Main voice visualization area
          Expanded(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Animated orb
                  _buildAnimatedOrb(),

                  const SizedBox(height: 40),

                  // Status text
                  _buildStatusText(),

                  // Live transcription
                  if (_voiceState == VoiceState.listening && _currentSpeechText.isNotEmpty)
                    _buildLiveTranscription(),
                ],
              ),
            ),
          ),

          // Bottom controls
          _buildBottomControls(),
        ],
      ),
    );
  }

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Close button
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.surface.withValues(alpha: 0.5),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.close, color: AppColors.textPrimary, size: 20),
            ),
          ),

          // Title
          Text(
            'Voice Recipe Creation',
            style: AppTextStyles.bodyLarge.copyWith(
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),

          // Chat mode toggle
          IconButton(
            onPressed: _toggleVoiceMode,
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.surface.withValues(alpha: 0.5),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.chat_bubble_outline, color: AppColors.textPrimary, size: 20),
            ),
          ),
        ],
      ),
    );
  }

  /// Animated orb visualization using VoiceOrbWidget (same as cook along mode)
  Widget _buildAnimatedOrb() {
    return VoiceOrbWidget(
      size: 160,
      isAISpeaking: _voiceState == VoiceState.speaking,
      isUserSpeaking: _voiceState == VoiceState.listening,
      isListening: _voiceState == VoiceState.listening,
      isProcessing: _voiceState == VoiceState.processing,
      audioLevel: _audioLevel,
      primaryColor: _getOrbColor(),
    );
  }

  /// Get the orb color based on current state
  Color _getOrbColor() {
    switch (_voiceState) {
      case VoiceState.listening:
        return AppColors.favorite; // Red/coral for listening
      case VoiceState.speaking:
        return AppColors.success; // Green for speaking
      case VoiceState.processing:
        return AppColors.textSecondary; // Gray for processing
      case VoiceState.idle:
        return AppColors.primaryAccent; // Default accent color
    }
  }

  Widget _buildStatusText() {
    String statusText;
    Color statusColor;

    switch (_voiceState) {
      case VoiceState.listening:
        statusText = 'Listening... (hands-free)';
        statusColor = AppColors.primaryAccent;
        break;
      case VoiceState.processing:
        statusText = 'Processing...';
        statusColor = AppColors.textSecondary;
        break;
      case VoiceState.speaking:
        statusText = 'Speaking...';
        statusColor = AppColors.success;
        break;
      case VoiceState.idle:
        statusText = 'Tap to start hands-free mode';
        statusColor = AppColors.textSecondary;
        break;
    }

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 200),
      child: Text(
        statusText,
        key: ValueKey(statusText),
        style: AppTextStyles.bodyLarge.copyWith(
          color: statusColor,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildLiveTranscription() {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        decoration: BoxDecoration(
          color: AppColors.surface.withValues(alpha: 0.8),
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        child: Text(
          '"$_currentSpeechText"',
          style: AppTextStyles.bodyMedium.copyWith(
            color: AppColors.textPrimary,
            fontStyle: FontStyle.italic,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  Widget _buildBottomControls() {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Main action button - toggle hands-free mode
          GestureDetector(
            onTap: () {
              if (_handsFreeModeActive) {
                _stopHandsFreeListening();
              } else if (_voiceState == VoiceState.idle) {
                _startHandsFreeListening();
              }
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: _handsFreeModeActive ? 72 : 64,
              height: _handsFreeModeActive ? 72 : 64,
              decoration: BoxDecoration(
                color: _handsFreeModeActive
                    ? AppColors.favorite
                    : AppColors.primaryAccent,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: (_handsFreeModeActive
                            ? AppColors.favorite
                            : AppColors.primaryAccent)
                        .withValues(alpha: 0.4),
                    blurRadius: 20,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Icon(
                _handsFreeModeActive ? Icons.stop : Icons.mic,
                size: 32,
                color: Colors.white,
              ),
            ),
          ),

          const SizedBox(height: AppSpacing.lg),

          // Helper text
          Text(
            _handsFreeModeActive
                ? 'Hands-free mode active - just speak!'
                : 'Tap to start hands-free mode',
            style: AppTextStyles.labelMedium.copyWith(
              color: AppColors.textTertiary,
            ),
          ),

          const SizedBox(height: AppSpacing.md),

          // View chat button
          TextButton.icon(
            onPressed: _toggleVoiceMode,
            icon: const Icon(Icons.chat_bubble_outline, size: 18),
            label: Text('View conversation (${_messages.length})'),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  /// Chat mode - shows conversation history
  Widget _buildChatMode() {
    return Column(
      children: [
        // App bar
        Container(
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            color: AppColors.surface,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
              ),
              const Expanded(
                child: Text(
                  'Voice Recipe Creation',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              // Voice mode toggle
              IconButton(
                onPressed: _toggleVoiceMode,
                icon: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primaryAccent,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.mic, color: Colors.white, size: 20),
                ),
              ),
            ],
          ),
        ),

        // Messages list
        Expanded(
          child: ListView.builder(
            controller: _scrollController,
            padding: const EdgeInsets.all(AppSpacing.lg),
            itemCount: _messages.length,
            itemBuilder: (context, index) {
              final message = _messages[index];
              return _buildMessageBubble(message);
            },
          ),
        ),

        // Bottom voice button
        Container(
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            color: AppColors.surface,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 4,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg,
                    vertical: AppSpacing.md,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                  ),
                  child: Text(
                    _currentStep != 'complete'
                        ? 'Tap mic to speak...'
                        : 'Recipe saved!',
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: AppColors.textTertiary,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              GestureDetector(
                onTap: _currentStep != 'complete' ? _toggleVoiceMode : null,
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: _currentStep != 'complete'
                        ? AppColors.primaryAccent
                        : AppColors.textTertiary,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.mic, color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMessageBubble(VoiceMessage message) {
    return Align(
      alignment: message.isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: AppSpacing.md),
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: message.isUser ? AppColors.primaryAccent : AppColors.surface,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(AppRadius.lg),
            topRight: const Radius.circular(AppRadius.lg),
            bottomLeft: Radius.circular(message.isUser ? AppRadius.lg : 4),
            bottomRight: Radius.circular(message.isUser ? 4 : AppRadius.lg),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!message.isUser)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        color: AppColors.primaryAccent,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.restaurant, size: 12, color: Colors.white),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Chef',
                      style: AppTextStyles.labelMedium.copyWith(
                        color: AppColors.primaryAccent,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            Text(
              message.content,
              style: AppTextStyles.bodyMedium.copyWith(
                color: message.isUser ? Colors.white : AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
