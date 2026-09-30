import '../../domain/models/year_report.dart';
import '../../domain/repositories/extended_report_repository.dart';

final class WatchYearReport {
  const WatchYearReport(this._repository);

  final ExtendedReportRepository _repository;

  Stream<YearReport> call({required String budgetId, required int year}) {
    return _repository.watchYearReport(budgetId: budgetId, year: year);
  }
}
