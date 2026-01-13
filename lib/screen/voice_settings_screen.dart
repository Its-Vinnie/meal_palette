import 'package:flutter/material.dart';
import 'package:meal_palette/model/voice_settings_model.dart';
import 'package:meal_palette/service/cook_along_service.dart';
import 'package:meal_palette/service/user_profile_service.dart';
import 'package:meal_palette/service/auth_service.dart';
import 'package:meal_palette/service/elevenlabs_service.dart';
import 'package:meal_palette/theme/theme_design.dart';
import 'package:audioplayers/audioplayers.dart';

/// Screen for selecting and configuring TTS voice settings
class VoiceSettingsScreen extends StatefulWidget {
  final VoiceSettings? initialSettings;

  const VoiceSettingsScreen({
    super.key,
    this.initialSettings,
  });

  @override
  State<VoiceSettingsScreen> createState() => _VoiceSettingsScreenState();
}

class _VoiceSettingsScreenState extends State<VoiceSettingsScreen> {
  List<AvailableVoice> _voices = [];
  List<PremiumVoice> _premiumVoices = [];
  AvailableVoice? _selectedVoice;
  PremiumVoice? _selectedPremiumVoice;
  bool _isPremiumMode = false;
  bool _isLoading = true;
  bool _isSaving = false;
  final AudioPlayer _audioPlayer = AudioPlayer();

  double _speechRate = 0.5;
  double _pitch = 1.0;
  double _volume = 1.0;

  @override
  void initState() {
    super.initState();
    _initializeSettings();
    _loadVoices();
    _loadPremiumVoices();
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    // Stop any playing voice preview
    cookAlongService.stopSpeaking();
    super.dispose();
  }

  void _initializeSettings() {
    final settings = widget.initialSettings ?? VoiceSettings.defaultSettings;
    _speechRate = settings.speechRate;
    _pitch = settings.pitch;
    _volume = settings.volume;
    _isPremiumMode = settings.isPremium;
  }

  Future<void> _loadVoices() async {
    try {
      setState(() => _isLoading = true);

      final voices = await cookAlongService.getAvailableVoices();

      // Try to find current voice if settings provided
      if (widget.initialSettings != null &&
          widget.initialSettings!.voiceName.isNotEmpty) {
        _selectedVoice = voices.firstWhere(
          (v) => v.name == widget.initialSettings!.voiceName,
          orElse: () => voices.isNotEmpty ? voices.first : _createDefaultVoice(),
        );
      } else if (voices.isNotEmpty) {
        _selectedVoice = voices.first;
      }

      setState(() {
        _voices = voices;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading voices: $e');
      setState(() => _isLoading = false);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load voices: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _loadPremiumVoices() async {
    try {
      final voices = await elevenLabsService.getAvailableVoices();

      // Try to find current premium voice if settings provided
      if (widget.initialSettings != null &&
          widget.initialSettings!.isPremium &&
          widget.initialSettings!.voiceId != null) {
        _selectedPremiumVoice = voices.firstWhere(
          (v) => v.id == widget.initialSettings!.voiceId,
          orElse: () => voices.first,
        );
      }

      setState(() {
        _premiumVoices = voices;
      });
    } catch (e) {
      print('Error loading premium voices: $e');
    }
  }

  AvailableVoice _createDefaultVoice() {
    return const AvailableVoice(
      name: '',
      locale: 'en-US',
      isDefault: true,
    );
  }

  Future<void> _previewVoice(AvailableVoice voice) async {
    await cookAlongService.previewVoice(voice);
  }

  Future<void> _previewPremiumVoice(PremiumVoice voice) async {
    try {
      // Stop any currently playing audio
      await _audioPlayer.stop();

      final audioPath = await elevenLabsService.previewVoice(voice);
      if (audioPath != null) {
        await _audioPlayer.play(DeviceFileSource(audioPath));
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to preview voice'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      print('Error previewing premium voice: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _saveSettings() async {
    if (!_isPremiumMode && _selectedVoice == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a voice')),
      );
      return;
    }

    if (_isPremiumMode && _selectedPremiumVoice == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a premium voice')),
      );
      return;
    }

    try {
      setState(() => _isSaving = true);

      final settings = _isPremiumMode
          ? VoiceSettings(
              voiceName: _selectedPremiumVoice!.name,
              locale: 'en-US',
              speechRate: _speechRate,
              pitch: _pitch,
              volume: _volume,
              isPremium: true,
              voiceId: _selectedPremiumVoice!.id,
            )
          : VoiceSettings(
              voiceName: _selectedVoice!.name,
              locale: _selectedVoice!.locale,
              speechRate: _speechRate,
              pitch: _pitch,
              volume: _volume,
              isPremium: false,
            );

      // Update cook along service
      await cookAlongService.updateVoiceSettings(settings);

      // Save to user profile
      final userId = authService.currentUser?.uid;
      if (userId != null) {
        await userProfileService.updateVoiceSettings(userId, settings);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Voice settings saved successfully!'),
            backgroundColor: Colors.green,
          ),
        );

        Navigator.pop(context, settings);
      }
    } catch (e) {
      print('Error saving settings: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save settings: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        title: const Text(
          'Voice Settings',
          style: TextStyle(color: AppColors.textPrimary),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (!_isLoading && !_isSaving)
            TextButton(
              onPressed: _saveSettings,
              child: const Text(
                'Save',
                style: TextStyle(
                  color: AppColors.primaryAccent,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          if (_isSaving)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.primaryAccent,
                ),
              ),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primaryAccent),
            )
          : _voices.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.voice_over_off,
                        size: 64,
                        color: AppColors.textSecondary,
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      Text(
                        'No voices available',
                        style: AppTextStyles.recipeTitle.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        'Your device doesn\'t support text-to-speech',
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                )
              : SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Voice type toggle
                        Container(
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(AppRadius.md),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: _buildToggleButton(
                                  'Device Voices',
                                  !_isPremiumMode,
                                  () => setState(() {
                                    _isPremiumMode = false;
                                    _selectedPremiumVoice = null;
                                  }),
                                ),
                              ),
                              Expanded(
                                child: _buildToggleButton(
                                  'Premium Voices',
                                  _isPremiumMode,
                                  () => setState(() {
                                    _isPremiumMode = true;
                                    _selectedVoice = null;
                                  }),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xl),

                        Text(
                          _isPremiumMode ? 'Premium AI Voices' : 'Device Voices',
                          style: AppTextStyles.recipeTitle.copyWith(
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          _isPremiumMode
                              ? 'High-quality AI voices powered by Claude. Perfect for natural-sounding cooking instructions.'
                              : 'Standard voices from your device. Works offline.',
                          style: AppTextStyles.bodyMedium.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.lg),

                        // Show appropriate voices
                        if (_isPremiumMode)
                          ..._premiumVoices.map((voice) => _buildPremiumVoiceCard(voice))
                        else
                          ..._voices.map((voice) => _buildVoiceCard(voice)),

                        const SizedBox(height: AppSpacing.xl),
                        _buildSettingsSection(),
                      ],
                    ),
                  ),
                ),
    );
  }

  Widget _buildVoiceCard(AvailableVoice voice) {
    final isSelected = _selectedVoice?.name == voice.name;

    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      color: isSelected ? AppColors.primaryAccent.withValues(alpha: 0.1) : AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        side: BorderSide(
          color: isSelected ? AppColors.primaryAccent : Colors.transparent,
          width: 2,
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.sm,
        ),
        title: Text(
          voice.displayName,
          style: AppTextStyles.bodyLarge.copyWith(
            color: AppColors.textPrimary,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        subtitle: Text(
          '${voice.gender} • ${voice.locale}',
          style: AppTextStyles.labelMedium.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: isSelected
                ? AppColors.primaryAccent.withValues(alpha: 0.2)
                : AppColors.background,
            shape: BoxShape.circle,
          ),
          child: Icon(
            voice.gender == 'Female'
                ? Icons.face_3
                : voice.gender == 'Male'
                    ? Icons.face
                    : Icons.record_voice_over,
            color: isSelected ? AppColors.primaryAccent : AppColors.textSecondary,
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.play_circle_outline),
              color: AppColors.primaryAccent,
              onPressed: () => _previewVoice(voice),
              tooltip: 'Preview voice',
            ),
            if (isSelected)
              const Icon(
                Icons.check_circle,
                color: AppColors.primaryAccent,
              ),
          ],
        ),
        onTap: () {
          setState(() {
            _selectedVoice = voice;
          });
        },
      ),
    );
  }

  Widget _buildSettingsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Voice Controls',
          style: AppTextStyles.recipeTitle.copyWith(
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        _buildSlider(
          label: 'Speech Rate',
          value: _speechRate,
          min: 0.0,
          max: 1.0,
          divisions: 10,
          onChanged: (value) => setState(() => _speechRate = value),
          valueLabel: '${(_speechRate * 100).round()}%',
        ),
        const SizedBox(height: AppSpacing.lg),
        _buildSlider(
          label: 'Pitch',
          value: _pitch,
          min: 0.5,
          max: 2.0,
          divisions: 15,
          onChanged: (value) => setState(() => _pitch = value),
          valueLabel: _pitch.toStringAsFixed(1),
        ),
        const SizedBox(height: AppSpacing.lg),
        _buildSlider(
          label: 'Volume',
          value: _volume,
          min: 0.0,
          max: 1.0,
          divisions: 10,
          onChanged: (value) => setState(() => _volume = value),
          valueLabel: '${(_volume * 100).round()}%',
        ),
        const SizedBox(height: AppSpacing.xl),
        if (_selectedVoice != null)
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isPremiumMode && _selectedPremiumVoice != null
                  ? () => _previewPremiumVoice(_selectedPremiumVoice!)
                  : _selectedVoice != null
                      ? () => _previewVoice(_selectedVoice!)
                      : null,
              icon: const Icon(Icons.play_arrow),
              label: const Text('Preview with Current Settings'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryAccent,
                foregroundColor: AppColors.surface,
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildToggleButton(String label, bool isActive, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.md,
        ),
        decoration: BoxDecoration(
          color: isActive ? AppColors.primaryAccent : Colors.transparent,
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Text(
          label,
          style: AppTextStyles.bodyMedium.copyWith(
            color: isActive ? AppColors.surface : AppColors.textSecondary,
            fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  Widget _buildPremiumVoiceCard(PremiumVoice voice) {
    final isSelected = _selectedPremiumVoice?.id == voice.id;

    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      color: isSelected
          ? AppColors.primaryAccent.withValues(alpha: 0.1)
          : AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        side: BorderSide(
          color: isSelected ? AppColors.primaryAccent : Colors.transparent,
          width: 2,
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.sm,
        ),
        title: Row(
          children: [
            Text(
              voice.name,
              style: AppTextStyles.bodyLarge.copyWith(
                color: AppColors.textPrimary,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 8,
                vertical: 2,
              ),
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: Colors.amber, width: 1),
              ),
              child: Text(
                'PREMIUM',
                style: AppTextStyles.labelMedium.copyWith(
                  color: Colors.amber,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              '${voice.gender} • ${voice.accent}',
              style: AppTextStyles.labelMedium.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              voice.description,
              style: AppTextStyles.labelMedium.copyWith(
                color: AppColors.textTertiary,
                fontSize: 11,
              ),
            ),
          ],
        ),
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: isSelected
                ? AppColors.primaryAccent.withValues(alpha: 0.2)
                : AppColors.background,
            shape: BoxShape.circle,
          ),
          child: Icon(
            voice.gender == 'Female' ? Icons.face_3 : Icons.face,
            color: isSelected ? AppColors.primaryAccent : AppColors.textSecondary,
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.play_circle_outline),
              color: AppColors.primaryAccent,
              onPressed: () => _previewPremiumVoice(voice),
              tooltip: 'Preview voice',
            ),
            if (isSelected)
              const Icon(
                Icons.check_circle,
                color: AppColors.primaryAccent,
              ),
          ],
        ),
        onTap: () {
          setState(() {
            _selectedPremiumVoice = voice;
          });
        },
      ),
    );
  }

  Widget _buildSlider({
    required String label,
    required double value,
    required double min,
    required double max,
    required int divisions,
    required ValueChanged<double> onChanged,
    required String valueLabel,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: AppTextStyles.bodyLarge.copyWith(
                color: AppColors.textPrimary,
              ),
            ),
            Text(
              valueLabel,
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.primaryAccent,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        Slider(
          value: value,
          min: min,
          max: max,
          divisions: divisions,
          activeColor: AppColors.primaryAccent,
          inactiveColor: AppColors.textSecondary.withValues(alpha: 0.3),
          onChanged: onChanged,
        ),
      ],
    );
  }
}
