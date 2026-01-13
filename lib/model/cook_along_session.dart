import 'package:meal_palette/model/detailed_recipe_model.dart';
import 'package:meal_palette/model/instruction_step_model.dart';

/// Represents the current state of a Cook Along session
class CookAlongSession {
  final RecipeDetail recipe;
  int currentStepIndex;
  final List<StepTimer> activeTimers;
  final List<ChatMessage> conversationHistory;
  final DateTime startedAt;
  bool isPaused;
  bool isCompleted;
  final List<String> checkedIngredients;

  CookAlongSession({
    required this.recipe,
    this.currentStepIndex = 0,
    List<StepTimer>? activeTimers,
    List<ChatMessage>? conversationHistory,
    DateTime? startedAt,
    this.isPaused = false,
    this.isCompleted = false,
    List<String>? checkedIngredients,
  })  : activeTimers = activeTimers ?? [],
        conversationHistory = conversationHistory ?? [],
        startedAt = startedAt ?? DateTime.now(),
        checkedIngredients = checkedIngredients ?? [];

  InstructionStep? get currentStep {
    if (recipe.instructions.isEmpty) return null;
    if (currentStepIndex >= recipe.instructions.length || currentStepIndex < 0) {
      return null;
    }
    return recipe.instructions[currentStepIndex];
  }

  int get totalSteps {
    return recipe.instructions.length;
  }

  bool get hasNextStep => currentStepIndex < totalSteps - 1;
  bool get hasPreviousStep => currentStepIndex > 0;

  double get progress {
    if (totalSteps == 0) return 0.0;
    return (currentStepIndex + 1) / totalSteps;
  }

  /// Get all active (not completed/cancelled) timers
  List<StepTimer> get runningTimers =>
      activeTimers.where((t) => t.status == TimerStatus.running).toList();

  /// Get all paused timers
  List<StepTimer> get pausedTimers =>
      activeTimers.where((t) => t.status == TimerStatus.paused).toList();

  CookAlongSession copyWith({
    RecipeDetail? recipe,
    int? currentStepIndex,
    List<StepTimer>? activeTimers,
    List<ChatMessage>? conversationHistory,
    DateTime? startedAt,
    bool? isPaused,
    bool? isCompleted,
    List<String>? checkedIngredients,
  }) {
    return CookAlongSession(
      recipe: recipe ?? this.recipe,
      currentStepIndex: currentStepIndex ?? this.currentStepIndex,
      activeTimers: activeTimers ?? this.activeTimers,
      conversationHistory: conversationHistory ?? this.conversationHistory,
      startedAt: startedAt ?? this.startedAt,
      isPaused: isPaused ?? this.isPaused,
      isCompleted: isCompleted ?? this.isCompleted,
      checkedIngredients: checkedIngredients ?? this.checkedIngredients,
    );
  }
}

/// Represents a timer for a cooking step
class StepTimer {
  final String id;
  final int stepNumber;
  final Duration duration;
  final DateTime startedAt;
  DateTime? pausedAt;
  Duration? pausedDuration;
  TimerStatus status;
  final String description;

  StepTimer({
    required this.id,
    required this.stepNumber,
    required this.duration,
    DateTime? startedAt,
    this.pausedAt,
    this.pausedDuration,
    this.status = TimerStatus.running,
    required this.description,
  }) : startedAt = startedAt ?? DateTime.now();

  /// Get remaining time
  Duration get remaining {
    if (status == TimerStatus.completed || status == TimerStatus.cancelled) {
      return Duration.zero;
    }

    final now = DateTime.now();
    final elapsed = status == TimerStatus.paused
        ? (pausedAt ?? now).difference(startedAt) -
            (pausedDuration ?? Duration.zero)
        : now.difference(startedAt) - (pausedDuration ?? Duration.zero);

    final remaining = duration - elapsed;
    return remaining.isNegative ? Duration.zero : remaining;
  }

  /// Check if timer has finished
  bool get isFinished => remaining == Duration.zero;

  /// Get progress percentage (0.0 to 1.0)
  double get progress {
    if (duration.inSeconds == 0) return 1.0;
    final elapsed = duration - remaining;
    return (elapsed.inSeconds / duration.inSeconds).clamp(0.0, 1.0);
  }

  void pause() {
    if (status == TimerStatus.running) {
      status = TimerStatus.paused;
      pausedAt = DateTime.now();
    }
  }

  void resume() {
    if (status == TimerStatus.paused && pausedAt != null) {
      final pauseDuration = DateTime.now().difference(pausedAt!);
      pausedDuration = (pausedDuration ?? Duration.zero) + pauseDuration;
      status = TimerStatus.running;
      pausedAt = null;
    }
  }

  void complete() {
    status = TimerStatus.completed;
  }

  void cancel() {
    status = TimerStatus.cancelled;
  }

  StepTimer copyWith({
    String? id,
    int? stepNumber,
    Duration? duration,
    DateTime? startedAt,
    DateTime? pausedAt,
    Duration? pausedDuration,
    TimerStatus? status,
    String? description,
  }) {
    return StepTimer(
      id: id ?? this.id,
      stepNumber: stepNumber ?? this.stepNumber,
      duration: duration ?? this.duration,
      startedAt: startedAt ?? this.startedAt,
      pausedAt: pausedAt ?? this.pausedAt,
      pausedDuration: pausedDuration ?? this.pausedDuration,
      status: status ?? this.status,
      description: description ?? this.description,
    );
  }
}

/// Timer status enum
enum TimerStatus {
  running,
  paused,
  completed,
  cancelled,
}

/// Represents a message in the conversation between user and AI chef
class ChatMessage {
  final String id;
  final String content;
  final ChatMessageRole role;
  final DateTime timestamp;
  final ChatMessageType type;

  ChatMessage({
    required this.id,
    required this.content,
    required this.role,
    DateTime? timestamp,
    this.type = ChatMessageType.text,
  }) : timestamp = timestamp ?? DateTime.now();

  ChatMessage copyWith({
    String? id,
    String? content,
    ChatMessageRole? role,
    DateTime? timestamp,
    ChatMessageType? type,
  }) {
    return ChatMessage(
      id: id ?? this.id,
      content: content ?? this.content,
      role: role ?? this.role,
      timestamp: timestamp ?? this.timestamp,
      type: type ?? this.type,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'content': content,
      'role': role.toString().split('.').last,
      'timestamp': timestamp.toIso8601String(),
      'type': type.toString().split('.').last,
    };
  }

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: json['id'] as String,
      content: json['content'] as String,
      role: ChatMessageRole.values.firstWhere(
        (e) => e.toString().split('.').last == json['role'],
      ),
      timestamp: DateTime.parse(json['timestamp'] as String),
      type: ChatMessageType.values.firstWhere(
        (e) => e.toString().split('.').last == json['type'],
        orElse: () => ChatMessageType.text,
      ),
    );
  }
}

/// Message role (user or assistant)
enum ChatMessageRole {
  user,
  assistant,
  system,
}

/// Message type
enum ChatMessageType {
  text,
  stepNavigation,
  timerAlert,
  systemNotification,
}

/// Voice command types
enum VoiceCommand {
  next,
  repeat,
  back,
  pause,
  resume,
  help,
  stopListening,
  start,
  complete,
  exit,
  unknown,
}

/// Equipment item needed for cooking
class EquipmentItem {
  final String name;
  final String? imageUrl;
  bool isChecked;

  EquipmentItem({
    required this.name,
    this.imageUrl,
    this.isChecked = false,
  });

  EquipmentItem copyWith({
    String? name,
    String? imageUrl,
    bool? isChecked,
  }) {
    return EquipmentItem(
      name: name ?? this.name,
      imageUrl: imageUrl ?? this.imageUrl,
      isChecked: isChecked ?? this.isChecked,
    );
  }
}
