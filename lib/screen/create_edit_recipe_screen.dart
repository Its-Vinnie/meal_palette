import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:meal_palette/model/custom_recipe_model.dart';
import 'package:meal_palette/model/ingredient_model.dart';
import 'package:meal_palette/model/instruction_step_model.dart';
import 'package:meal_palette/service/auth_service.dart';
import 'package:meal_palette/state/custom_recipes_state.dart';
import 'package:meal_palette/theme/theme_design.dart';
import 'package:uuid/uuid.dart';

/// Screen for creating or editing custom recipes
class CreateEditRecipeScreen extends StatefulWidget {
  final CustomRecipe? recipe; // null = create new, non-null = edit

  const CreateEditRecipeScreen({super.key, this.recipe});

  @override
  State<CreateEditRecipeScreen> createState() => _CreateEditRecipeScreenState();
}

class _CreateEditRecipeScreenState extends State<CreateEditRecipeScreen> {
  final _formKey = GlobalKey<FormState>();
  final CustomRecipesState _recipesState = customRecipesState;
  final AuthService _authService = authService;
  final _uuid = const Uuid();
  final _imagePicker = ImagePicker();

  // Form controllers
  late TextEditingController _titleController;
  late TextEditingController _descriptionController;
  late TextEditingController _servingsController;
  late TextEditingController _prepTimeController;
  late TextEditingController _cookTimeController;

  // Form data
  String? _selectedCategory;
  List<_IngredientItem> _ingredients = [];
  List<_InstructionItem> _instructions = [];
  Set<String> _selectedTags = {};
  bool _vegetarian = false;
  bool _vegan = false;
  bool _glutenFree = false;
  bool _dairyFree = false;

  // Image handling
  File? _selectedImage;
  String? _existingImageUrl;

  // UI state
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _initializeForm();
  }

  void _initializeForm() {
    if (widget.recipe != null) {
      // Edit mode - populate from existing recipe
      final recipe = widget.recipe!;
      _titleController = TextEditingController(text: recipe.title);
      _descriptionController = TextEditingController(text: recipe.description ?? '');
      _servingsController = TextEditingController(text: recipe.servings?.toString() ?? '');
      _prepTimeController = TextEditingController(text: recipe.prepTime?.toString() ?? '');
      _cookTimeController = TextEditingController(text: recipe.cookTime?.toString() ?? '');

      _selectedCategory = recipe.category;
      _ingredients = recipe.ingredients
          .map((ing) => _IngredientItem(
                nameController: TextEditingController(text: ing.name),
                amountController: TextEditingController(text: ing.amount.toString()),
                unitController: TextEditingController(text: ing.unit),
              ))
          .toList();
      _instructions = recipe.instructions
          .map((inst) => _InstructionItem(
                controller: TextEditingController(text: inst.step),
                number: inst.number,
              ))
          .toList();
      _selectedTags = Set.from(recipe.tags);
      _vegetarian = recipe.vegetarian;
      _vegan = recipe.vegan;
      _glutenFree = recipe.glutenFree;
      _dairyFree = recipe.dairyFree;
      _existingImageUrl = recipe.imageUrl;
    } else {
      // Create mode - empty form
      _titleController = TextEditingController();
      _descriptionController = TextEditingController();
      _servingsController = TextEditingController();
      _prepTimeController = TextEditingController();
      _cookTimeController = TextEditingController();
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _servingsController.dispose();
    _prepTimeController.dispose();
    _cookTimeController.dispose();
    for (var item in _ingredients) {
      item.dispose();
    }
    for (var item in _instructions) {
      item.dispose();
    }
    super.dispose();
  }

  /// Add a new ingredient field
  void _addIngredient() {
    setState(() {
      _ingredients.add(_IngredientItem(
        nameController: TextEditingController(),
        amountController: TextEditingController(),
        unitController: TextEditingController(),
      ));
    });
  }

  /// Remove an ingredient
  void _removeIngredient(int index) {
    setState(() {
      _ingredients[index].dispose();
      _ingredients.removeAt(index);
    });
  }

  /// Add a new instruction step
  void _addInstruction() {
    setState(() {
      _instructions.add(_InstructionItem(
        controller: TextEditingController(),
        number: _instructions.length + 1,
      ));
    });
  }

  /// Remove an instruction
  void _removeInstruction(int index) {
    setState(() {
      _instructions[index].dispose();
      _instructions.removeAt(index);
      // Renumber instructions
      for (int i = 0; i < _instructions.length; i++) {
        _instructions[i].number = i + 1;
      }
    });
  }

  /// Pick image from gallery
  Future<void> _pickImage() async {
    try {
      final image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );

      if (image != null) {
        setState(() {
          _selectedImage = File(image.path);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to pick image: $e'),
            backgroundColor: AppColors.favorite,
          ),
        );
      }
    }
  }

  /// Save the recipe
  Future<void> _saveRecipe() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_ingredients.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please add at least one ingredient'),
          backgroundColor: AppColors.favorite,
        ),
      );
      return;
    }

    if (_instructions.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please add at least one instruction'),
          backgroundColor: AppColors.favorite,
        ),
      );
      return;
    }

    final user = _authService.currentUser;
    if (user == null) return;

    setState(() => _isSaving = true);

    try {
      String? imageUrl = _existingImageUrl;

      // Upload new image if selected
      if (_selectedImage != null) {
        imageUrl = await _recipesState.uploadRecipeImage(user.uid, _selectedImage!);
      }

      // Build ingredients list
      final ingredients = _ingredients
          .where((item) => item.nameController.text.trim().isNotEmpty)
          .map((item) => Ingredient(
                id: 0,
                name: item.nameController.text.trim(),
                original: '${item.amountController.text.trim()} ${item.unitController.text.trim()} ${item.nameController.text.trim()}',
                amount: double.tryParse(item.amountController.text.trim()) ?? 0,
                unit: item.unitController.text.trim(),
              ))
          .toList();

      // Build instructions list
      final instructions = _instructions
          .where((item) => item.controller.text.trim().isNotEmpty)
          .map((item) => InstructionStep(
                number: item.number,
                step: item.controller.text.trim(),
              ))
          .toList();

      // Create or update recipe
      final recipe = CustomRecipe(
        id: widget.recipe?.id ?? _uuid.v4(),
        userId: user.uid,
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
        imageUrl: imageUrl,
        ingredients: ingredients,
        instructions: instructions,
        servings: int.tryParse(_servingsController.text.trim()),
        prepTime: int.tryParse(_prepTimeController.text.trim()),
        cookTime: int.tryParse(_cookTimeController.text.trim()),
        category: _selectedCategory,
        tags: _selectedTags.toList(),
        createdAt: widget.recipe?.createdAt ?? DateTime.now(),
        updatedAt: widget.recipe != null ? DateTime.now() : null,
        source: widget.recipe?.source ?? 'manual',
        sourceUrl: widget.recipe?.sourceUrl,
        vegetarian: _vegetarian,
        vegan: _vegan,
        glutenFree: _glutenFree,
        dairyFree: _dairyFree,
      );

      bool success;
      if (widget.recipe == null) {
        // Create new recipe
        final recipeId = await _recipesState.createRecipe(user.uid, recipe);
        success = recipeId != null;
      } else {
        // Update existing recipe
        success = await _recipesState.updateRecipe(user.uid, recipe);
      }

      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.recipe == null
                ? '✅ Recipe created successfully'
                : '✅ Recipe updated successfully'),
            backgroundColor: AppColors.success,
          ),
        );
        Navigator.pop(context);
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
        title: Text(
          widget.recipe == null ? 'Create Recipe' : 'Edit Recipe',
          style: const TextStyle(color: AppColors.textPrimary),
        ),
        leading: IconButton(
          icon: const Icon(Icons.close, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          TextButton(
            onPressed: _isSaving ? null : _saveRecipe,
            child: _isSaving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.primaryAccent,
                    ),
                  )
                : const Text(
                    'Save',
                    style: TextStyle(
                      color: AppColors.primaryAccent,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            // Image picker
            _buildImagePicker(),
            const SizedBox(height: AppSpacing.xl),

            // Title
            TextFormField(
              controller: _titleController,
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textPrimary,
              ),
              decoration: InputDecoration(
                labelText: 'Recipe Title *',
                labelStyle: AppTextStyles.bodyMedium,
                hintText: 'e.g., Chocolate Chip Cookies',
                hintStyle: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.textTertiary,
                ),
                filled: true,
                fillColor: AppColors.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  borderSide: BorderSide.none,
                ),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter a recipe title';
                }
                return null;
              },
            ),
            const SizedBox(height: AppSpacing.lg),

            // Description
            TextFormField(
              controller: _descriptionController,
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textPrimary,
              ),
              decoration: InputDecoration(
                labelText: 'Description (Optional)',
                labelStyle: AppTextStyles.bodyMedium,
                hintText: 'Tell us about this recipe...',
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
              maxLines: 3,
            ),
            const SizedBox(height: AppSpacing.lg),

            // Category
            DropdownButtonFormField<String>(
              value: _selectedCategory,
              dropdownColor: AppColors.surface,
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textPrimary,
              ),
              decoration: InputDecoration(
                labelText: 'Category',
                labelStyle: AppTextStyles.bodyMedium,
                filled: true,
                fillColor: AppColors.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  borderSide: BorderSide.none,
                ),
              ),
              items: RecipeCategories.all.map((category) {
                return DropdownMenuItem(
                  value: category,
                  child: Text(
                    '${RecipeCategories.getIcon(category)} ${RecipeCategories.getDisplayName(category)}',
                  ),
                );
              }).toList(),
              onChanged: (value) {
                setState(() => _selectedCategory = value);
              },
            ),
            const SizedBox(height: AppSpacing.lg),

            // Servings, Prep Time, Cook Time (Row)
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _servingsController,
                    keyboardType: TextInputType.number,
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: AppColors.textPrimary,
                    ),
                    decoration: InputDecoration(
                      labelText: 'Servings',
                      labelStyle: AppTextStyles.bodyMedium,
                      hintText: '4',
                      filled: true,
                      fillColor: AppColors.surface,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppRadius.md),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: TextFormField(
                    controller: _prepTimeController,
                    keyboardType: TextInputType.number,
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: AppColors.textPrimary,
                    ),
                    decoration: InputDecoration(
                      labelText: 'Prep (min)',
                      labelStyle: AppTextStyles.bodyMedium,
                      hintText: '15',
                      filled: true,
                      fillColor: AppColors.surface,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppRadius.md),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: TextFormField(
                    controller: _cookTimeController,
                    keyboardType: TextInputType.number,
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: AppColors.textPrimary,
                    ),
                    decoration: InputDecoration(
                      labelText: 'Cook (min)',
                      labelStyle: AppTextStyles.bodyMedium,
                      hintText: '30',
                      filled: true,
                      fillColor: AppColors.surface,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppRadius.md),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xxl),

            // Dietary flags
            _buildDietaryFlags(),
            const SizedBox(height: AppSpacing.xxl),

            // Tags
            _buildTagsSection(),
            const SizedBox(height: AppSpacing.xxl),

            // Ingredients
            _buildIngredientsSection(),
            const SizedBox(height: AppSpacing.xxl),

            // Instructions
            _buildInstructionsSection(),
            const SizedBox(height: 100), // Space for FAB
          ],
        ),
      ),
    );
  }

  Widget _buildImagePicker() {
    return GestureDetector(
      onTap: _pickImage,
      child: Container(
        height: 200,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.md),
          image: _selectedImage != null
              ? DecorationImage(
                  image: FileImage(_selectedImage!),
                  fit: BoxFit.cover,
                )
              : (_existingImageUrl != null
                  ? DecorationImage(
                      image: NetworkImage(_existingImageUrl!),
                      fit: BoxFit.cover,
                    )
                  : null),
        ),
        child: _selectedImage == null && _existingImageUrl == null
            ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.add_photo_alternate,
                    size: 48,
                    color: AppColors.textTertiary,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    'Add Recipe Photo',
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              )
            : Stack(
                children: [
                  Positioned(
                    top: AppSpacing.sm,
                    right: AppSpacing.sm,
                    child: Container(
                      padding: const EdgeInsets.all(AppSpacing.sm),
                      decoration: BoxDecoration(
                        color: AppColors.overlayDark.withValues(alpha: 0.7),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.edit,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildDietaryFlags() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Dietary Information',
          style: AppTextStyles.bodyLarge.copyWith(
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Wrap(
          spacing: AppSpacing.md,
          runSpacing: AppSpacing.sm,
          children: [
            FilterChip(
              label: const Text('🌱 Vegetarian'),
              selected: _vegetarian,
              onSelected: (value) {
                setState(() => _vegetarian = value);
              },
              backgroundColor: AppColors.surface,
              selectedColor: AppColors.primaryAccent,
              labelStyle: TextStyle(
                color: _vegetarian ? Colors.white : AppColors.textPrimary,
              ),
            ),
            FilterChip(
              label: const Text('🌿 Vegan'),
              selected: _vegan,
              onSelected: (value) {
                setState(() {
                  _vegan = value;
                  if (value) _vegetarian = true; // Vegan implies vegetarian
                });
              },
              backgroundColor: AppColors.surface,
              selectedColor: AppColors.primaryAccent,
              labelStyle: TextStyle(
                color: _vegan ? Colors.white : AppColors.textPrimary,
              ),
            ),
            FilterChip(
              label: const Text('🌾 Gluten-Free'),
              selected: _glutenFree,
              onSelected: (value) {
                setState(() => _glutenFree = value);
              },
              backgroundColor: AppColors.surface,
              selectedColor: AppColors.primaryAccent,
              labelStyle: TextStyle(
                color: _glutenFree ? Colors.white : AppColors.textPrimary,
              ),
            ),
            FilterChip(
              label: const Text('🥛 Dairy-Free'),
              selected: _dairyFree,
              onSelected: (value) {
                setState(() => _dairyFree = value);
              },
              backgroundColor: AppColors.surface,
              selectedColor: AppColors.primaryAccent,
              labelStyle: TextStyle(
                color: _dairyFree ? Colors.white : AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTagsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Tags',
          style: AppTextStyles.bodyLarge.copyWith(
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: RecipeTags.all.map((tag) {
            final isSelected = _selectedTags.contains(tag);
            return FilterChip(
              label: Text(RecipeTags.getDisplayName(tag)),
              selected: isSelected,
              onSelected: (value) {
                setState(() {
                  if (value) {
                    _selectedTags.add(tag);
                  } else {
                    _selectedTags.remove(tag);
                  }
                });
              },
              backgroundColor: AppColors.surface,
              selectedColor: AppColors.primaryAccent,
              labelStyle: TextStyle(
                color: isSelected ? Colors.white : AppColors.textPrimary,
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildIngredientsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Ingredients *',
              style: AppTextStyles.bodyLarge.copyWith(
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            TextButton.icon(
              onPressed: _addIngredient,
              icon: const Icon(Icons.add, size: 20),
              label: const Text('Add'),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.primaryAccent,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        if (_ingredients.isEmpty)
          Container(
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Center(
              child: Text(
                'No ingredients yet. Tap "Add" to get started.',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.textTertiary,
                ),
              ),
            ),
          )
        else
          ...List.generate(_ingredients.length, (index) {
            final item = _ingredients[index];
            return Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.md),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 3,
                    child: TextFormField(
                      controller: item.nameController,
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: AppColors.textPrimary,
                      ),
                      decoration: InputDecoration(
                        labelText: 'Ingredient',
                        labelStyle: AppTextStyles.labelMedium,
                        hintText: 'e.g., Flour',
                        filled: true,
                        fillColor: AppColors.surface,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppRadius.md),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.all(AppSpacing.md),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    flex: 1,
                    child: TextFormField(
                      controller: item.amountController,
                      keyboardType: TextInputType.number,
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: AppColors.textPrimary,
                      ),
                      decoration: InputDecoration(
                        labelText: 'Amount',
                        labelStyle: AppTextStyles.labelMedium,
                        hintText: '2',
                        filled: true,
                        fillColor: AppColors.surface,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppRadius.md),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.all(AppSpacing.md),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    flex: 1,
                    child: TextFormField(
                      controller: item.unitController,
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: AppColors.textPrimary,
                      ),
                      decoration: InputDecoration(
                        labelText: 'Unit',
                        labelStyle: AppTextStyles.labelMedium,
                        hintText: 'cups',
                        filled: true,
                        fillColor: AppColors.surface,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppRadius.md),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.all(AppSpacing.md),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: AppColors.favorite),
                    onPressed: () => _removeIngredient(index),
                  ),
                ],
              ),
            );
          }),
      ],
    );
  }

  Widget _buildInstructionsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Instructions *',
              style: AppTextStyles.bodyLarge.copyWith(
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            TextButton.icon(
              onPressed: _addInstruction,
              icon: const Icon(Icons.add, size: 20),
              label: const Text('Add Step'),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.primaryAccent,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        if (_instructions.isEmpty)
          Container(
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Center(
              child: Text(
                'No instructions yet. Tap "Add Step" to get started.',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.textTertiary,
                ),
              ),
            ),
          )
        else
          ...List.generate(_instructions.length, (index) {
            final item = _instructions[index];
            return Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.md),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    margin: const EdgeInsets.only(top: AppSpacing.md),
                    decoration: BoxDecoration(
                      color: AppColors.primaryAccent,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        '${item.number}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: TextFormField(
                      controller: item.controller,
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: AppColors.textPrimary,
                      ),
                      decoration: InputDecoration(
                        labelText: 'Step ${item.number}',
                        labelStyle: AppTextStyles.labelMedium,
                        hintText: 'Describe this step...',
                        filled: true,
                        fillColor: AppColors.surface,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppRadius.md),
                          borderSide: BorderSide.none,
                        ),
                        alignLabelWithHint: true,
                      ),
                      maxLines: 3,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: AppColors.favorite),
                    onPressed: () => _removeInstruction(index),
                  ),
                ],
              ),
            );
          }),
      ],
    );
  }
}

// Helper class for ingredient form items
class _IngredientItem {
  final TextEditingController nameController;
  final TextEditingController amountController;
  final TextEditingController unitController;

  _IngredientItem({
    required this.nameController,
    required this.amountController,
    required this.unitController,
  });

  void dispose() {
    nameController.dispose();
    amountController.dispose();
    unitController.dispose();
  }
}

// Helper class for instruction form items
class _InstructionItem {
  final TextEditingController controller;
  int number;

  _InstructionItem({
    required this.controller,
    required this.number,
  });

  void dispose() {
    controller.dispose();
  }
}
