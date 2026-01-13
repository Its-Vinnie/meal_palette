import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

/// Service for ElevenLabs premium text-to-speech
class ElevenLabsService {
  // Use the same Claude API key for now - in production, get a separate ElevenLabs key
  static const String _apiKey ='sk_7eb9ae36c68d4805c0d5ff402103128323cc7a8d35c1d209';
  static const String _apiUrl = 'https://api.elevenlabs.io/v1';

  /// Get available premium voices
  Future<List<PremiumVoice>> getAvailableVoices() async {
    try {
      // Return predefined premium voices (ElevenLabs voice IDs)
      return [
        PremiumVoice(
          id: '21m00Tcm4TlvDq8ikWAM',
          name: 'Rachel',
          gender: 'Female',
          description: 'Warm and friendly, great for cooking instructions',
          accent: 'American',
          isPremium: true,
        ),
        PremiumVoice(
          id: 'AZnzlk1XvdvUeBnXmlld',
          name: 'Domi',
          gender: 'Female',
          description: 'Professional and clear, excellent for recipes',
          accent: 'American',
          isPremium: true,
        ),
        PremiumVoice(
          id: 'EXAVITQu4vr4xnSDxMaL',
          name: 'Bella',
          gender: 'Female',
          description: 'Energetic and upbeat, makes cooking fun',
          accent: 'American',
          isPremium: true,
        ),
        PremiumVoice(
          id: 'ErXwobaYiN019PkySvjV',
          name: 'Antoni',
          gender: 'Male',
          description: 'Deep and reassuring, professional chef voice',
          accent: 'American',
          isPremium: true,
        ),
        PremiumVoice(
          id: 'VR6AewLTigWG4xSOukaG',
          name: 'Arnold',
          gender: 'Male',
          description: 'Strong and confident, motivational',
          accent: 'American',
          isPremium: true,
        ),
        PremiumVoice(
          id: 'pNInz6obpgDQGcFmaJgB',
          name: 'Adam',
          gender: 'Male',
          description: 'Natural and conversational, friendly chef',
          accent: 'American',
          isPremium: true,
        ),
        PremiumVoice(
          id: 'yoZ06aMxZJJ28mfd3POQ',
          name: 'Sam',
          gender: 'Male',
          description: 'Calm and clear, easy to follow',
          accent: 'American',
          isPremium: true,
        ),
        PremiumVoice(
          id: 'ThT5KcBeYPX3keUQqHPh',
          name: 'Emily',
          gender: 'Female',
          description: 'Soothing and gentle, patient instructor',
          accent: 'British',
          isPremium: true,
        ),
      ];
    } catch (e) {
      print('❌ Error fetching ElevenLabs voices: $e');
      return [];
    }
  }

  /// Convert text to speech using ElevenLabs API
  /// Returns the path to the generated audio file
  Future<String?> textToSpeech({
    required String text,
    required String voiceId,
    double stability = 0.5,
    double similarityBoost = 0.75,
  }) async {
    try {
      print('🎙️ Generating speech with ElevenLabs...');

      final url = '$_apiUrl/text-to-speech/$voiceId';

      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'xi-api-key': _apiKey,
        },
        body: jsonEncode({
          'text': text,
          'model_id': 'eleven_monolingual_v1',
          'voice_settings': {
            'stability': stability,
            'similarity_boost': similarityBoost,
          },
        }),
      );

      if (response.statusCode == 200) {
        // Save audio file
        final directory = await getTemporaryDirectory();
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final filePath = '${directory.path}/elevenlabs_$timestamp.mp3';

        final file = File(filePath);
        await file.writeAsBytes(response.bodyBytes);

        print('✅ Audio generated and saved to: $filePath');
        return filePath;
      } else {
        print('❌ ElevenLabs API error: ${response.statusCode}');
        print('Response: ${response.body}');
        return null;
      }
    } catch (e) {
      print('❌ Error generating speech: $e');
      return null;
    }
  }

  /// Preview a voice by speaking sample text
  Future<String?> previewVoice(PremiumVoice voice) async {
    const sampleText = '''Welcome to Cook Along Mode! Let's prepare something delicious together.
I'll guide you through each step, and you can ask me questions anytime.''';

    return await textToSpeech(
      text: sampleText,
      voiceId: voice.id,
    );
  }
}

/// Model for premium voice
class PremiumVoice {
  final String id;
  final String name;
  final String gender;
  final String description;
  final String accent;
  final bool isPremium;

  const PremiumVoice({
    required this.id,
    required this.name,
    required this.gender,
    required this.description,
    required this.accent,
    this.isPremium = false,
  });

  String get displayName => '$name ($accent)';
}

/// Global singleton instance
final elevenLabsService = ElevenLabsService();
