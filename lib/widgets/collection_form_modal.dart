import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:meal_palette/model/recipe_collection_model.dart';
import 'package:meal_palette/service/auth_service.dart';
import 'package:meal_palette/state/collections_state.dart';
import 'package:meal_palette/theme/theme_design.dart';

/// Modal bottom sheet for creating or editing a collection
class CollectionFormModal extends StatefulWidget {
  final RecipeCollection? collection; // Null for create, non-null for edit

  const CollectionFormModal({
    super.key,
    this.collection,
  });

  @override
  State<CollectionFormModal> createState() => _CollectionFormModalState();
}

class _CollectionFormModalState extends State<CollectionFormModal> {
  final CollectionsState _collectionsState = collectionsState;
  final AuthService _authService = authService;
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _descriptionController;
  late String _selectedIcon;
  late Color _selectedColor;
  late String _coverImageType;
  String? _customCoverUrl;
  File? _selectedImageFile;
  bool _isSaving = false;
  bool _isUploadingImage = false;

  bool get _isEditing => widget.collection != null;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(
      text: widget.collection?.name ?? '',
    );
    _descriptionController = TextEditingController(
      text: widget.collection?.description ?? '',
    );
    _selectedIcon = widget.collection?.icon ?? 'favorite';
    _selectedColor = widget.collection?.colorValue ?? CollectionColors.presets[0];
    _coverImageType = widget.collection?.coverImageType ?? 'grid';
    _customCoverUrl = widget.collection?.customCoverUrl;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  /// Pick image from gallery
  Future<void> _pickImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);

    if (image != null) {
      setState(() {
        _selectedImageFile = File(image.path);
      });
    }
  }

  /// Upload image to Firebase Storage and return URL
  Future<String?> _uploadImage() async {
    if (_selectedImageFile == null) return null;

    setState(() => _isUploadingImage = true);

    try {
      final userId = _authService.currentUser?.uid;
      if (userId == null) {
        throw Exception('User not authenticated');
      }

      // Create unique filename
      final String fileName = 'collection_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final String path = 'users/$userId/collections/$fileName';

      // Upload to Firebase Storage
      final storageRef = FirebaseStorage.instance.ref().child(path);
      await storageRef.putFile(_selectedImageFile!);

      // Get download URL
      final String downloadUrl = await storageRef.getDownloadURL();

      setState(() {
        _customCoverUrl = downloadUrl;
        _isUploadingImage = false;
      });

      return downloadUrl;
    } catch (e) {
      setState(() => _isUploadingImage = false);
      print('❌ Error uploading image: $e');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to upload image: ${e.toString()}'),
            backgroundColor: AppColors.favorite,
          ),
        );
      }
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppRadius.xl),
        ),
      ),
      padding: EdgeInsets.only(
        left: AppSpacing.xl,
        right: AppSpacing.xl,
        top: AppSpacing.lg,
        bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.xl,
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle bar
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.textSecondary.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),

              // Title
              Text(
                _isEditing ? 'Edit Collection' : 'Create Collection',
                style: AppTextStyles.recipeTitle,
              ),
              const SizedBox(height: AppSpacing.xl),

              // Name field
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Collection Name',
                  hintText: 'e.g., Quick Meals, Italian Recipes',
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter a collection name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: AppSpacing.lg),

              // Description field
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Description (optional)',
                  hintText: 'Describe this collection',
                ),
                maxLines: 2,
              ),
              const SizedBox(height: AppSpacing.xl),

              // Icon picker
              Text(
                'Icon',
                style: AppTextStyles.labelLarge.copyWith(
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              _buildIconPicker(),
              const SizedBox(height: AppSpacing.xl),

              // Color picker
              Text(
                'Color',
                style: AppTextStyles.labelLarge.copyWith(
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              _buildColorPicker(),
              const SizedBox(height: AppSpacing.xxl),

              // Cover image type selector
              Text(
                'Cover Image',
                style: AppTextStyles.labelLarge.copyWith(
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              _buildCoverTypePicker(),
              const SizedBox(height: AppSpacing.md),

              // Custom image picker (only show if custom type selected)
              if (_coverImageType == 'custom') ...[
                _buildCustomImagePicker(),
                const SizedBox(height: AppSpacing.md),
              ],

              const SizedBox(height: AppSpacing.xl),

              // Save button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _saveCollection,
                  child: _isSaving
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              AppColors.textPrimary,
                            ),
                          ),
                        )
                      : Text(_isEditing ? 'Save Changes' : 'Create Collection'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildIconPicker() {
    final icons = CollectionIcons.allIcons;

    return Container(
      height: 120,
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      padding: const EdgeInsets.all(AppSpacing.sm),
      child: GridView.builder(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 6,
          crossAxisSpacing: AppSpacing.sm,
          mainAxisSpacing: AppSpacing.sm,
        ),
        itemCount: icons.length,
        itemBuilder: (context, index) {
          final iconEntry = icons[index];
          final isSelected = _selectedIcon == iconEntry.key;

          return GestureDetector(
            onTap: () {
              setState(() {
                _selectedIcon = iconEntry.key;
              });
            },
            child: Container(
              decoration: BoxDecoration(
                color: isSelected
                    ? _selectedColor.withValues(alpha: 0.3)
                    : AppColors.surface,
                borderRadius: BorderRadius.circular(AppRadius.sm),
                border: isSelected
                    ? Border.all(color: _selectedColor, width: 2)
                    : null,
              ),
              child: Icon(
                iconEntry.value,
                color: isSelected ? _selectedColor : AppColors.textSecondary,
                size: 24,
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildColorPicker() {
    return Wrap(
      spacing: AppSpacing.md,
      runSpacing: AppSpacing.md,
      children: CollectionColors.presets.map((color) {
        final isSelected = _selectedColor == color;

        return GestureDetector(
          onTap: () {
            setState(() {
              _selectedColor = color;
            });
          },
          child: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: isSelected
                  ? Border.all(color: AppColors.textPrimary, width: 3)
                  : null,
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: color.withValues(alpha: 0.5),
                        blurRadius: 8,
                        spreadRadius: 2,
                      ),
                    ]
                  : null,
            ),
            child: isSelected
                ? const Icon(
                    Icons.check,
                    color: Colors.white,
                    size: 24,
                  )
                : null,
          ),
        );
      }).toList(),
    );
  }

  Widget _buildCoverTypePicker() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildCoverTypeOption(
              'grid',
              'Recipe Grid',
              Icons.grid_on,
              'Collage of recipe photos',
            ),
          ),
          Expanded(
            child: _buildCoverTypeOption(
              'first',
              'First Recipe',
              Icons.image,
              'First recipe photo',
            ),
          ),
          Expanded(
            child: _buildCoverTypeOption(
              'custom',
              'Custom',
              Icons.photo_library,
              'Your own photo',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCoverTypeOption(
    String type,
    String label,
    IconData icon,
    String description,
  ) {
    final isSelected = _coverImageType == type;

    return GestureDetector(
      onTap: () {
        setState(() {
          _coverImageType = type;
        });
      },
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: isSelected
              ? _selectedColor.withValues(alpha: 0.2)
              : AppColors.surface,
          border: isSelected
              ? Border.all(color: _selectedColor, width: 2)
              : Border.all(color: Colors.transparent, width: 2),
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isSelected ? _selectedColor : AppColors.textSecondary,
              size: 32,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              label,
              style: AppTextStyles.labelMedium.copyWith(
                color: isSelected ? _selectedColor : AppColors.textSecondary,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              description,
              style: AppTextStyles.labelMedium.copyWith(
                color: AppColors.textTertiary,
                fontSize: 11,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomImagePicker() {
    return GestureDetector(
      onTap: _isUploadingImage ? null : _pickImage,
      child: Container(
        height: 150,
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(
            color: _selectedColor.withValues(alpha: 0.5),
            width: 2,
            style: BorderStyle.solid,
          ),
        ),
        child: _isUploadingImage
            ? const Center(
                child: CircularProgressIndicator(
                  color: AppColors.primaryAccent,
                ),
              )
            : _selectedImageFile != null || _customCoverUrl != null
                ? Stack(
                    fit: StackFit.expand,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(AppRadius.md - 2),
                        child: _selectedImageFile != null
                            ? Image.file(
                                _selectedImageFile!,
                                fit: BoxFit.cover,
                              )
                            : Image.network(
                                _customCoverUrl!,
                                fit: BoxFit.cover,
                              ),
                      ),
                      Positioned(
                        top: AppSpacing.sm,
                        right: AppSpacing.sm,
                        child: IconButton(
                          onPressed: () {
                            setState(() {
                              _selectedImageFile = null;
                            });
                          },
                          style: IconButton.styleFrom(
                            backgroundColor: Colors.black54,
                          ),
                          icon: const Icon(
                            Icons.close,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  )
                : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.add_photo_alternate_outlined,
                        size: 48,
                        color: _selectedColor,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        'Tap to select image',
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: _selectedColor,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Choose from gallery',
                        style: AppTextStyles.labelMedium.copyWith(
                          color: AppColors.textTertiary,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
      ),
    );
  }

  Future<void> _saveCollection() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isSaving = true);

    // Upload custom image if selected
    String? coverUrl = _customCoverUrl;
    if (_coverImageType == 'custom' && _selectedImageFile != null) {
      coverUrl = await _uploadImage();
      if (coverUrl == null) {
        setState(() => _isSaving = false);
        return; // Upload failed, don't proceed
      }
    }

    bool success;
    if (_isEditing) {
      // Update existing collection
      final updatedCollection = widget.collection!.copyWith(
        name: _nameController.text.trim(),
        description: _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
        icon: _selectedIcon,
        color: CollectionColors.toHex(_selectedColor),
        coverImageType: _coverImageType,
        customCoverUrl: _coverImageType == 'custom' ? coverUrl : null,
      );
      success = await _collectionsState.updateCollection(updatedCollection);
    } else {
      // Create new collection
      success = await _collectionsState.createCollection(
        name: _nameController.text.trim(),
        description: _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
        icon: _selectedIcon,
        color: CollectionColors.toHex(_selectedColor),
        coverImageType: _coverImageType,
        customCoverUrl: _coverImageType == 'custom' ? coverUrl : null,
      );
    }

    if (mounted) {
      if (success) {
        Navigator.pop(context, true); // Return true to indicate success
      } else {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _isEditing
                  ? 'Failed to update collection'
                  : 'Failed to create collection',
            ),
            backgroundColor: AppColors.favorite,
          ),
        );
      }
    }
  }
}
