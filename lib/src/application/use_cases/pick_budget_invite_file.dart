import '../ports/invite_file_gateway.dart';

final class PickBudgetInviteFile {
  const PickBudgetInviteFile(this._gateway);

  final InviteFileGateway _gateway;

  Future<String?> call() => _gateway.pick();
}
