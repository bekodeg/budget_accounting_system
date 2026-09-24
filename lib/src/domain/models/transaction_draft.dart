import '../errors/domain_validation_error.dart';
import '../value_objects/currency.dart';
import '../value_objects/money.dart';
import 'domain_types.dart';

final class TransactionDraft {
  TransactionDraft({
    required this.type,
    required this.amount,
    required this.accountId,
    required Currency accountCurrency,
    this.destinationAccountId,
    Currency? destinationAccountCurrency,
    this.categoryId,
    this.description,
  }) {
    if (amount.currency != accountCurrency) {
      throw const DomainValidationError(
        code: DomainValidationCode.currencyMismatch,
        message: 'Transaction currency must match the source account currency.',
      );
    }

    switch (type) {
      case TransactionType.transfer:
        final destinationId = destinationAccountId;
        if (destinationId == null || destinationId.isEmpty) {
          throw const DomainValidationError(
            code: DomainValidationCode.missingDestinationAccount,
            message: 'Transfer requires a destination account.',
          );
        }
        if (destinationId == accountId) {
          throw const DomainValidationError(
            code: DomainValidationCode.sameTransferAccount,
            message: 'Transfer source and destination accounts must differ.',
          );
        }
        final destinationCurrency = destinationAccountCurrency;
        if (destinationCurrency == null ||
            destinationCurrency != amount.currency) {
          throw const DomainValidationError(
            code: DomainValidationCode.currencyMismatch,
            message: 'Cross-currency transfers are not supported in the current version.',
          );
        }
        break;
      case TransactionType.income:
      case TransactionType.expense:
        if (destinationAccountId != null) {
          throw const DomainValidationError(
            code: DomainValidationCode.unexpectedDestinationAccount,
            message: 'Income and expense transactions cannot have a destination account.',
          );
        }
    }
  }

  final TransactionType type;
  final Money amount;
  final String accountId;
  final String? destinationAccountId;
  final String? categoryId;
  final String? description;
}
