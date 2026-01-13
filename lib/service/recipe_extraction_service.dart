import 'dart:convert';
import 'package:meal_palette/model/cook_along_session.dart';
import 'package:meal_palette/model/detailed_recipe_model.dart';
import 'package:meal_palette/service/claude_conversation_service.dart';

/// Service for extracting recipe information from text using Claude AI
class RecipeExtractionService {
  final ClaudeConversationService _claudeService = ClaudeConversationService();

  // ============================================================================
  // INGREDIENT EXTRACTION
  // ============================================================================

  /// Extract ingredients from raw text (OCR output, manual paste, etc.)
  /// Returns a list of ingredient names
  Future<List<String>> extractIngredientsFromText(String text) async {
    try {
      final prompt = '''
Extract all ingredients from this recipe text. Return ONLY a JSON array of ingredient names (strings).

Rules:
- Include only the ingredient name, not quantities or measurements
- One ingredient per array item
- Remove any measurements, quantities, or preparation instructions
- If text contains no ingredients, return empty array []

Example input: "2 cups flour, 1 tsp salt, 3 eggs, beaten"
Example output: ["flour", "salt", "eggs"]

Text to extract from:
$text

Return only the JSON array, no other text.
''';

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
        systemPrompt: 'You are a recipe ingredient extraction assistant. Return only valid JSON arrays.',
      );

      // Parse JSON response
      final cleaned = _cleanJsonResponse(response);
      final List<dynamic> ingredientsList = jsonDecode(cleaned);
      final ingredients = ingredientsList.map((e) => e.toString()).toList();

      print('✅ Extracted ${ingredients.length} ingredients from text');
      return ingredients;
    } catch (e) {
      print('❌ Error extracting ingredients: $e');
      rethrow;
    }
  }

  // ============================================================================
  // FULL RECIPE EXTRACTION
  // ============================================================================

  /// Extract complete recipe details from text
  /// Returns a RecipeDetail object
  Future<RecipeDetail> extractRecipeFromText(String text, {String? sourceUrl}) async {
    try {
      final prompt = '''
Extract recipe information from this text. Return valid JSON with this exact structure:

{
  "title": "recipe name",
  "servings": number or null,
  "readyInMinutes": number or null,
  "summary": "brief description" or null,
  "extendedIngredients": [
    {
      "id": 1,
      "name": "ingredient name",
      "amount": number or null,
      "unit": "measurement unit" or null,
      "original": "original ingredient line"
    }
  ],
  "analyzedInstructions": [
    {
      "name": "",
      "steps": [
        {
          "number": 1,
          "step": "instruction text"
        }
      ]
    }
  ],
  "vegetarian": boolean,
  "vegan": boolean,
  "glutenFree": boolean,
  "dairyFree": boolean,
  "sourceUrl": "${sourceUrl ?? ''}"
}

Rules:
- Use null for any field you cannot determine
- Use false for dietary flags if uncertain
- Number steps sequentially starting from 1
- If no instructions found, return empty steps array
- Keep ingredient amounts as numbers (1, 2, 0.5, etc.)

Recipe text:
$text

Return only valid JSON, no markdown code blocks or extra text.
''';

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
        systemPrompt: 'You are a recipe extraction expert. Return only valid JSON matching the specified structure.',
      );

      // Clean response (remove markdown code blocks if present)
      String cleaned = _cleanJsonResponse(response);

      // Parse JSON and create RecipeDetail
      final Map<String, dynamic> json = jsonDecode(cleaned);
      final recipe = RecipeDetail.fromJson(json);

      print('✅ Extracted recipe: ${recipe.title}');
      return recipe;
    } catch (e) {
      print('❌ Error extracting recipe from text: $e');
      rethrow;
    }
  }

  // ============================================================================
  // URL-BASED EXTRACTION
  // ============================================================================

  /// Extract recipe directly from a URL by fetching and parsing content automatically
  /// This method fetches the webpage content and extracts the recipe
  Future<RecipeDetail> extractFromUrl(String url) async {
    try {
      print('🔗 Fetching and extracting recipe from URL: $url');

      final prompt = '''
Please fetch the content from this URL and extract the recipe information: $url

Return valid JSON with this exact structure. If any information is missing, use intelligent estimation:

{
  "title": "recipe name",
  "servings": number (estimate based on ingredient quantities if not specified, typical is 4),
  "readyInMinutes": number (estimate based on cooking method and complexity if not specified),
  "summary": "brief description" or null,
  "extendedIngredients": [
    {
      "id": 1,
      "name": "ingredient name",
      "amount": number or null,
      "unit": "measurement unit" or null,
      "original": "original ingredient line"
    }
  ],
  "analyzedInstructions": [
    {
      "name": "",
      "steps": [
        {
          "number": 1,
          "step": "instruction text"
        }
      ]
    }
  ],
  "vegetarian": boolean,
  "vegan": boolean,
  "glutenFree": boolean,
  "dairyFree": boolean,
  "sourceUrl": "$url"
}

Important:
- If servings are not specified, estimate based on ingredient quantities (typical recipe serves 4-6)
- If cooking time is not specified, estimate based on the complexity and cooking methods:
  * Simple salads/no-cook: 10-15 minutes
  * Quick sautés/stir-fries: 20-30 minutes
  * Baked goods: 30-60 minutes
  * Slow-cooked dishes: 90+ minutes
- If you can't find the recipe, throw an error with a clear message

Return only valid JSON, no markdown code blocks or extra text.
''';

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
        systemPrompt: 'You are a recipe extraction expert with web access. Fetch the URL content and extract recipes accurately. Make intelligent estimates for missing information.',
      );

      // Clean response (remove markdown code blocks if present)
      String cleaned = _cleanJsonResponse(response);

      // Parse JSON and create RecipeDetail
      final Map<String, dynamic> json = jsonDecode(cleaned);
      final recipe = RecipeDetail.fromJson(json);

      print('✅ Extracted recipe from URL: ${recipe.title}');
      print('   Servings: ${recipe.servings ?? "estimated"}');
      print('   Time: ${recipe.readyInMinutes ?? "estimated"} minutes');
      return recipe;
    } catch (e) {
      print('❌ Error extracting from URL: $e');
      rethrow;
    }
  }

  /// Extract recipe from a URL with manual text paste (legacy method)
  /// User should paste the URL and optionally the recipe text
  Future<RecipeDetail> extractFromUrlText({
    required String url,
    required String recipeText,
  }) async {
    try {
      print('🔗 Extracting recipe from URL with text: $url');

      // Use the text extraction with URL as source
      final recipe = await extractRecipeFromText(
        recipeText,
        sourceUrl: url,
      );

      // Estimate missing information
      final enhancedRecipe = await _estimateMissingInfo(recipe);
      return enhancedRecipe;
    } catch (e) {
      print('❌ Error extracting from URL: $e');
      rethrow;
    }
  }

  // ============================================================================
  // AI-BASED ESTIMATION
  // ============================================================================

  /// Estimate missing recipe information (servings, time) using AI
  Future<RecipeDetail> _estimateMissingInfo(RecipeDetail recipe) async {
    // If both servings and time are present, no estimation needed
    if (recipe.servings != null && recipe.readyInMinutes != null) {
      return recipe;
    }

    try {
      print('🤖 Estimating missing information for recipe: ${recipe.title}');

      final prompt = '''
Analyze this recipe and estimate missing information:

Title: ${recipe.title}
Current servings: ${recipe.servings ?? "unknown"}
Current time: ${recipe.readyInMinutes ?? "unknown"} minutes
Ingredients count: ${recipe.ingredients.length}
Instructions count: ${recipe.instructions.length}

Sample ingredients:
${recipe.ingredients.take(5).map((i) => i.original).join('\n')}

Sample instructions:
${recipe.instructions.take(3).map((s) => '${s.number}. ${s.step}').join('\n')}

Estimate:
1. Servings (if unknown): Based on ingredient quantities, typically 4-6 for most recipes
2. Cooking time (if unknown): Based on complexity, cooking methods, and steps

Return JSON:
{
  "estimatedServings": number,
  "estimatedMinutes": number,
  "reasoning": "brief explanation"
}

Return only valid JSON.
''';

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
        systemPrompt: 'You are a culinary expert. Provide realistic estimates based on typical recipe patterns.',
      );

      // Clean and parse response
      String cleaned = _cleanJsonResponse(response);

      final Map<String, dynamic> estimates = jsonDecode(cleaned);

      // Apply estimates only if missing
      final updatedServings = recipe.servings ?? estimates['estimatedServings'] as int?;
      final updatedTime = recipe.readyInMinutes ?? estimates['estimatedMinutes'] as int?;

      print('✅ Estimated - Servings: $updatedServings, Time: $updatedTime min');
      print('   Reasoning: ${estimates['reasoning']}');

      // Create updated recipe with estimates
      return RecipeDetail.fromJson({
        ...recipe.toJson(),
        'servings': updatedServings,
        'readyInMinutes': updatedTime,
      });
    } catch (e) {
      print('⚠️ Could not estimate missing info: $e');
      // Return original recipe if estimation fails
      return recipe;
    }
  }

  // ============================================================================
  // HELPER METHODS
  // ============================================================================

  /// Clean JSON response from AI - removes markdown blocks and extracts JSON
  String _cleanJsonResponse(String response) {
    String cleaned = response.trim();

    // Remove markdown code blocks
    if (cleaned.startsWith('```json')) {
      cleaned = cleaned.substring(7);
    } else if (cleaned.startsWith('```')) {
      cleaned = cleaned.substring(3);
    }

    if (cleaned.endsWith('```')) {
      cleaned = cleaned.substring(0, cleaned.length - 3);
    }

    cleaned = cleaned.trim();

    // Try to find JSON object or array in the response
    // This handles cases where AI adds explanation text before/after JSON
    final jsonObjectStart = cleaned.indexOf('{');
    final jsonArrayStart = cleaned.indexOf('[');

    if (jsonObjectStart == -1 && jsonArrayStart == -1) {
      // No JSON found, return as-is (will fail at parsing)
      return cleaned;
    }

    // Determine which comes first - object or array
    int startIndex;
    String endChar;

    if (jsonObjectStart != -1 &&
        (jsonArrayStart == -1 || jsonObjectStart < jsonArrayStart)) {
      startIndex = jsonObjectStart;
      endChar = '}';
    } else {
      startIndex = jsonArrayStart;
      endChar = ']';
    }

    // Find the matching end bracket
    int depth = 0;
    int endIndex = startIndex;
    final startChar = endChar == '}' ? '{' : '[';

    for (int i = startIndex; i < cleaned.length; i++) {
      if (cleaned[i] == startChar) {
        depth++;
      } else if (cleaned[i] == endChar) {
        depth--;
        if (depth == 0) {
          endIndex = i;
          break;
        }
      }
    }

    if (endIndex > startIndex) {
      cleaned = cleaned.substring(startIndex, endIndex + 1);
    }

    return cleaned.trim();
  }

  /// Detect the platform from URL
  RecipePlatform detectPlatform(String url) {
    final lowerUrl = url.toLowerCase();

    if (lowerUrl.contains('tiktok.com')) {
      return RecipePlatform.tiktok;
    } else if (lowerUrl.contains('instagram.com')) {
      return RecipePlatform.instagram;
    } else if (lowerUrl.contains('youtube.com') || lowerUrl.contains('youtu.be')) {
      return RecipePlatform.youtube;
    } else if (lowerUrl.contains('pinterest.com')) {
      return RecipePlatform.pinterest;
    } else {
      return RecipePlatform.other;
    }
  }

  /// Get platform display name
  String getPlatformName(RecipePlatform platform) {
    switch (platform) {
      case RecipePlatform.tiktok:
        return 'TikTok';
      case RecipePlatform.instagram:
        return 'Instagram';
      case RecipePlatform.youtube:
        return 'YouTube';
      case RecipePlatform.pinterest:
        return 'Pinterest';
      case RecipePlatform.other:
        return 'Web';
    }
  }

  /// Get platform icon
  String getPlatformIcon(RecipePlatform platform) {
    switch (platform) {
      case RecipePlatform.tiktok:
        return '🎵';
      case RecipePlatform.instagram:
        return '📷';
      case RecipePlatform.youtube:
        return '▶️';
      case RecipePlatform.pinterest:
        return '📌';
      case RecipePlatform.other:
        return '🌐';
    }
  }

  // ============================================================================
  // VALIDATION
  // ============================================================================

  /// Validate if text contains recipe-like content
  Future<bool> looksLikeRecipe(String text) async {
    if (text.trim().length < 20) return false;

    // Simple heuristics
    final lowerText = text.toLowerCase();
    final hasIngredientKeywords = lowerText.contains('cup') ||
        lowerText.contains('tbsp') ||
        lowerText.contains('tsp') ||
        lowerText.contains('oz') ||
        lowerText.contains('lb') ||
        lowerText.contains('gram') ||
        lowerText.contains('ingredient');

    final hasInstructionKeywords = lowerText.contains('cook') ||
        lowerText.contains('bake') ||
        lowerText.contains('mix') ||
        lowerText.contains('add') ||
        lowerText.contains('heat') ||
        lowerText.contains('step') ||
        lowerText.contains('instruction');

    return hasIngredientKeywords || hasInstructionKeywords;
  }
}

/// Recipe platform sources
enum RecipePlatform {
  tiktok,
  instagram,
  youtube,
  pinterest,
  other,
}

/// Global singleton instance
final recipeExtractionService = RecipeExtractionService();
