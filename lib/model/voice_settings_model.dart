/// Model for TTS voice settings
class VoiceSettings {
  final String voiceName;
  final String locale;
  final double speechRate;
  final double pitch;
  final double volume;
  final bool isPremium;
  final String? voiceId; // For premium voices (ElevenLabs ID)

  const VoiceSettings({
    required this.voiceName,
    required this.locale,
    this.speechRate = 0.5,
    this.pitch = 1.0,
    this.volume = 1.0,
    this.isPremium = false,
    this.voiceId,
  });

  /// Create from JSON
  factory VoiceSettings.fromJson(Map<String, dynamic> json) {
    return VoiceSettings(
      voiceName: json['voiceName'] as String? ?? '',
      locale: json['locale'] as String? ?? 'en-US',
      speechRate: (json['speechRate'] as num?)?.toDouble() ?? 0.5,
      pitch: (json['pitch'] as num?)?.toDouble() ?? 1.0,
      volume: (json['volume'] as num?)?.toDouble() ?? 1.0,
      isPremium: json['isPremium'] as bool? ?? false,
      voiceId: json['voiceId'] as String?,
    );
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'voiceName': voiceName,
      'locale': locale,
      'speechRate': speechRate,
      'pitch': pitch,
      'volume': volume,
      'isPremium': isPremium,
      if (voiceId != null) 'voiceId': voiceId,
    };
  }

  /// Create copy with modifications
  VoiceSettings copyWith({
    String? voiceName,
    String? locale,
    double? speechRate,
    double? pitch,
    double? volume,
    bool? isPremium,
    String? voiceId,
  }) {
    return VoiceSettings(
      voiceName: voiceName ?? this.voiceName,
      locale: locale ?? this.locale,
      speechRate: speechRate ?? this.speechRate,
      pitch: pitch ?? this.pitch,
      volume: volume ?? this.volume,
      isPremium: isPremium ?? this.isPremium,
      voiceId: voiceId ?? this.voiceId,
    );
  }

  /// Default settings
  static const VoiceSettings defaultSettings = VoiceSettings(
    voiceName: '',
    locale: 'en-US',
    speechRate: 0.5,
    pitch: 1.0,
    volume: 1.0,
  );
}

/// Model for available voice
class AvailableVoice {
  final String name;
  final String locale;
  final bool isDefault;

  const AvailableVoice({
    required this.name,
    required this.locale,
    this.isDefault = false,
  });

  /// Create from flutter_tts voice map
  factory AvailableVoice.fromMap(Map<String, dynamic> map) {
    return AvailableVoice(
      name: map['name'] as String? ?? '',
      locale: map['locale'] as String? ?? 'en-US',
      isDefault: false,
    );
  }

  /// Get display name (remove technical prefixes)
  String get displayName {
    // iOS voices often have format "com.apple.voice.compact.en-US.Samantha"
    // Android voices: "en-us-x-sfg#female_1-local"

    if (name.contains('Samantha')) return 'Samantha (Female, US)';
    if (name.contains('Daniel')) return 'Daniel (Male, UK)';
    if (name.contains('Karen')) return 'Karen (Female, AU)';
    if (name.contains('Moira')) return 'Moira (Female, IE)';
    if (name.contains('Tessa')) return 'Tessa (Female, ZA)';
    if (name.contains('Rishi')) return 'Rishi (Male, IN)';
    if (name.contains('Alex')) return 'Alex (Male, US)';
    if (name.contains('Fred')) return 'Fred (Male, US)';
    if (name.contains('Victoria')) return 'Victoria (Female, US)';

    // Extract name from path
    final parts = name.split('.');
    final lastPart = parts.last;

    // Remove technical suffixes
    final cleanName = lastPart
        .replaceAll('_local', '')
        .replaceAll('#female', '')
        .replaceAll('#male', '')
        .replaceAll('-', ' ');

    return cleanName;
  }

  /// Get voice gender from name (best guess)
  String get gender {
    final lower = name.toLowerCase();
    if (lower.contains('female')) return 'Female';
    if (lower.contains('male') && !lower.contains('female')) return 'Male';

    // Known female voices
    if (lower.contains('samantha') ||
        lower.contains('karen') ||
        lower.contains('moira') ||
        lower.contains('tessa') ||
        lower.contains('victoria') ||
        lower.contains('kate') ||
        lower.contains('zoe')) {
      return 'Female';
    }

    // Known male voices
    if (lower.contains('daniel') ||
        lower.contains('alex') ||
        lower.contains('fred') ||
        lower.contains('rishi') ||
        lower.contains('tom')) {
      return 'Male';
    }

    return 'Unknown';
  }

  @override
  String toString() => '$displayName ($locale)';
}
