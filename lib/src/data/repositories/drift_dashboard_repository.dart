import '../../domain/models/dashboard_summary.dart';
import '../../domain/repositories/dashboard_repository.dart';
import '../dal/report_dao.dart';

final class DriftDashboardRepository implements DashboardRepository {
  const DriftDashboardRepository(this._reports);

  final ReportDao _reports;

  @override
  Stream<DashboardSummary> watchSummary({
    required String budgetId,
    required DateTime monthStart,
  }) {
    final nextMonth = DateTime(monthStart.year, monthStart.month + 1);
    return _reports
        .watchDashboardMetrics(
          budgetId: budgetId,
          fromInclusive: monthStart,
          toExclusive: nextMonth,
        )
        .map((metrics) {
          final income = <String, BigInt>{};
          final expense = <String, BigInt>{};
          final balance = <String, BigInt>{};

          for (final metric in metrics) {
            switch (metric.metric) {
              case 'INCOME':
                income[metric.currency] = metric.amountMinor;
              case 'EXPENSE':
                expense[metric.currency] = metric.amountMinor;
              case 'BALANCE':
                balance[metric.currency] = metric.amountMinor;
              default:
                throw StateError(
                  'Unsupported dashboard metric: ${metric.metric}',
                );
            }
          }

          return DashboardSummary(
            monthStart: monthStart,
            incomeMinorByCurrency: income,
            expenseMinorByCurrency: expense,
            balanceMinorByCurrency: balance,
          );
        });
  }
}
