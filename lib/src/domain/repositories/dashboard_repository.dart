import '../models/dashboard_summary.dart';

abstract interface class DashboardRepository {
  Stream<DashboardSummary> watchSummary({
    required String budgetId,
    required DateTime monthStart,
  });
}
