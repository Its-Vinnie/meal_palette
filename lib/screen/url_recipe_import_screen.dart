import 'package:flutter/material.dart';
import 'package:meal_palette/model/detailed_recipe_model.dart';
import 'package:meal_palette/model/custom_recipe_model.dart';
import 'package:meal_palette/service/recipe_extraction_service.dart';
import 'package:meal_palette/service/auth_service.dart';
import 'package:meal_palette/state/custom_recipes_state.dart';
import 'package:meal_palette/theme/theme_design.dart';
import 'package:uuid/uuid.dart';

/// Screen for importing recipes from URLs (social media, websites, etc.)
class UrlRecipeImportScreen extends StatefulWidget {
  const UrlRecipeImportScreen({super.key});

  @override
  State<UrlRecipeImportScreen> createState() => _UrlRecipeImportScreenState();
}

class _UrlRecipeImportScreenState extends State<UrlRecipeImportScreen> {
  final TextEditingController _urlController = TextEditingController();
  final TextEditingController _textController = TextEditingController();
  final RecipeExtractionService _extractionService = recipeExtractionService;
  final CustomRecipesState _customRecipesState = customRecipesState;
  final AuthService _authService = authService;
  final _uuid = const Uuid();

  bool _isExtracting = false;
  bool _isSaving = false;
  RecipeDetail? _extractedRecipe;
  RecipePlatform? _detectedPlatform;
  String? _errorMessage;
  bool _showManualMode = false; // Toggle between auto and manual extraction

  @override
  void dispose() {
    _urlController.dispose();
    _textController.dispose();
    super.dispose();
  }

  /// Detect platform from URL
  void _detectPlatform(String url) {
    if (url.isEmpty) {
      setState(() => _detectedPlatform = null);
      return;
    }

    final platform = _extractionService.detectPlatform(url);
    setState(() => _detectedPlatform = platform);
  }

  /// Extract recipe automatically from URL only
  Future<void> _extractRecipeAuto() async {
    final url = _urlController.text.trim();

    // Validation
    if (url.isEmpty) {
      setState(() {
        _errorMessage = 'Please enter a URL';
      });
      return;
    }

    setState(() {
      _isExtracting = true;
      _errorMessage = null;
      _extractedRecipe = null;
    });

    try {
      // Auto-extract recipe from URL (AI fetches and parses)
      final recipe = await _extractionService.extractFromUrl(url);

      setState(() {
        _extractedRecipe = recipe;
        _isExtracting = false;
      });

      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Recipe extracted: ${recipe.title}'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Auto-extraction failed. Try manual mode or check the URL.';
        _isExtracting = false;
      });
      print('Auto extraction error: $e');
    }
  }

  /// Extract recipe from pasted text and URL (manual mode)
  Future<void> _extractRecipeManual() async {
    final url = _urlController.text.trim();
    final text = _textController.text.trim();

    // Validation
    if (url.isEmpty) {
      setState(() {
        _errorMessage = 'Please enter a URL';
      });
      return;
    }

    if (text.isEmpty) {
      setState(() {
        _errorMessage = 'Please paste the recipe text';
      });
      return;
    }

    setState(() {
      _isExtracting = true;
      _errorMessage = null;
      _extractedRecipe = null;
    });

    try {
      // Extract recipe using Claude AI with manual text
      final recipe = await _extractionService.extractFromUrlText(
        url: url,
        recipeText: text,
      );

      setState(() {
        _extractedRecipe = recipe;
        _isExtracting = false;
      });

      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Recipe extracted: ${recipe.title}'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to extract recipe: ${e.toString()}';
        _isExtracting = false;
      });
    }
  }

  /// Clear all fields and start over
  void _clearAll() {
    setState(() {
      _urlController.clear();
      _textController.clear();
      _extractedRecipe = null;
      _detectedPlatform = null;
      _errorMessage = null;
    });
  }

  /// Save the extracted recipe as a custom recipe
  Future<void> _saveRecipe() async {
    if (_extractedRecipe == null) return;

    final user = _authService.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You must be logged in to save recipes'),
          backgroundColor: AppColors.favorite,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      // Convert RecipeDetail to CustomRecipe
      final customRecipe = CustomRecipe.fromRecipeDetail(
        id: _uuid.v4(),
        userId: user.uid,
        recipe: _extractedRecipe!,
        source: 'url',
        sourceUrl: _urlController.text.trim(),
      );

      // Save to Firestore via state management
      final recipeId = await _customRecipesState.createRecipe(user.uid, customRecipe);

      if (recipeId != null && mounted) {
        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Recipe saved: ${_extractedRecipe!.title}'),
            backgroundColor: AppColors.success,
            duration: const Duration(seconds: 2),
          ),
        );

        // Clear form and show success
        _clearAll();

        // Navigate back or to My Recipes screen
        Navigator.pop(context);
      } else if (mounted) {
        throw Exception('Failed to save recipe');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save recipe: ${e.toString()}'),
            backgroundColor: AppColors.favorite,
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
          'Import Recipe from URL',
          style: TextStyle(color: AppColors.textPrimary),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (_extractedRecipe != null || _urlController.text.isNotEmpty || _textController.text.isNotEmpty)
            TextButton(
              onPressed: _clearAll,
              child: const Text(
                'Clear',
                style: TextStyle(color: AppColors.primaryAccent),
              ),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Instructions
            Container(
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: BoxDecoration(
                color: AppColors.primaryAccent.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.auto_awesome,
                            color: AppColors.primaryAccent,
                            size: 20,
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Text(
                            _showManualMode ? 'Manual Import' : 'Smart Import',
                            style: AppTextStyles.bodyLarge.copyWith(
                              fontWeight: FontWeight.bold,
                              color: AppColors.primaryAccent,
                            ),
                          ),
                        ],
                      ),
                      TextButton(
                        onPressed: () {
                          setState(() {
                            _showManualMode = !_showManualMode;
                            _errorMessage = null;
                          });
                        },
                        child: Text(
                          _showManualMode ? 'Use Auto Mode' : 'Use Manual Mode',
                          style: TextStyle(
                            color: AppColors.secondaryAccent,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    _showManualMode
                        ? '1. Paste the recipe URL\n'
                            '2. Paste the full recipe text\n'
                            '3. Tap Extract'
                        : '1. Paste any recipe URL\n'
                            '2. Tap Extract - AI will fetch and parse it automatically!\n'
                            '3. Missing info (servings, time) will be estimated',
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: AppSpacing.xxl),

            // URL Input
            Text(
              'Recipe URL',
              style: AppTextStyles.bodyLarge.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            TextField(
              controller: _urlController,
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textPrimary,
              ),
              decoration: InputDecoration(
                hintText: 'https://www.tiktok.com/...',
                hintStyle: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.textTertiary,
                ),
                prefixIcon: Icon(
                  _detectedPlatform != null
                      ? Icons.link
                      : Icons.link_off,
                  color: _detectedPlatform != null
                      ? AppColors.primaryAccent
                      : AppColors.textTertiary,
                ),
                suffixIcon: _detectedPlatform != null
                    ? Padding(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        child: Text(
                          _extractionService.getPlatformIcon(_detectedPlatform!),
                          style: const TextStyle(fontSize: 20),
                        ),
                      )
                    : null,
                filled: true,
                fillColor: AppColors.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  borderSide: BorderSide.none,
                ),
              ),
              onChanged: _detectPlatform,
              keyboardType: TextInputType.url,
            ),

            if (_detectedPlatform != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                '${_extractionService.getPlatformIcon(_detectedPlatform!)} ${_extractionService.getPlatformName(_detectedPlatform!)} recipe detected',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.primaryAccent,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],

            // Recipe Text Input - Only show in manual mode
            if (_showManualMode) ...[
              const SizedBox(height: AppSpacing.xl),
              Text(
                'Recipe Text',
                style: AppTextStyles.bodyLarge.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Paste the full recipe text including ingredients and instructions',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: _textController,
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.textPrimary,
                ),
                decoration: InputDecoration(
                  hintText: 'Paste recipe text here...\n\nIngredients:\n- 2 cups flour\n- 1 cup sugar\n...\n\nInstructions:\n1. Mix ingredients...',
                  hintStyle: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.textTertiary,
                  ),
                  filled: true,
                  fillColor: AppColors.surface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    borderSide: BorderSide.none,
                  ),
                  alignLabelWithHint: true,
                ),
                maxLines: 10,
                keyboardType: TextInputType.multiline,
              ),
            ],

            const SizedBox(height: AppSpacing.xxl),

            // Error Message
            if (_errorMessage != null) ...[
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: AppColors.favorite.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.error_outline,
                      color: AppColors.favorite,
                      size: 20,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: AppColors.favorite,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
            ],

            // Extract Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isExtracting
                    ? null
                    : _showManualMode
                        ? _extractRecipeManual
                        : _extractRecipeAuto,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryAccent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                ),
                icon: _isExtracting
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Icon(_showManualMode ? Icons.edit_note : Icons.auto_awesome),
                label: Text(
                  _isExtracting
                      ? 'Extracting...'
                      : _showManualMode
                          ? 'Extract Recipe'
                          : 'Auto Extract Recipe',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),

            // Extracted Recipe Preview
            if (_extractedRecipe != null) ...[
              const SizedBox(height: AppSpacing.xxl),
              const Divider(color: AppColors.textTertiary),
              const SizedBox(height: AppSpacing.xxl),

              // Recipe Preview Header
              Row(
                children: [
                  const Icon(
                    Icons.check_circle,
                    color: AppColors.success,
                    size: 24,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    'Recipe Extracted',
                    style: AppTextStyles.recipeTitle.copyWith(
                      color: AppColors.success,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),

              // Recipe Title
              Text(
                _extractedRecipe!.title,
                style: AppTextStyles.pageHeadline,
              ),
              const SizedBox(height: AppSpacing.md),

              // Recipe Meta
              Row(
                children: [
                  if (_extractedRecipe!.servings != null) ...[
                    const Icon(Icons.people_outline, size: 16, color: AppColors.textSecondary),
                    const SizedBox(width: 4),
                    Text(
                      '${_extractedRecipe!.servings} servings',
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.lg),
                  ],
                  if (_extractedRecipe!.readyInMinutes != null) ...[
                    const Icon(Icons.access_time, size: 16, color: AppColors.textSecondary),
                    const SizedBox(width: 4),
                    Text(
                      '${_extractedRecipe!.readyInMinutes} min',
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ],
              ),

              const SizedBox(height: AppSpacing.xl),

              // Ingredients Count
              Text(
                'Ingredients (${_extractedRecipe!.ingredients.length})',
                style: AppTextStyles.bodyLarge.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              ...List.generate(
                _extractedRecipe!.ingredients.take(5).length,
                (index) {
                  final ingredient = _extractedRecipe!.ingredients[index];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.circle,
                          size: 6,
                          color: AppColors.primaryAccent,
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Text(
                            ingredient.original,
                            style: AppTextStyles.bodyMedium,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
              if (_extractedRecipe!.ingredients.length > 5)
                Text(
                  '+ ${_extractedRecipe!.ingredients.length - 5} more',
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),

              const SizedBox(height: AppSpacing.xl),

              // Instructions Count
              Text(
                'Instructions (${_extractedRecipe!.instructions.length})',
                style: AppTextStyles.bodyLarge.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              if (_extractedRecipe!.instructions.isNotEmpty)
                ...List.generate(
                  _extractedRecipe!.instructions.take(3).length,
                  (index) {
                    final step = _extractedRecipe!.instructions[index];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.md),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 24,
                            height: 24,
                            decoration: BoxDecoration(
                              color: AppColors.primaryAccent,
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: Text(
                                '${step.number}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: Text(
                              step.step,
                              style: AppTextStyles.bodyMedium,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              if (_extractedRecipe!.instructions.isNotEmpty &&
                  _extractedRecipe!.instructions.length > 3)
                Text(
                  '+ ${_extractedRecipe!.instructions.length - 3} more steps',
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),

              const SizedBox(height: AppSpacing.xxl),

              // Save Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isSaving ? null : _saveRecipe,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.success,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                  ),
                  icon: _isSaving
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.save_outlined),
                  label: Text(
                    _isSaving ? 'Saving...' : 'Save Recipe',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
