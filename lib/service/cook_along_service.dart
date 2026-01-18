import 'dart:async';
import 'dart:math' as math;
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:permission_handler/permission_handler.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:meal_palette/model/cook_along_session.dart';
import 'package:meal_palette/model/voice_settings_model.dart';
import 'package:meal_palette/service/claude_conversation_service.dart';
import 'package:meal_palette/service/elevenlabs_service.dart';

/// Service for managing Cook Along Mode functionality
/// Handles Text-to-Speech, Speech-to-Text (built-in), and timer management
/// Implements hands-free continuous listening like ChatGPT voice mode
class CookAlongService {
  final FlutterTts _tts = FlutterTts();
  final stt.SpeechToText _speech = stt.SpeechToText();
  final ClaudeConversationService _claudeService = ClaudeConversationService();
  final AudioPlayer _audioPlayer = AudioPlayer();

  bool _isTtsInitialized = false;
  bool _isSpeechInitialized = false;
  bool _isListening = false;
  bool _isSpeaking = false;
  bool _useNaturalVoice = true; // Enable Claude-enhanced natural speech by default
  bool _continuousListeningEnabled = false;

  // Hands-free listening state
  bool _handsFreeModeActive = false;
  Timer? _silenceTimer;
  Timer? _restartListeningTimer;
  String _accumulatedText = '';
  Function(String)? _handsFreeonResult; // Store callback for restarting
  static const Duration _silenceThreshold = Duration(milliseconds: 1500);
  static const Duration _restartDelay = Duration(milliseconds: 800); // Longer delay for stability

  // Command debouncing
  String? _lastProcessedCommand;
  DateTime? _lastCommandTime;
  static const _commandDebounceMs = 2000; // 2 second debounce between commands

  // TTS settings
  VoiceSettings _currentSettings = VoiceSettings.defaultSettings;
  List<AvailableVoice> _availableVoices = [];

  // Callbacks
  Function(String)? onRecognizedText;
  Function(VoiceCommand)? onVoiceCommand;
  Function()? onTtsComplete;
  Function()? onSpeakingDone; // Called when AI is done speaking
  Function(double)? onAudioLevelChange; // Audio level for animation sync (0.0 to 1.0)

  // TTS audio level simulation
  Timer? _ttsAudioLevelTimer;
  double _simulatedAudioLevel = 0.0;
  Completer<void>? _ttsCompleter; // To properly await TTS completion

  // Timer streams
  final Map<String, StreamController<Duration>> _timerControllers = {};

  // Cache for natural speech conversions
  final Map<String, String> _naturalSpeechCache = {};

  // Getters
  bool get isSpeaking => _isSpeaking;
  bool get continuousListeningEnabled => _continuousListeningEnabled;
  bool get handsFreeModeActive => _handsFreeModeActive;

  CookAlongService() {
    _initializeTts();
  }

/// Check if all required permissions are granted
Future<bool> checkPermissions() async {
  final micStatus = await Permission.microphone.status;
  final speechStatus = await Permission.speech.status;
  
  print('🔍 Mic permission: $micStatus');
  print('🔍 Speech permission: $speechStatus');
  
  return micStatus.isGranted && speechStatus.isGranted;
}

/// Request all required permissions
Future<bool> requestPermissions() async {
  final micStatus = await Permission.microphone.request();
  final speechStatus = await Permission.speech.request();
  
  return micStatus.isGranted && speechStatus.isGranted;
}


  /// Initialize Text-to-Speech
  Future<void> _initializeTts() async {
    try {
      await _tts.setLanguage(_currentSettings.locale);
      await _tts.setSpeechRate(_currentSettings.speechRate);
      await _tts.setPitch(_currentSettings.pitch);
      await _tts.setVolume(_currentSettings.volume);

      // Set voice if specified
      if (_currentSettings.voiceName.isNotEmpty) {
        await _tts.setVoice({
          'name': _currentSettings.voiceName,
          'locale': _currentSettings.locale,
        });
        print('🔊 Set voice: ${_currentSettings.voiceName}');
      }

      // Set completion handler
      _tts.setCompletionHandler(() {
        print('🔊 TTS completed');
        _stopAudioLevelSimulation();
        _isSpeaking = false;

        // Complete the TTS completer if waiting
        if (_ttsCompleter != null && !_ttsCompleter!.isCompleted) {
          _ttsCompleter!.complete();
        }

        onTtsComplete?.call();
        onSpeakingDone?.call();

        // Auto-restart hands-free listening after speaking
        if (_handsFreeModeActive || _continuousListeningEnabled) {
          resumeHandsFreeListening();
        }
      });

      // Set start handler
      _tts.setStartHandler(() {
        print('🔊 TTS started speaking');
        _isSpeaking = true;
        _startAudioLevelSimulation();
      });

      // Set error handler
      _tts.setErrorHandler((msg) {
        print('❌ TTS error: $msg');
        _stopAudioLevelSimulation();
        _isSpeaking = false;

        // Complete with error
        if (_ttsCompleter != null && !_ttsCompleter!.isCompleted) {
          _ttsCompleter!.complete();
        }
      });

      _isTtsInitialized = true;
      print('✅ TTS initialized with locale: ${_currentSettings.locale}');
    } catch (e) {
      print('❌ Failed to initialize TTS: $e');
    }
  }

  /// Initialize Speech Recognition
  Future<bool> initializeSpeech() async {
    if (_isSpeechInitialized) return true;

    try {
      //Checking the current mic status first

      var micStatus = await Permission.microphone.status;
      print('🎤 Current mic status: $micStatus');

      // Request microphone permission if not granted
      if (!micStatus.isGranted) {
        micStatus = await Permission.microphone.request();
        print('After request mic status: $micStatus');
      }

      if (!micStatus.isGranted) {
        print('❌ Microphone permission denied');

        //check if permentantly denied
        if (micStatus.isPermanentlyDenied) {
          print(
              '❌ Microphone permission permanently denied - need to open settings');

          await openAppSettings();
        }
        return false;
      }

      // Initialize speech recognition
     var speechStatus = await Permission.speech.status;
    print('🎤 Current speech status: $speechStatus');
    
    if (!speechStatus.isGranted) {
      speechStatus = await Permission.speech.request();
      print('🎤 After request speech status: $speechStatus');
    }
    
    if (!speechStatus.isGranted) {
      print('❌ Speech recognition permission denied');
      if (speechStatus.isPermanentlyDenied) {
        await openAppSettings();
      }
      return false;
    }

    print('🎤 Permissions granted, initializing speech recognition...');

    // Initialize speech recognition
    _isSpeechInitialized = await _speech.initialize(
      onError: (error) {
        print('❌ Speech recognition error: ${error.errorMsg}');
        print('❌ Error type: ${error.runtimeType}');

        // Handle errors by restarting hands-free listening if active
        // error_no_match means no speech was detected - this is normal, just restart
        if (_handsFreeModeActive && !_isSpeaking) {
          _isListening = false;
          _scheduleHandsFreeRestart();
        }
      },
      onStatus: (status) {
        print('🎤 Speech status: $status');

        // When speech recognition stops (done/notListening), restart if in hands-free mode
        if ((status == 'done' || status == 'notListening') &&
            _handsFreeModeActive && !_isSpeaking && !_isListening) {
          _scheduleHandsFreeRestart();
        }
      },
    );

    if (_isSpeechInitialized) {
      print('✅ Speech recognition initialized successfully');
    } else {
      print('❌ Speech recognition initialization returned false');
    }

    return _isSpeechInitialized;
  } catch (e, stackTrace) {
    print('❌ Failed to initialize speech recognition: $e');
    print('❌ Stack trace: $stackTrace');
    return false;
  }
}

  /// Convert text to natural, conversational speech using Claude AI
  Future<String> _convertToNaturalSpeech(String text) async {
    // Check cache first
    if (_naturalSpeechCache.containsKey(text)) {
      return _naturalSpeechCache[text]!;
    }

    try {
      final prompt = '''Convert this cooking instruction into natural, conversational speech for a voice assistant. Make it sound friendly, warm, and encouraging - like a helpful chef guiding someone through cooking.

Original: "$text"

Rules:
- Keep it concise but natural
- Use contractions (we'll, let's, you'll)
- Add small encouraging phrases where appropriate
- Make it sound like a real person talking, not reading
- Don't add extra steps or information
- Return ONLY the converted speech text, no quotation marks or explanations

Example:
Input: "Step 1: Preheat the oven to 350 degrees Fahrenheit"
Output: Alright, let's start by preheating your oven to 350 degrees

Convert the text above following these rules:''';

      final response = await _claudeService.sendMessage(
        messages: [
          ChatMessage(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            content: prompt,
            role: ChatMessageRole.user,
            timestamp: DateTime.now(),
            type: ChatMessageType.text,
          ),
        ],
        systemPrompt: 'You are a friendly cooking voice assistant. Convert recipe instructions into natural, conversational speech.',
      );

      final naturalText = response.trim();

      // Cache the result
      _naturalSpeechCache[text] = naturalText;

      print('✨ Natural speech: $naturalText');
      return naturalText;
    } catch (e) {
      print('⚠️ Failed to convert to natural speech, using original: $e');
      return text; // Fallback to original text
    }
  }

  /// Speak text using TTS with optional Claude-enhanced natural voice
  Future<void> speak(String text, {bool interrupt = false, bool useNatural = true}) async {
    try {
      if (interrupt) {
        await _tts.stop();
        await _audioPlayer.stop();
      }

      // Convert to natural speech if enabled
      String textToSpeak = text;
      if (useNatural && _useNaturalVoice) {
        textToSpeak = await _convertToNaturalSpeech(text);
      }

      print(
          '🔊 Speaking: ${textToSpeak.substring(0, textToSpeak.length > 50 ? 50 : textToSpeak.length)}...');

      // Check if using premium voice
      if (_currentSettings.isPremium && _currentSettings.voiceId != null) {
        // Use ElevenLabs for premium voices
        final audioPath = await elevenLabsService.textToSpeech(
          text: textToSpeak,
          voiceId: _currentSettings.voiceId!,
          stability: _currentSettings.pitch / 2.0, // Map pitch to stability
          similarityBoost: _currentSettings.volume,
        );

        if (audioPath != null) {
          await _audioPlayer.play(DeviceFileSource(audioPath));
        } else {
          print('⚠️ Failed to generate premium voice, falling back to device TTS');
          if (!_isTtsInitialized) {
            await _initializeTts();
          }
          await _tts.speak(textToSpeak);
        }
      } else {
        // Use device TTS for standard voices
        if (!_isTtsInitialized) {
          await _initializeTts();
        }
        await _tts.speak(textToSpeak);
      }
    } catch (e) {
      print('❌ Error speaking: $e');
    }
  }

  /// Stop current speech
  Future<void> stopSpeaking() async {
    try {
      await _tts.stop();
      await _audioPlayer.stop();
      print('🔇 Stopped speaking');
    } catch (e) {
      print('❌ Error stopping speech: $e');
    }
  }

  /// Pause current speech
  Future<void> pauseSpeaking() async {
    try {
      await _tts.pause();
      print('⏸️ Paused speaking');
    } catch (e) {
      print('❌ Error pausing speech: $e');
    }
  }

  /// Start simulating audio levels during TTS playback
  /// This creates realistic-looking audio visualization since TTS doesn't provide real levels
  void _startAudioLevelSimulation() {
    _stopAudioLevelSimulation(); // Clean up any existing timer

    int tickCount = 0;
    _ttsAudioLevelTimer = Timer.periodic(const Duration(milliseconds: 50), (timer) {
      tickCount++;

      // Create natural-looking speech patterns with varying amplitudes
      // Simulate speech rhythm: louder during "words", quieter during "pauses"
      final baseLevel = 0.3;

      // Use multiple sine waves at different frequencies for natural variation
      final wave1 = math.sin(tickCount * 0.3) * 0.3;  // Slow wave for overall rhythm
      final wave2 = math.sin(tickCount * 0.8) * 0.2;  // Medium wave for word patterns
      final wave3 = math.sin(tickCount * 2.1) * 0.15; // Fast wave for syllables
      final randomNoise = (math.Random().nextDouble() - 0.5) * 0.1; // Small random variation

      _simulatedAudioLevel = (baseLevel + wave1 + wave2 + wave3 + randomNoise)
          .clamp(0.1, 1.0);

      // Notify listeners of the simulated audio level
      onAudioLevelChange?.call(_simulatedAudioLevel);
    });

    print('🎵 Started TTS audio level simulation');
  }

  /// Stop the audio level simulation
  void _stopAudioLevelSimulation() {
    _ttsAudioLevelTimer?.cancel();
    _ttsAudioLevelTimer = null;
    _simulatedAudioLevel = 0.0;
    onAudioLevelChange?.call(0.0);
  }

  /// Speak text and wait for completion
  /// Returns a Future that completes when TTS finishes speaking
  Future<void> speakAndWait(String text, {bool interrupt = false, bool useNatural = true}) async {
    _ttsCompleter = Completer<void>();

    await speak(text, interrupt: interrupt, useNatural: useNatural);

    // Wait for TTS to complete (completion handler will complete the completer)
    // Add a timeout as safety net
    try {
      await _ttsCompleter!.future.timeout(
        Duration(seconds: (text.length / 10).ceil() + 10), // Rough estimate + buffer
        onTimeout: () {
          print('⚠️ TTS completion timeout - continuing');
          _stopAudioLevelSimulation();
        },
      );
    } catch (e) {
      print('⚠️ TTS wait error: $e');
      _stopAudioLevelSimulation();
    }

    _ttsCompleter = null;
  }

  /// Get all available voices from the platform
  Future<List<AvailableVoice>> getAvailableVoices() async {
    if (_availableVoices.isNotEmpty) {
      return _availableVoices;
    }

    try {
      final voices = await _tts.getVoices;
      if (voices != null && voices is List) {
        _availableVoices = voices
            .map((voice) {
              if (voice is Map) {
                final map = Map<String, dynamic>.from(voice);
                return AvailableVoice.fromMap(map);
              }
              return null;
            })
            .whereType<AvailableVoice>()
            .toList();

        // Filter to English voices only
        _availableVoices = _availableVoices
            .where((v) => v.locale.toLowerCase().startsWith('en'))
            .toList();

        print('✅ Found ${_availableVoices.length} English voices');
        return _availableVoices;
      }
    } catch (e) {
      print('❌ Error getting voices: $e');
    }

    return [];
  }

  /// Update voice settings and reinitialize TTS
  Future<void> updateVoiceSettings(VoiceSettings settings) async {
    _currentSettings = settings;
    _isTtsInitialized = false;
    await _initializeTts();
    print('✅ Voice settings updated');
  }

  /// Preview a voice by speaking sample text
  Future<void> previewVoice(AvailableVoice voice, {String? text}) async {
    try {
      await stopSpeaking();

      // Temporarily set voice
      await _tts.setVoice({
        'name': voice.name,
        'locale': voice.locale,
      });

      final sampleText = text ??
          'Hello! This is how I will sound when guiding you through your recipes. Let\'s cook something delicious together!';

      await _tts.speak(sampleText);

      // Wait a bit then restore current voice
      await Future.delayed(const Duration(milliseconds: 500));
    } catch (e) {
      print('❌ Error previewing voice: $e');
    }
  }

  /// Get current voice settings
  VoiceSettings get currentSettings => _currentSettings;

  /// Set speech rate (0.0 to 1.0)
  Future<void> setSpeechRate(double rate) async {
    _currentSettings =
        _currentSettings.copyWith(speechRate: rate.clamp(0.0, 1.0));
    await _tts.setSpeechRate(_currentSettings.speechRate);
  }

  /// Set speech pitch (0.5 to 2.0)
  Future<void> setSpeechPitch(double pitch) async {
    _currentSettings = _currentSettings.copyWith(pitch: pitch.clamp(0.5, 2.0));
    await _tts.setPitch(_currentSettings.pitch);
  }

  /// Set volume (0.0 to 1.0)
  Future<void> setVolume(double volume) async {
    _currentSettings =
        _currentSettings.copyWith(volume: volume.clamp(0.0, 1.0));
    await _tts.setVolume(_currentSettings.volume);
  }

  /// Enable continuous hands-free listening mode (like ChatGPT voice mode)
  /// When enabled, the system will automatically listen and process speech
  /// without requiring the user to tap to send
  void enableContinuousListening(bool enable) {
    _continuousListeningEnabled = enable;
    print('🎤 Continuous listening: ${enable ? 'enabled' : 'disabled'}');

    if (enable && !_handsFreeModeActive && !_isSpeaking) {
      _startContinuousListening();
    } else if (!enable) {
      stopHandsFreeListening();
    }
  }

  /// Start continuous hands-free listening (internal)
  Future<void> _startContinuousListening() async {
    if (_handsFreeModeActive || _isSpeaking) return;

    try {
      await startHandsFreeListening();
    } catch (e) {
      print('❌ Error starting continuous listening: $e');
    }
  }

  /// Resume hands-free listening after TTS completes
  /// Call this after AI finishes speaking to restart listening
  void resumeHandsFreeListening() {
    if (_handsFreeModeActive && !_isSpeaking) {
      print('🔄 Resuming hands-free listening after TTS...');
      _scheduleHandsFreeRestart();
    }
  }

  /// Check if command should be processed (debouncing)
  bool _shouldProcessCommand(String commandText) {
    final now = DateTime.now();

    // Check if same command was processed recently
    if (_lastProcessedCommand == commandText && _lastCommandTime != null) {
      final elapsed = now.difference(_lastCommandTime!).inMilliseconds;
      if (elapsed < _commandDebounceMs) {
        print('⚠️ Command debounced: $commandText (${elapsed}ms ago)');
        return false;
      }
    }

    _lastProcessedCommand = commandText;
    _lastCommandTime = now;
    return true;
  }

  /// Start hands-free listening mode
  /// This mode automatically detects silence and processes speech,
  /// then resumes listening - no need to tap to send
  Future<void> startHandsFreeListening({
    Function(String)? onResult,
  }) async {
    if (_isSpeaking) {
      print('Cannot start listening while speaking');
      return;
    }

    if (_handsFreeModeActive) {
      print('Hands-free mode already active');
      return;
    }

    _handsFreeModeActive = true;
    _handsFreeonResult = onResult; // Store callback for restarts
    _accumulatedText = '';
    print('🎤 Hands-free listening mode activated');

    await _startHandsFreeSession(onResult: onResult);
  }

  /// Stop hands-free listening mode
  Future<void> stopHandsFreeListening() async {
    _handsFreeModeActive = false;
    _handsFreeonResult = null;
    _silenceTimer?.cancel();
    _restartListeningTimer?.cancel();
    _silenceTimer = null;
    _restartListeningTimer = null;
    _accumulatedText = '';
    await _speech.stop();
    _isListening = false;
    print('🔇 Hands-free listening mode deactivated');
  }

  /// Schedule a hands-free listening restart after a delay
  void _scheduleHandsFreeRestart() {
    _restartListeningTimer?.cancel();
    _restartListeningTimer = Timer(_restartDelay, () {
      if (_handsFreeModeActive && !_isListening && !_isSpeaking) {
        print('🔄 Restarting hands-free listening...');
        _startHandsFreeSession(onResult: _handsFreeonResult);
      }
    });
  }

  /// Internal method to start a hands-free listening session
  Future<void> _startHandsFreeSession({
    Function(String)? onResult,
  }) async {
    if (!_handsFreeModeActive || _isSpeaking) {
      print('🎤 Cannot start session: handsFreeModeActive=$_handsFreeModeActive, isSpeaking=$_isSpeaking');
      return;
    }

    // Cancel any pending restart
    _restartListeningTimer?.cancel();

    if (!_isSpeechInitialized) {
      final initialized = await initializeSpeech();
      if (!initialized) {
        print('Cannot start listening: speech recognition not available');
        _handsFreeModeActive = false;
        throw Exception('Speech recognition not available. Please check permissions.');
      }
    }

    // Make sure speech is stopped before starting a new session
    try {
      await _speech.stop();
    } catch (e) {
      // Ignore stop errors
    }

    // Small delay to ensure clean state
    await Future.delayed(const Duration(milliseconds: 100));

    if (!_handsFreeModeActive || _isSpeaking) return; // Check again after delay

    try {
      _isListening = true;
      _accumulatedText = '';
      print('🎤 Starting hands-free listening session...');

      await _speech.listen(
        onResult: (result) {
          final recognizedText = result.recognizedWords.trim();

          if (recognizedText.isNotEmpty) {
            _accumulatedText = recognizedText;
            onRecognizedText?.call(recognizedText);

            // Reset silence timer on new speech
            _silenceTimer?.cancel();

            if (result.finalResult) {
              // Speech ended, process after a short delay to ensure we got everything
              _silenceTimer = Timer(_silenceThreshold, () {
                if (_accumulatedText.isNotEmpty && _handsFreeModeActive) {
                  _processHandsFreeResult(_accumulatedText, onResult: onResult);
                }
              });
            }
          }
        },
        listenFor: const Duration(seconds: 30),
        pauseFor: const Duration(seconds: 3), // Longer pause to detect end of speech
        listenOptions: stt.SpeechListenOptions(
          cancelOnError: false,
          listenMode: stt.ListenMode.dictation,
        ),
        onSoundLevelChange: (level) {
          // Normalize level (typically -2 to 10 dB range) to 0-1
          final normalized = ((level + 2) / 12).clamp(0.0, 1.0);
          onAudioLevelChange?.call(normalized);
        },
      );

      // Note: _speech.listen returns immediately. The actual listening happens async.
      // Errors and completion are handled via the onError and onStatus callbacks
      // set up in initializeSpeech()

    } catch (e, stackTrace) {
      print('Error in hands-free listening: $e');
      print('Stack trace: $stackTrace');
      _isListening = false;

      // Try to restart if hands-free mode is still active
      if (_handsFreeModeActive && !_isSpeaking) {
        _scheduleHandsFreeRestart();
      }
    }
  }

  /// Process the result from hands-free listening
  void _processHandsFreeResult(String text, {Function(String)? onResult}) async {
    if (text.isEmpty) return;

    final lowerText = text.toLowerCase();
    print('🎤 Processing hands-free result: $lowerText');

    // Stop current listening session
    try {
      await _speech.stop();
    } catch (e) {
      // Ignore stop errors
    }
    _isListening = false;

    // Notify callbacks
    onResult?.call(lowerText);

    // Parse voice command
    final command = _parseVoiceCommand(lowerText);
    if (command != VoiceCommand.unknown) {
      if (_shouldProcessCommand(command.toString())) {
        print('📢 Processing command: $command');
        onVoiceCommand?.call(command);
      }
    }

    // Clear accumulated text
    _accumulatedText = '';

    // Note: Restart will be triggered automatically after TTS completes
    // via the TTS completion handler -> resumeHandsFreeListening()
    // If no TTS happens, the onStatus callback will trigger restart
  }

  /// Start listening for voice commands (legacy method for compatibility)
  Future<void> startListening({
    Function(String)? onResult,
    Duration? timeout,
    bool continuous = false,
  }) async {
    print('startListening called');

    // Don't start listening while speaking
    if (_isSpeaking) {
      print('Cannot listen while speaking');
      return;
    }

    if (_isListening) {
      print('Already listening');
      return;
    }

    // If continuous mode is requested, use hands-free mode
    if (continuous || _continuousListeningEnabled) {
      await startHandsFreeListening(onResult: onResult);
      return;
    }

    await _startSingleListening(onResult: onResult, timeout: timeout);
  }

  /// Start a single listening session (non-continuous)
  Future<void> _startSingleListening({
    Function(String)? onResult,
    Duration? timeout,
  }) async {
    if (!_isSpeechInitialized) {
      print('Speech not initialized, attempting initialization...');
      final initialized = await initializeSpeech();
      if (!initialized) {
        print('Cannot start listening: speech recognition not available');
        throw Exception('Speech recognition not available. Please check permissions.');
      }
    }

    try {
      _isListening = true;
      print('🎤 Started single listening session...');

      await _speech.listen(
        onResult: (result) {
          final recognizedText = result.recognizedWords.toLowerCase().trim();

          // Show partial results for UI feedback
          onRecognizedText?.call(recognizedText);

          // Only process final results
          if (!result.finalResult) return;
          if (recognizedText.isEmpty) return;

          print('Recognized: $recognizedText');
          onResult?.call(recognizedText);

          // Parse voice command
          final command = _parseVoiceCommand(recognizedText);
          if (command != VoiceCommand.unknown) {
            if (_shouldProcessCommand(command.toString())) {
              print('Processing command: $command');
              onVoiceCommand?.call(command);
            }
          }
        },
        listenFor: timeout ?? const Duration(seconds: 10),
        pauseFor: const Duration(seconds: 2),
        listenOptions: stt.SpeechListenOptions(
          cancelOnError: false,
          listenMode: stt.ListenMode.dictation,
        ),
        onSoundLevelChange: (level) {
          final normalized = ((level + 2) / 12).clamp(0.0, 1.0);
          onAudioLevelChange?.call(normalized);
        },
      );
    } catch (e, stackTrace) {
      print('Error starting listening: $e');
      print('Stack trace: $stackTrace');
      _isListening = false;
      rethrow;
    }
  }

  /// Stop listening for voice commands
  Future<void> stopListening() async {
    _silenceTimer?.cancel();
    _restartListeningTimer?.cancel();

    if (!_isListening && !_handsFreeModeActive) return;

    try {
      await _speech.stop();
      _isListening = false;
      print('Stopped listening');
    } catch (e) {
      print('Error stopping listening: $e');
      _isListening = false;
    }
  }

  /// Parse recognized text into voice command
  VoiceCommand _parseVoiceCommand(String text) {
    final lowerText = text.toLowerCase().trim();

    // Complete/Finish (check first to avoid conflict with other commands)
    if (lowerText.contains('complete') ||
        lowerText.contains('finish') ||
        lowerText.contains('done cooking') ||
        lowerText.contains('all done')) {
      return VoiceCommand.complete;
    }

    // Start command - to begin reading step 1
    if (lowerText == 'start' ||
        lowerText.contains('let\'s start') ||
        lowerText.contains('begin') ||
        lowerText.contains('start cooking')) {
      return VoiceCommand.start;
    }

    // Next step
    if (lowerText.contains('next') ||
        lowerText.contains('go on')) {
      return VoiceCommand.next;
    }

    // Repeat step
    if (lowerText.contains('repeat') ||
        lowerText.contains('again') ||
        lowerText.contains('say that again')) {
      return VoiceCommand.repeat;
    }

    // Previous step
    if (lowerText.contains('back') ||
        lowerText.contains('previous') ||
        lowerText.contains('go back')) {
      return VoiceCommand.back;
    }

    // Pause
    if (lowerText.contains('pause') ||
        lowerText.contains('wait')) {
      return VoiceCommand.pause;
    }

    // Resume/Continue
    if (lowerText.contains('resume') ||
        lowerText.contains('continue')) {
      return VoiceCommand.resume;
    }

    // Help
    if (lowerText.contains('help') ||
        lowerText.contains('hey chef') ||
        lowerText.contains('question')) {
      return VoiceCommand.help;
    }

    // Stop listening
    if (lowerText.contains('stop listening') || lowerText.contains('cancel')) {
      return VoiceCommand.stopListening;
    }

    // Exit gracefully
    if (lowerText.contains('exit') ||
        lowerText.contains('leave') ||
        lowerText.contains('goodbye') ||
        lowerText.contains('bye')) {
      return VoiceCommand.exit;
    }

    return VoiceCommand.unknown;
  }

  /// Detect timer duration from step text
  Duration? detectTimerInText(String text) {
    final lowerText = text.toLowerCase();

    // Regex patterns for time detection
    final patterns = [
      RegExp(r'(\d+)\s*(?:to\s*\d+\s*)?(?:minute|min)s?', caseSensitive: false),
      RegExp(r'(\d+)\s*(?:to\s*\d+\s*)?(?:hour|hr)s?', caseSensitive: false),
      RegExp(r'(\d+)\s*(?:to\s*\d+\s*)?(?:second|sec)s?', caseSensitive: false),
    ];

    for (final pattern in patterns) {
      final match = pattern.firstMatch(lowerText);
      if (match != null) {
        final value = int.tryParse(match.group(1) ?? '0') ?? 0;

        if (lowerText.contains('hour') || lowerText.contains('hr')) {
          return Duration(hours: value);
        } else if (lowerText.contains('second') || lowerText.contains('sec')) {
          return Duration(seconds: value);
        } else {
          return Duration(minutes: value);
        }
      }
    }

    return null;
  }

  /// Extract timer description from step text
  String extractTimerDescription(String text, Duration duration) {
    final minutes = duration.inMinutes;
    final hours = duration.inHours;
    final seconds = duration.inSeconds % 60;

    String timeStr;
    if (hours > 0) {
      timeStr = '$hours hour${hours > 1 ? 's' : ''}';
    } else if (minutes > 0) {
      timeStr = '$minutes minute${minutes > 1 ? 's' : ''}';
    } else {
      timeStr = '$seconds second${seconds > 1 ? 's' : ''}';
    }

    // Try to extract what should be timed
    final lowerText = text.toLowerCase();
    if (lowerText.contains('simmer')) return 'Simmer for $timeStr';
    if (lowerText.contains('bake')) return 'Bake for $timeStr';
    if (lowerText.contains('cook')) return 'Cook for $timeStr';
    if (lowerText.contains('boil')) return 'Boil for $timeStr';
    if (lowerText.contains('rest')) return 'Rest for $timeStr';
    if (lowerText.contains('chill')) return 'Chill for $timeStr';
    if (lowerText.contains('marinate')) return 'Marinate for $timeStr';

    return 'Timer: $timeStr';
  }

  /// Create and start a timer stream
  Stream<Duration> createTimer(StepTimer timer) {
    final controller = StreamController<Duration>.broadcast();
    _timerControllers[timer.id] = controller;

    Timer.periodic(const Duration(seconds: 1), (t) {
      if (timer.status == TimerStatus.cancelled ||
          timer.status == TimerStatus.completed ||
          !_timerControllers.containsKey(timer.id)) {
        t.cancel();
        controller.close();
        _timerControllers.remove(timer.id);
        return;
      }

      if (timer.status == TimerStatus.running) {
        final remaining = timer.remaining;
        controller.add(remaining);

        if (remaining == Duration.zero) {
          timer.complete();
          controller.add(Duration.zero);
          print('⏰ Timer completed: ${timer.description}');
          speak('Timer finished for ${timer.description}');
        }
      }
    });

    return controller.stream;
  }

  /// Cancel a timer
  void cancelTimer(String timerId) {
    final controller = _timerControllers[timerId];
    if (controller != null) {
      controller.close();
      _timerControllers.remove(timerId);
      print('🛑 Timer cancelled: $timerId');
    }
  }

  /// Cancel all timers
  void cancelAllTimers() {
    for (final controller in _timerControllers.values) {
      controller.close();
    }
    _timerControllers.clear();
    print('🛑 All timers cancelled');
  }

  /// Check if currently listening
  bool get isListening => _isListening;

  /// Check if TTS is available
  bool get isTtsAvailable => _isTtsInitialized;

  /// Check if speech recognition is available
  bool get isSpeechAvailable => _isSpeechInitialized;

  /// Dispose resources
  void dispose() {
    _tts.stop();
    _speech.stop();
    _silenceTimer?.cancel();
    _restartListeningTimer?.cancel();
    _ttsAudioLevelTimer?.cancel();
    cancelAllTimers();
    _handsFreeModeActive = false;
  }
}

/// Global singleton instance
final cookAlongService = CookAlongService();
