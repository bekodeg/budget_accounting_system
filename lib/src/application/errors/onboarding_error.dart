enum OnboardingErrorCode {
  emptyUserName,
  emptyBudgetName,
  inaccessibleBudget,
}

final class OnboardingError implements Exception {
  const OnboardingError({
    required this.code,
    required this.message,
  });

  final OnboardingErrorCode code;
  final String message;

  @override
  String toString() => 'OnboardingError($code): $message';
}
