import 'package:drift/drift.dart';

import '../../domain/models/budget_invite.dart';
import '../../domain/models/budget_summary.dart';
import '../../domain/models/public_identity.dart';
import '../../domain/repositories/invitation_repository.dart';
import '../dal/user_budget_dao.dart';
import '../database/app_database.dart';

final class DriftInvitationRepository implements InvitationRepository {
  const DriftInvitationRepository(this._dao);

  final UserBudgetDao _dao;

  @override
  Future<BudgetSummary?> findBudget(String budgetId) async {
    final budget = await _dao.findBudgetById(budgetId);
    if (budget == null) return null;
    return BudgetSummary(
      id: budget.id,
      name: budget.name,
      baseCurrency: budget.baseCurrency,
    );
  }

  @override
  Future<void> acceptInvite({
    required BudgetInvite invite,
    required PublicIdentity joiningIdentity,
  }) {
    return _dao.acceptInvitation(
      owner: UsersCompanion.insert(
        id: invite.ownerUserId,
        name: invite.ownerName,
        publicKey: invite.ownerPublicKey,
      ),
      ownerDevice: DevicesCompanion.insert(
        id: invite.ownerDeviceId,
        userId: invite.ownerUserId,
      ),
      budget: BudgetsCompanion.insert(
        id: invite.budgetId,
        name: invite.budgetName,
        baseCurrency: invite.baseCurrency,
        createdBy: invite.ownerUserId,
      ),
      ownerMembership: BudgetMembersCompanion.insert(
        budgetId: invite.budgetId,
        userId: invite.ownerUserId,
        role: 'OWNER',
        revokedAt: const Value(null),
      ),
      joiningMembership: BudgetMembersCompanion.insert(
        budgetId: invite.budgetId,
        userId: joiningIdentity.userId,
        role: _role(invite),
        revokedAt: const Value(null),
      ),
      joiningPublicKey: joiningIdentity.publicKey,
    );
  }
  @override
  Future<void> acceptInviteForNewIdentity({
    required BudgetInvite invite,
    required String joiningUserName,
    required PublicIdentity joiningIdentity,
  }) {
    return _dao.acceptInvitationForNewIdentity(
      owner: UsersCompanion.insert(
        id: invite.ownerUserId,
        name: invite.ownerName,
        publicKey: invite.ownerPublicKey,
      ),
      ownerDevice: DevicesCompanion.insert(
        id: invite.ownerDeviceId,
        userId: invite.ownerUserId,
      ),
      joiningUser: UsersCompanion.insert(
        id: joiningIdentity.userId,
        name: joiningUserName,
        publicKey: joiningIdentity.publicKey,
      ),
      joiningDevice: DevicesCompanion.insert(
        id: joiningIdentity.deviceId,
        userId: joiningIdentity.userId,
      ),
      budget: BudgetsCompanion.insert(
        id: invite.budgetId,
        name: invite.budgetName,
        baseCurrency: invite.baseCurrency,
        createdBy: invite.ownerUserId,
      ),
      ownerMembership: BudgetMembersCompanion.insert(
        budgetId: invite.budgetId,
        userId: invite.ownerUserId,
        role: 'OWNER',
        revokedAt: const Value(null),
      ),
      joiningMembership: BudgetMembersCompanion.insert(
        budgetId: invite.budgetId,
        userId: joiningIdentity.userId,
        role: _role(invite),
        revokedAt: const Value(null),
      ),
    );
  }
}

String _role(BudgetInvite invite) {
  return switch (invite.role.name) {
    'editor' => 'EDITOR',
    'viewer' => 'VIEWER',
    _ => throw StateError('OWNER invitations are not supported.'),
  };
}
