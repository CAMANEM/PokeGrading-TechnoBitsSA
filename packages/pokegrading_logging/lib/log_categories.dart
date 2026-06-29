/// Structured log categories used across all PokéGrading layers.
enum LogCategory {
  operational('operational'),
  audit('audit'),
  grading('grading'),
  metric('metric');

  const LogCategory(this.value);

  final String value;
}
