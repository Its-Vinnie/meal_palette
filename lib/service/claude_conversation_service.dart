import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:meal_palette/model/cook_along_session.dart';
import 'package:meal_palette/model/detailed_recipe_model.dart';

/// Service for handling conversational AI interactions using Claude API
class ClaudeConversationService {
  static const String _apiKey ='';
  static const String _apiUrl = 'https://api.anthropic.com/v1/messages';
  static const String _model = 'claude-sonnet-4-20250514';

  /// Send a message to Claude and get a response
  /// [messages] - conversation history
  /// [systemPrompt] - system context for the conversation
  Future<String> sendMessage({
    required List<ChatMessage> messages,
    String? systemPrompt,
  }) async {
    try {
      // Convert ChatMessage to Claude API format
      final apiMessages = messages
          .where((m) => m.role != ChatMessageRole.system)
          .map((m) => {
                'role': m.role == ChatMessageRole.user ? 'user' : 'assistant',
                'content': m.content,
              })
          .toList();

      final requestBody = {
        'model': _model,
        'max_tokens': 1024,
        'messages': apiMessages,
        if (systemPrompt != null) 'system': systemPrompt,
      };

      print('🤖 Sending message to Claude API...');

      final response = await http.post(
        Uri.parse(_apiUrl),
        headers: {
          'Content-Type': 'application/json',
          'x-api-key': _apiKey,
          'anthropic-version': '2023-06-01',
        },
        body: jsonEncode(requestBody),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final content = data['content'][0]['text'] as String;
        print('✅ Received response from Claude');
        return content;
      } else {
        print('❌ Claude API error: ${response.statusCode} - ${response.body}');
        throw Exception(
            'Failed to get response from Claude: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Error in Claude conversation: $e');
      rethrow;
    }
  }

  /// Ask a cooking-related question during a Cook Along session
  Future<String> askCookingQuestion({
    required String question,
    required RecipeDetail recipe,
    required int currentStepNumber,
    List<ChatMessage>? conversationHistory,
  }) async {
    final systemPrompt = _buildCookingSystemPrompt(recipe, currentStepNumber);

    final messages = <ChatMessage>[
      if (conversationHistory != null) ...conversationHistory,
      ChatMessage(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        content: question,
        role: ChatMessageRole.user,
      ),
    ];

    return await sendMessage(
      messages: messages,
      systemPrompt: systemPrompt,
    );
  }

  /// Get an explanation for a cooking technique
  Future<String> explainTechnique(String technique, RecipeDetail recipe) async {
    final systemPrompt =
        '''You are a helpful cooking assistant. Explain cooking techniques in simple, clear language.
Keep explanations concise (2-3 sentences) and practical.''';

    final message = ChatMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      content:
          'Explain how to $technique in the context of cooking ${recipe.title}',
      role: ChatMessageRole.user,
    );

    return await sendMessage(
      messages: [message],
      systemPrompt: systemPrompt,
    );
  }

  /// Suggest ingredient substitutions
  Future<String> suggestSubstitution({
    required String ingredient,
    required RecipeDetail recipe,
  }) async {
    final systemPrompt =
        '''You are a helpful cooking assistant. Suggest practical ingredient substitutions.
Keep suggestions concise and explain how they might affect the dish.''';

    final message = ChatMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      content:
          'I don\'t have $ingredient for ${recipe.title}. What can I use instead?',
      role: ChatMessageRole.user,
    );

    return await sendMessage(
      messages: [message],
      systemPrompt: systemPrompt,
    );
  }

  /// Build system prompt for cooking assistance
  String _buildCookingSystemPrompt(RecipeDetail recipe, int currentStep) {
    final ingredientsList =
        recipe.ingredients.map((i) => '- ${i.original}').join('\n');

    final instructionsList = recipe.instructions
        .asMap()
        .entries
        .map((e) => 'Step ${e.key + 1}: ${e.value.step}')
        .join('\n');

    return '''You are a friendly AI cooking assistant helping someone cook "${recipe.title}".

Recipe Information:
- Ready in: ${recipe.readyInMinutes} minutes
- Servings: ${recipe.servings}
- Dietary: ${_getDietaryInfo(recipe)}

Ingredients:
$ingredientsList

Instructions:
$instructionsList

The user is currently on Step ${currentStep + 1}.

Your role:
- Answer questions clearly and concisely
- Provide helpful cooking tips and explanations
- Suggest substitutions when needed
- Explain techniques in simple terms
- Keep responses conversational and encouraging
- Stay focused on cooking this specific recipe

Keep your responses brief (2-3 sentences unless more detail is specifically requested).''';
  }

  /// Get dietary information as a formatted string
  String _getDietaryInfo(RecipeDetail recipe) {
    final dietary = <String>[];
    if (recipe.vegetarian) dietary.add('Vegetarian');
    if (recipe.vegan) dietary.add('Vegan');
    if (recipe.glutenFree) dietary.add('Gluten-Free');
    if (recipe.dairyFree) dietary.add('Dairy-Free');
    return dietary.isEmpty ? 'None specified' : dietary.join(', ');
  }

  /// Generate a welcome message for starting Cook Along
  String generateWelcomeMessage(RecipeDetail recipe) {
    return '''Welcome to Cook Along Mode! I'm your AI cooking assistant, and I'll help you prepare "${recipe.title}".

This recipe takes about ${recipe.readyInMinutes} minutes and makes ${recipe.servings} servings.

We'll go through ${recipe.instructions.length} steps together. I'll read each step to you, and you can say "next" when you're ready to move on.

Here are the voice commands you can use:
- "Start" to begin cooking
- "Next" to move to the next step
- "Repeat" to hear the current step again
- "Back" to go to the previous step
- "Complete" when you're done

You can also ask me questions at any time, like:
- "How do I do this?"
- "Can I substitute X for Y?"

Just say "Hey Chef" followed by your question!

When you're ready to begin, say "Start" or tap the Start button.''';
  }

  /// Generate a completion message
  String generateCompletionMessage(RecipeDetail recipe) {
    return '''Congratulations! You've completed cooking "${recipe.title}"!

I hope it turns out delicious. Enjoy your meal!

Would you like to save any notes about how it went, or do you have any questions about the recipe?''';
  }
}

/// Global singleton instance
final claudeConversationService = ClaudeConversationService();
