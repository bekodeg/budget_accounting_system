import '../models/monthly_report.dart';

abstract interface class MonthlyReportRepository {
  Stream<MonthlyReport> watchMonthlyReport({
    required String budgetId,
    required DateTime monthStart,
  });
}
