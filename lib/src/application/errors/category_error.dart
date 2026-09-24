enum CategoryErrorCode {
  emptyName,
}

final class CategoryError implements Exception {
  const CategoryError({
    required this.code,
    required this.message,
  });

  final CategoryErrorCode code;
  final String message;

  @override
  String toString() => 'CategoryError($code): $message';
}
