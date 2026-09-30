final class ReportFilter {
  ReportFilter({
    required this.budgetId,
    required this.fromInclusive,
    required this.toExclusive,
    Set<String> categoryIds = const {},
    Set<String> accountIds = const {},
    Set<String> authorIds = const {},
  }) : categoryIds = Set.unmodifiable(categoryIds),
       accountIds = Set.unmodifiable(accountIds),
       authorIds = Set.unmodifiable(authorIds) {
    if (!fromInclusive.isBefore(toExclusive)) {
      throw ArgumentError.value(
        toExclusive,
        'toExclusive',
        'Report period must satisfy fromInclusive < toExclusive.',
      );
    }
  }

  final String budgetId;
  final DateTime fromInclusive;
  final DateTime toExclusive;
  final Set<String> categoryIds;
  final Set<String> accountIds;
  final Set<String> authorIds;

  bool get hasFilters =>
      categoryIds.isNotEmpty || accountIds.isNotEmpty || authorIds.isNotEmpty;
}
