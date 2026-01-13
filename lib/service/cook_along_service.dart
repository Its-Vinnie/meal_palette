import 'dart:async';
import 'dart:io';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:permission_handler/permission_handler.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:meal_palette/model/cook_along_session.dart';
import 'package:meal_palette/model/voice_settings_model.dart';
import 'package:meal_palette/service/claude_conversation_service.dart';
import 'package:meal_palette/service/elevenlabs_service.dart';
import 'package:meal_palette/service/whisper_service.dart';

/// Service for managing Cook Along Mode functionality
/// Handles Text-to-Speech, Speech-to-Text (via Whisper), and timer management
class CookAlongService {
  final FlutterTts _tts = FlutterTts();
  final stt.SpeechToText _speech = stt.SpeechToText();
  final ClaudeConversationService _claudeService = ClaudeConversationService();
  final AudioPlayer _audioPlayer = AudioPlayer();
  final WhisperService _whisperService = whisperService;
  final AudioRecorder _audioRecorder = AudioRecorder();

  bool _isTtsInitialized = false;
  bool _isSpeechInitialized = false;
  bool _isListening = false;
  bool _isSpeaking = false;
  bool _useNaturalVoice = true; // Enable Claude-enhanced natural speech by default
  bool _continuousListeningEnabled = false;
  bool _useWhisper = true; // Use Whisper API for better accuracy
  String? _currentRecordingPath;

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

  // Timer streams
  final Map<String, StreamController<Duration>> _timerControllers = {};

  // Cache for natural speech conversions
  final Map<String, String> _naturalSpeechCache = {};

  // Getters
  bool get isSpeaking => _isSpeaking;
  bool get continuousListeningEnabled => _continuousListeningEnabled;
  bool get useWhisper => _useWhisper;

  /// Enable or disable Whisper (OpenAI) for speech recognition
  /// Whisper provides better accuracy but requires API calls
  void setUseWhisper(bool value) {
    _useWhisper = value;
    print('Whisper speech recognition: ${value ? 'enabled' : 'disabled'}');
  }

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
        _isSpeaking = false;
        onTtsComplete?.call();
        onSpeakingDone?.call();

        // Auto-restart listening in continuous mode
        if (_continuousListeningEnabled && !_isListening) {
          Future.delayed(const Duration(milliseconds: 300), () {
            if (_continuousListeningEnabled && !_isListening) {
              _startContinuousListening();
            }
          });
        }
      });

      // Set start handler
      _tts.setStartHandler(() {
        print('🔊 TTS started speaking');
        _isSpeaking = true;
      });

      // Set error handler
      _tts.setErrorHandler((msg) {
        print('❌ TTS error: $msg');
        _isSpeaking = false;
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
      },
      onStatus: (status) {
        print('🎤 Speech status: $status');
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

  /// Enable continuous listening mode (like a real conversation)
  void enableContinuousListening(bool enable) {
    _continuousListeningEnabled = enable;
    print('🎤 Continuous listening: ${enable ? 'enabled' : 'disabled'}');

    if (enable && !_isListening && !_isSpeaking) {
      _startContinuousListening();
    } else if (!enable) {
      stopListening();
    }
  }

  /// Start continuous listening (internal)
  Future<void> _startContinuousListening() async {
    if (_isListening || _isSpeaking) return;

    try {
      await startListening(
        timeout: const Duration(seconds: 30),
        continuous: true,
      );
    } catch (e) {
      print('❌ Error starting continuous listening: $e');
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

  /// Start listening for voice commands
  /// Uses Whisper API when _useWhisper is true for better accuracy
  Future<void> startListening({
    Function(String)? onResult,
    Duration? timeout,
    bool continuous = false,
  }) async {
    print('startListening called, useWhisper: $_useWhisper');

    // Don't start listening while speaking
    if (_isSpeaking) {
      print('Cannot listen while speaking');
      return;
    }

    if (_isListening) {
      print('Already listening');
      return;
    }

    // Use Whisper API for better accuracy if enabled and configured
    if (_useWhisper && WhisperService.isConfigured) {
      await _startWhisperListening(onResult: onResult, timeout: timeout, continuous: continuous);
    } else {
      await _startNativeListening(onResult: onResult, timeout: timeout, continuous: continuous);
    }
  }

  /// Start listening using OpenAI Whisper API (better accuracy)
  Future<void> _startWhisperListening({
    Function(String)? onResult,
    Duration? timeout,
    bool continuous = false,
  }) async {
    try {
      // Check if recorder is available
      if (!await _audioRecorder.hasPermission()) {
        print('Microphone permission not granted');
        throw Exception('Microphone permission required');
      }

      _isListening = true;
      print('Started Whisper listening...');

      // Get temp directory for recording
      final tempDir = await getTemporaryDirectory();
      _currentRecordingPath = '${tempDir.path}/whisper_recording_${DateTime.now().millisecondsSinceEpoch}.m4a';

      // Start recording
      await _audioRecorder.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc,
          bitRate: 128000,
          sampleRate: 44100,
        ),
        path: _currentRecordingPath!,
      );

      print('Recording started at: $_currentRecordingPath');

      // Auto-stop after timeout
      final listenDuration = timeout ?? const Duration(seconds: 10);
      Future.delayed(listenDuration, () async {
        if (_isListening && _currentRecordingPath != null) {
          await _stopWhisperRecordingAndTranscribe(onResult: onResult, continuous: continuous);
        }
      });
    } catch (e, stackTrace) {
      print('Error starting Whisper listening: $e');
      print('Stack trace: $stackTrace');
      _isListening = false;
      rethrow;
    }
  }

  /// Stop Whisper recording and transcribe
  Future<void> _stopWhisperRecordingAndTranscribe({
    Function(String)? onResult,
    bool continuous = false,
  }) async {
    if (!_isListening || _currentRecordingPath == null) return;

    try {
      // Stop recording
      final path = await _audioRecorder.stop();
      print('Recording stopped at: $path');

      if (path == null) {
        print('No recording path returned');
        _isListening = false;
        return;
      }

      // Check if file exists and has content
      final file = File(path);
      if (!await file.exists()) {
        print('Recording file does not exist');
        _isListening = false;
        return;
      }

      final fileSize = await file.length();
      if (fileSize < 1000) {
        print('Recording too short (${fileSize} bytes)');
        _isListening = false;
        return;
      }

      print('Transcribing ${fileSize} bytes with Whisper...');

      // Transcribe with Whisper
      final transcription = await _whisperService.transcribe(path, language: 'en');
      final recognizedText = transcription.toLowerCase().trim();

      // Clean up recording file
      try {
        await file.delete();
      } catch (e) {
        print('Could not delete recording file: $e');
      }

      _isListening = false;
      _currentRecordingPath = null;

      if (recognizedText.isEmpty) {
        print('Empty transcription');
        return;
      }

      print('Whisper transcribed: $recognizedText');
      onRecognizedText?.call(recognizedText);
      onResult?.call(recognizedText);

      // Parse voice command
      final command = _parseVoiceCommand(recognizedText);
      if (command != VoiceCommand.unknown) {
        if (_shouldProcessCommand(command.toString())) {
          print('Processing command: $command');
          onVoiceCommand?.call(command);
        }
      }

      // Restart listening in continuous mode
      if (continuous && _continuousListeningEnabled && !_isSpeaking) {
        Future.delayed(const Duration(milliseconds: 500), () {
          if (_continuousListeningEnabled && !_isListening && !_isSpeaking) {
            _startContinuousListening();
          }
        });
      }
    } catch (e, stackTrace) {
      print('Error in Whisper transcription: $e');
      print('Stack trace: $stackTrace');
      _isListening = false;
      _currentRecordingPath = null;
    }
  }

  /// Start listening using native speech-to-text (fallback)
  Future<void> _startNativeListening({
    Function(String)? onResult,
    Duration? timeout,
    bool continuous = false,
  }) async {
    if (!_isSpeechInitialized) {
      print('Speech not initialized, attempting initialization...');
      final initialized = await initializeSpeech();
      if (!initialized) {
        print('Cannot start listening: speech recognition not available');
        throw Exception('Speech recognition not available. Please check permissions.');
      }
    }

    // Double-check speech recognition is actually available
    final available = await _speech.initialize();
    if (!available) {
      print('Speech recognition not available on this device');
      throw Exception('Speech recognition not available on this device');
    }

    try {
      _isListening = true;
      print('Started native listening (continuous: $continuous)...');

      await _speech.listen(
        onResult: (result) {
          final recognizedText = result.recognizedWords.toLowerCase().trim();

          // Only process final results to avoid duplicates
          if (!result.finalResult) {
            // Still show partial results for UI feedback
            onRecognizedText?.call(recognizedText);
            return;
          }

          if (recognizedText.isEmpty) return;

          print('Native recognized: $recognizedText');
          onRecognizedText?.call(recognizedText);
          onResult?.call(recognizedText);

          // Parse voice command
          final command = _parseVoiceCommand(recognizedText);
          if (command != VoiceCommand.unknown) {
            // Debounce duplicate commands
            if (_shouldProcessCommand(command.toString())) {
              print('Processing command: $command');
              onVoiceCommand?.call(command);
            }

            // Stop listening, AI will respond and then restart listening
            stopListening();
          }
        },
        listenFor: timeout ?? const Duration(seconds: 10),
        pauseFor: const Duration(seconds: 3),
        listenOptions: stt.SpeechListenOptions(
          cancelOnError: false,
          listenMode: stt.ListenMode.dictation,
        ),
        onSoundLevelChange: (level) {
          // Can be used for voice wave animation
        },
      );
    } catch (e, stackTrace) {
      print('Error starting native listening: $e');
      print('Stack trace: $stackTrace');
      _isListening = false;

      // Retry in continuous mode
      if (continuous && _continuousListeningEnabled) {
        Future.delayed(const Duration(seconds: 1), () {
          if (_continuousListeningEnabled && !_isListening && !_isSpeaking) {
            _startContinuousListening();
          }
        });
      } else {
        rethrow;
      }
    }
  }

  /// Stop listening for voice commands
  Future<void> stopListening() async {
    if (!_isListening) return;

    try {
      if (_useWhisper && _currentRecordingPath != null) {
        // Stop Whisper recording and transcribe
        await _stopWhisperRecordingAndTranscribe();
      } else {
        // Stop native speech recognition
        await _speech.stop();
        _isListening = false;
      }
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
    cancelAllTimers();
  }
}

/// Global singleton instance
final cookAlongService = CookAlongService();
