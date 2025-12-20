class InstructionStep {
  final int number;
  final String step;

  InstructionStep({
    required this.number,
    required this.step,
  });

  factory InstructionStep.fromJson(Map<String, dynamic> json) {
    return InstructionStep(
      number: json['number'] ?? 0,
      step: json['step'] ?? '',
    );
  }
}
