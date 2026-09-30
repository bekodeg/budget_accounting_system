import '../models/period_report.dart';
import '../models/report_filter.dart';
import '../models/year_report.dart';

abstract interface class ExtendedReportRepository {
  Stream<PeriodReport> watchPeriodReport(ReportFilter filter);

  Stream<YearReport> watchYearReport({
    required String budgetId,
    required int year,
  });
}
