import '../../domain/models/monthly_report.dart';
import '../../domain/repositories/monthly_report_repository.dart';

final class WatchMonthlyReport {
  const WatchMonthlyReport(this._repository);

  final MonthlyReportRepository _repository;

  Stream<MonthlyReport> call({
    required String budgetId,
    required DateTime month,
  }) {
    final monthStart = DateTime(month.year, month.month);
    return _repository.watchMonthlyReport(
      budgetId: budgetId,
      monthStart: monthStart,
    );
  }
}
