import '../../domain/models/dashboard_summary.dart';
import '../../domain/repositories/dashboard_repository.dart';

final class WatchDashboardSummary {
  const WatchDashboardSummary(this._repository);

  final DashboardRepository _repository;

  Stream<DashboardSummary> call({
    required String budgetId,
    required DateTime month,
  }) {
    final monthStart = DateTime(month.year, month.month);
    return _repository.watchSummary(
      budgetId: budgetId,
      monthStart: monthStart,
    );
  }
}
