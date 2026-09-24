import 'domain_types.dart';

final class CategoryTemplate {
  const CategoryTemplate({
    required this.code,
    required this.name,
    required this.kind,
    required this.sortOrder,
  });

  final String code;
  final String name;
  final CategoryKind kind;
  final int sortOrder;
}
