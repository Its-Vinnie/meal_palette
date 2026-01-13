import 'package:flutter/material.dart';
import 'package:meal_palette/screen/generated_recipes_screen.dart';
import 'package:meal_palette/screen/generation_history_screen.dart';
import 'package:meal_palette/service/ocr_service.dart';
import 'package:meal_palette/service/recipe_extraction_service.dart';
import 'package:meal_palette/theme/theme_design.dart';
import 'package:meal_palette/widgets/custom_text_field.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

/// Screen for users to input ingredients they have
/// Supports both manual entry and camera scanning
class IngredientInputScreen extends StatefulWidget {
  const IngredientInputScreen({super.key});

  @override
  State<IngredientInputScreen> createState() => _IngredientInputScreenState();
}

class _IngredientInputScreenState extends State<IngredientInputScreen> {
  //* Controllers and state
  final _ingredientController = TextEditingController();
  final List<String> _ingredients = [];
  File? _selectedImage;
  bool _isProcessingImage = false;
  final ImagePicker _picker = ImagePicker();

  @override
  void dispose() {
    _ingredientController.dispose();
    super.dispose();
  }

  /// Add ingredient manually
  void _addIngredient() {
    final ingredient = _ingredientController.text.trim();
    if (ingredient.isNotEmpty && !_ingredients.contains(ingredient)) {
      setState(() {
        _ingredients.add(ingredient);
        _ingredientController.clear();
      });
    }
  }

  /// Remove ingredient from list
  void _removeIngredient(int index) {
    setState(() {
      _ingredients.removeAt(index);
    });
  }

  // Take photo with camera
  Future<void> _takePhoto() async {
    try {
      final XFile? photo = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 80,
      );

      if (photo != null) {
        setState(() {
          _selectedImage = File(photo.path);
        });
        await _processImage();
      }
    } catch (e) {
      _showError('Failed to take photo: $e');
    }
  }

  // Pick image from gallery
  Future<void> _pickFromGallery() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
      );

      if (image != null) {
        setState(() {
          _selectedImage = File(image.path);
        });
        await _processImage();
      }
    } catch (e) {
      _showError('Failed to pick image: $e');
    }
  }

  /// Process image to extract ingredients using OCR and Claude AI
  Future<void> _processImage() async {
    if (_selectedImage == null) return;

    setState(() => _isProcessingImage = true);

    try {
      // Step 1: Extract text from image using Google ML Kit OCR
      final extractedText = await ocrService.extractTextFromImage(_selectedImage!.path);

      if (extractedText.isEmpty) {
        _showError('No text found in image. Please try a clearer image.');
        setState(() => _isProcessingImage = false);
        return;
      }

      // Step 2: Use Claude AI to parse ingredients from extracted text
      final detectedIngredients = await recipeExtractionService.extractIngredientsFromText(extractedText);

      if (detectedIngredients.isEmpty) {
        _showError('No ingredients found in the text. Please try a different image.');
        setState(() => _isProcessingImage = false);
        return;
      }

      // Step 3: Show confirmation dialog
      if (mounted) {
        final confirmed = await _showIngredientsConfirmationDialog(
          detectedIngredients,
        );

        if (confirmed != null) {
          setState(() {
            _ingredients.addAll(confirmed);
            _selectedImage = null;
          });
        }
      }
    } catch (e) {
      print('Error processing image: $e');
      _showError('Failed to process image: ${e.toString()}');
    } finally {
      setState(() => _isProcessingImage = false);
    }
  }

  /// Show dialog to confirm detected ingredients
  Future<List<String>?> _showIngredientsConfirmationDialog(
    List<String> detected,
  ) async {
    final selected = detected.toSet();

    return showDialog<List<String>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: AppColors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.xl),
          ),
          title: Text(
            'Detected Ingredients',
            style: AppTextStyles.recipeTitle,
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Select the ingredients you want to use:',
                  style: AppTextStyles.bodyMedium,
                ),
                SizedBox(height: AppSpacing.lg),
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: detected.length,
                    itemBuilder: (context, index) {
                      final ingredient = detected[index];
                      return CheckboxListTile(
                        value: selected.contains(ingredient),
                        onChanged: (value) {
                          setDialogState(() {
                            if (value == true) {
                              selected.add(ingredient);
                            } else {
                              selected.remove(ingredient);
                            }
                          });
                        },
                        title: Text(
                          ingredient,
                          style: AppTextStyles.bodyMedium,
                        ),
                        activeColor: AppColors.primaryAccent,
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, selected.toList()),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryAccent,
              ),
              child: Text('Confirm'),
            ),
          ],
        ),
      ),
    );
  }

  /// Generate recipes from ingredients
  void _generateRecipes() {
    if (_ingredients.isEmpty) {
      _showError('Please add at least one ingredient');
      return;
    }

    // Navigate to generated recipes screen
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => GeneratedRecipesScreen(
          ingredients: _ingredients,
        ),
      ),
    );
  }

  /// Show error message
  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.favorite,
      ),
    );
  }

  /// Show image source selection
  void _showImageSourceSelection() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      builder: (context) => Padding(
        padding: EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.textTertiary,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            SizedBox(height: AppSpacing.xl),

            Text('Scan Ingredients', style: AppTextStyles.recipeTitle),
            SizedBox(height: AppSpacing.xl),

            // Camera option
            _buildImageSourceOption(
              icon: Icons.camera_alt_outlined,
              title: 'Take Photo',
              subtitle: 'Capture ingredients with camera',
              onTap: () {
                Navigator.pop(context);
                _takePhoto();
              },
            ),
            SizedBox(height: AppSpacing.md),

            // Gallery option
            _buildImageSourceOption(
              icon: Icons.image_outlined,
              title: 'Choose from Gallery',
              subtitle: 'Select existing photo',
              onTap: () {
                Navigator.pop(context);
                _pickFromGallery();
              },
            ),

            SizedBox(height: AppSpacing.xl),
          ],
        ),
      ),
    );
  }

  Widget _buildImageSourceOption({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: AppColors.primaryAccent.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Icon(icon, color: AppColors.primaryAccent, size: 24),
            ),
            SizedBox(width: AppSpacing.lg),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTextStyles.bodyLarge.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: AppTextStyles.labelMedium.copyWith(
                      color: AppColors.textTertiary,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              color: AppColors.textTertiary,
              size: 16,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: Text('Your Ingredients'),
        actions: [
          // History button
          IconButton(
            icon: Icon(Icons.history),
            onPressed: () {
              Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => GenerationHistoryScreen(),
                  ));
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('History feature coming soon!')),
              );
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                child: Padding(
                  padding: EdgeInsets.all(AppSpacing.lg),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      //* Header
                      Text(
                        'What\'s in your fridge?',
                        style:
                            AppTextStyles.pageHeadline.copyWith(fontSize: 28),
                      ),
                      SizedBox(height: AppSpacing.sm),
                      Text(
                        'Add ingredients to get personalized recipe suggestions',
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),

                      SizedBox(height: AppSpacing.xxl),

                      //* Scan Ingredients Button
                      SizedBox(
                        width: double.infinity,
                        height: 120,
                        child: ElevatedButton(
                          onPressed: _isProcessingImage
                              ? null
                              : _showImageSourceSelection,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primaryAccent,
                            padding: EdgeInsets.all(AppSpacing.lg),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(AppRadius.xl),
                            ),
                          ),
                          child: _isProcessingImage
                              ? CircularProgressIndicator(
                                  color: AppColors.textPrimary,
                                )
                              : Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.camera_alt_outlined,
                                      size: 40,
                                      color: AppColors.textPrimary,
                                    ),
                                    SizedBox(height: AppSpacing.sm),
                                    Text(
                                      'Scan Ingredients',
                                      style: AppTextStyles.bodyLarge.copyWith(
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                    Text(
                                      'Take a photo of your ingredients',
                                      style: AppTextStyles.labelMedium.copyWith(
                                        color: AppColors.textPrimary
                                            .withValues(alpha: 0.8),
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                      ),

                      SizedBox(height: AppSpacing.xl),

                      //* Divider
                      Row(
                        children: [
                          Expanded(
                            child: Divider(
                              color:
                                  AppColors.textTertiary.withValues(alpha: 0.3),
                            ),
                          ),
                          Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: AppSpacing.lg,
                            ),
                            child: Text(
                              'OR',
                              style: AppTextStyles.labelMedium.copyWith(
                                color: AppColors.textTertiary,
                              ),
                            ),
                          ),
                          Expanded(
                            child: Divider(
                              color:
                                  AppColors.textTertiary.withValues(alpha: 0.3),
                            ),
                          ),
                        ],
                      ),

                      SizedBox(height: AppSpacing.xl),

                      //* Manual Entry Section
                      Text(
                        'Add Manually',
                        style: AppTextStyles.bodyLarge.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      SizedBox(height: AppSpacing.md),

                      //* Input field
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _ingredientController,
                              style: AppTextStyles.bodyMedium,
                              decoration: InputDecoration(
                                hintText: 'Enter ingredient name',
                                hintStyle: AppTextStyles.bodyMedium.copyWith(
                                  color: AppColors.textTertiary,
                                ),
                                filled: true,
                                fillColor: AppColors.surface,
                                border: OutlineInputBorder(
                                  borderRadius:
                                      BorderRadius.circular(AppRadius.md),
                                  borderSide: BorderSide.none,
                                ),
                                prefixIcon: Icon(
                                  Icons.restaurant_outlined,
                                  color: AppColors.textTertiary,
                                ),
                              ),
                              textInputAction: TextInputAction.done,
                              onSubmitted: (_) => _addIngredient(),
                            ),
                          ),
                          SizedBox(width: AppSpacing.md),
                          Container(
                            height: 56,
                            width: 56,
                            decoration: BoxDecoration(
                              color: AppColors.primaryAccent,
                              borderRadius: BorderRadius.circular(AppRadius.md),
                            ),
                            child: IconButton(
                              icon:
                                  Icon(Icons.add, color: AppColors.textPrimary),
                              onPressed: _addIngredient,
                            ),
                          ),
                        ],
                      ),

                      SizedBox(height: AppSpacing.xl),

                      //* Ingredients List
                      if (_ingredients.isNotEmpty) ...[
                        Text(
                          'Your Ingredients (${_ingredients.length})',
                          style: AppTextStyles.bodyLarge.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        SizedBox(height: AppSpacing.md),
                        Wrap(
                          spacing: AppSpacing.sm,
                          runSpacing: AppSpacing.sm,
                          children: _ingredients
                              .asMap()
                              .entries
                              .map(
                                (entry) => Chip(
                                  label: Text(
                                    entry.value,
                                    style: AppTextStyles.bodyMedium,
                                  ),
                                  deleteIcon: Icon(
                                    Icons.close,
                                    size: 18,
                                    color: AppColors.textSecondary,
                                  ),
                                  onDeleted: () => _removeIngredient(entry.key),
                                  backgroundColor: AppColors.surface,
                                  side: BorderSide(
                                    color: AppColors.primaryAccent
                                        .withValues(alpha: 0.3),
                                  ),
                                ),
                              )
                              .toList(),
                        ),
                      ] else
                        Container(
                          padding: EdgeInsets.all(AppSpacing.xl),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(AppRadius.md),
                            border: Border.all(
                              color:
                                  AppColors.textTertiary.withValues(alpha: 0.2),
                              style: BorderStyle.solid,
                            ),
                          ),
                          child: Column(
                            children: [
                              Icon(
                                Icons.inventory_2_outlined,
                                size: 48,
                                color: AppColors.textTertiary,
                              ),
                              SizedBox(height: AppSpacing.md),
                              Text(
                                'No ingredients added yet',
                                style: AppTextStyles.bodyMedium.copyWith(
                                  color: AppColors.textTertiary,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),

            //* Generate Button (sticky at bottom)
            if (_ingredients.isNotEmpty)
              Container(
                padding: EdgeInsets.all(AppSpacing.lg),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 10,
                      offset: Offset(0, -5),
                    ),
                  ],
                ),
                child: SafeArea(
                  child: SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: _generateRecipes,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.secondaryAccent,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppRadius.xl),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.auto_awesome, size: 24),
                          SizedBox(width: AppSpacing.md),
                          Text(
                            'Generate Recipes',
                            style: AppTextStyles.button,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
