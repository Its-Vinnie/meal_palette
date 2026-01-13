import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

/// Service for OpenAI Whisper speech-to-text
/// Provides more accurate speech recognition than native implementations
class WhisperService {
  // OpenAI API configuration
  static const String _apiUrl = 'https://api.openai.com/v1/audio/transcriptions';

  // Configurable API key - set this before using the service
  static String _apiKey = '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';

  /// Set the OpenAI API key for Whisper
  /// Call this during app initialization with your API key
  static void setApiKey(String apiKey) {
    _apiKey = apiKey;
    print('Whisper API key configured');
  }

  /// Get the current API key (masked for security)
  static String get maskedApiKey {
    if (_apiKey.isEmpty) return 'Not set';
    if (_apiKey.length < 8) return '****';
    return '${_apiKey.substring(0, 4)}...${_apiKey.substring(_apiKey.length - 4)}';
  }

  /// Transcribe audio file to text using OpenAI Whisper
  /// [audioPath] - Path to the audio file (supports mp3, mp4, mpeg, mpga, m4a, wav, webm)
  /// [language] - Optional language code (e.g., 'en' for English) for better accuracy
  Future<String> transcribe(String audioPath, {String? language}) async {
    try {
      final file = File(audioPath);
      if (!await file.exists()) {
        throw Exception('Audio file not found: $audioPath');
      }

      // Create multipart request
      final request = http.MultipartRequest('POST', Uri.parse(_apiUrl));

      // Add headers
      request.headers['Authorization'] = 'Bearer $_apiKey';

      // Add file
      request.files.add(await http.MultipartFile.fromPath(
        'file',
        audioPath,
      ));

      // Add model
      request.fields['model'] = 'whisper-1';

      // Add language if specified (improves accuracy)
      if (language != null) {
        request.fields['language'] = language;
      }

      // Add response format
      request.fields['response_format'] = 'json';

      print('Sending audio to Whisper API...');

      // Send request
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final text = data['text'] as String;
        print('Whisper transcription: $text');
        return text.trim();
      } else {
        print('Whisper API error: ${response.statusCode} - ${response.body}');
        throw Exception('Whisper transcription failed: ${response.statusCode}');
      }
    } catch (e) {
      print('Error in Whisper transcription: $e');
      rethrow;
    }
  }

  /// Transcribe audio bytes to text
  /// Useful when recording audio in memory
  Future<String> transcribeBytes(List<int> audioBytes, {
    String filename = 'audio.wav',
    String? language,
  }) async {
    try {
      // Save bytes to temporary file
      final tempDir = await getTemporaryDirectory();
      final tempFile = File('${tempDir.path}/$filename');
      await tempFile.writeAsBytes(audioBytes);

      // Transcribe
      final result = await transcribe(tempFile.path, language: language);

      // Clean up temp file
      await tempFile.delete();

      return result;
    } catch (e) {
      print('Error transcribing bytes: $e');
      rethrow;
    }
  }

  /// Check if the API key is configured
  static bool get isConfigured => _apiKey.isNotEmpty;

  /// Validate API key by making a test request
  Future<bool> validateApiKey() async {
    try {
      // Create a minimal test request to check API key validity
      final response = await http.get(
        Uri.parse('https://api.openai.com/v1/models'),
        headers: {
          'Authorization': 'Bearer $_apiKey',
        },
      );
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }
}

/// Global singleton instance
final whisperService = WhisperService();
