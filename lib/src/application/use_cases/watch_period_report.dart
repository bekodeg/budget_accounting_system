import '../../domain/models/period_report.dart';
import '../../domain/models/report_filter.dart';
import '../../domain/repositories/extended_report_repository.dart';

final class WatchPeriodReport {
  const WatchPeriodReport(this._repository);

  final ExtendedReportRepository _repository;

  Stream<PeriodReport> call(ReportFilter filter) {
    return _repository.watchPeriodReport(filter);
  }
}
