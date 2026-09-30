import '../../domain/models/budget_invite.dart';
import '../ports/invite_file_gateway.dart';

final class ShareBudgetInviteFile {
  const ShareBudgetInviteFile(this._gateway);

  final InviteFileGateway _gateway;

  Future<void> call(BudgetInvitePreview preview) {
    final safeBudget = preview.invite.budgetName
        .replaceAll(RegExp(r'[^A-Za-z0-9_-]+'), '_')
        .replaceAll(RegExp(r'_+'), '_');
    final fileName =
        'budget-invite-${safeBudget.isEmpty ? preview.invite.budgetId : safeBudget}';
    return _gateway.share(fileName: fileName, payload: preview.rawPayload);
  }
}
