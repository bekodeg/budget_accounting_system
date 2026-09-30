import '../../domain/models/domain_types.dart';
import '../../domain/models/report_export.dart';
import '../../domain/models/report_filter.dart';
import '../../domain/repositories/report_export_repository.dart';
import '../dal/transaction_dao.dart';

final class DriftReportExportRepository implements ReportExportRepository {
  const DriftReportExportRepository(this._transactions);

  final TransactionDao _transactions;

  @override
  Future<List<ReportExportTransaction>> listTransactions(
    ReportFilter filter,
  ) async {
    final rows = await _transactions.getForReport(
      budgetId: filter.budgetId,
      fromInclusive: filter.fromInclusive,
      toExclusive: filter.toExclusive,
      categoryIds: filter.categoryIds,
      accountIds: filter.accountIds,
      authorIds: filter.authorIds,
    );

    return rows
        .map(
          (row) => ReportExportTransaction(
            id: row.id,
            occurredAt: row.occurredAt,
            amountMinor: row.amountMinor,
            currency: row.currency,
            type: _typeFromStorage(row.type),
            authorId: row.authorId,
            accountId: row.accountId,
            destinationAccountId: row.destinationAccountId,
            categoryId: row.categoryId,
            description: row.description,
          ),
        )
        .toList(growable: false);
  }
}

TransactionType _typeFromStorage(String value) {
  return switch (value) {
    'INCOME' => TransactionType.income,
    'EXPENSE' => TransactionType.expense,
    'TRANSFER' => TransactionType.transfer,
    _ => throw StateError('Unsupported transaction type: $value'),
  };
}
