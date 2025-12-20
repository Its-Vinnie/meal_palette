class InstructionStep {
  final int number;
  final String step;

  InstructionStep({
    required this.number,
    required this.step,
  });

  /// Creates InstructionStep from JSON
  factory InstructionStep.fromJson(Map<String, dynamic> json) {
    return InstructionStep(
      number: json['number'] ?? 0,
      step: json['step'] ?? '',
    );
  }

  /// Converts InstructionStep to Map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'number': number,
      'step': step,
    };
  }
}