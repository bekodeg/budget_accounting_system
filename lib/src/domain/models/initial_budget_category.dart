import 'domain_types.dart';

final class InitialBudgetCategory {
  const InitialBudgetCategory({
    required this.id,
    required this.name,
    required this.kind,
  });

  final String id;
  final String name;
  final CategoryKind kind;
}
