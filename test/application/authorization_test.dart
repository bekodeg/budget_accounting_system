import 'package:budget_accounting_system/src/application/authorization/budget_action.dart';
import 'package:budget_accounting_system/src/application/errors/authorization_error.dart';
import 'package:budget_accounting_system/src/application/use_cases/authorize_budget_action.dart';
import 'package:budget_accounting_system/src/application/use_cases/update_member_role.dart';
import 'package:budget_accounting_system/src/domain/models/budget_member_profile.dart';
import 'package:budget_accounting_system/src/domain/models/domain_types.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/onboarding_fakes.dart';

void main() {
  BudgetMemberProfile member(String id, MemberRole role) {
    return BudgetMemberProfile(
      userId: id,
      name: id,
      role: role,
      joinedAt: DateTime(2026, 1, 1),
      revokedAt: null,
    );
  }

  AuthorizeBudgetAction authorizationFor(MemberRole role) {
    return AuthorizeBudgetAction(
      membershipRepository: FakeMembershipRepository(
        membersByBudget: {
          'budget-1': [member('user-1', role)],
        },
      ),
      sessionStore: FakeSessionStore(currentUserId: 'user-1'),
    );
  }

  test('OWNER can read export mutate and manage members', () async {
    final authorization = authorizationFor(MemberRole.owner);

    for (final action in BudgetAction.values) {
      final result = await authorization.require(
        budgetId: 'budget-1',
        action: action,
      );
      expect(result.role, MemberRole.owner);
    }
  });

  test('EDITOR can mutate and export but cannot manage members', () async {
    final authorization = authorizationFor(MemberRole.editor);

    for (final action in [
      BudgetAction.read,
      BudgetAction.export,
      BudgetAction.mutate,
    ]) {
      expect(
        await authorization.require(
          budgetId: 'budget-1',
          action: action,
        ),
        isA<BudgetMemberProfile>(),
      );
    }

    await expectLater(
      authorization.require(
        budgetId: 'budget-1',
        action: BudgetAction.manageMembers,
      ),
      throwsA(
        isA<AuthorizationError>().having(
          (error) => error.code,
          'code',
          AuthorizationErrorCode.forbidden,
        ),
      ),
    );
  });

  test('VIEWER can read and export but cannot mutate', () async {
    final authorization = authorizationFor(MemberRole.viewer);

    await authorization.require(
      budgetId: 'budget-1',
      action: BudgetAction.read,
    );
    await authorization.require(
      budgetId: 'budget-1',
      action: BudgetAction.export,
    );

    for (final action in [
      BudgetAction.mutate,
      BudgetAction.manageMembers,
    ]) {
      await expectLater(
        authorization.require(budgetId: 'budget-1', action: action),
        throwsA(
          isA<AuthorizationError>().having(
            (error) => error.code,
            'code',
            AuthorizationErrorCode.forbidden,
          ),
        ),
      );
    }
  });

  test('non-member gets typed notMember error', () async {
    final authorization = AuthorizeBudgetAction(
      membershipRepository: FakeMembershipRepository(),
      sessionStore: FakeSessionStore(currentUserId: 'user-1'),
    );

    await expectLater(
      authorization.require(
        budgetId: 'budget-1',
        action: BudgetAction.read,
      ),
      throwsA(
        isA<AuthorizationError>().having(
          (error) => error.code,
          'code',
          AuthorizationErrorCode.notMember,
        ),
      ),
    );
  });

  test('last OWNER cannot be demoted', () async {
    final repository = FakeMembershipRepository(
      membersByBudget: {
        'budget-1': [
          member('owner-1', MemberRole.owner),
          member('viewer-1', MemberRole.viewer),
        ],
      },
    );
    final useCase = UpdateMemberRole(
      membershipRepository: repository,
      authorization: FakeBudgetAuthorizationGuard(userId: 'owner-1'),
    );

    await expectLater(
      useCase(
        budgetId: 'budget-1',
        userId: 'owner-1',
        role: MemberRole.editor,
      ),
      throwsA(
        isA<AuthorizationError>().having(
          (error) => error.code,
          'code',
          AuthorizationErrorCode.lastOwner,
        ),
      ),
    );
  });

  test('OWNER can demote one owner when another active owner remains', () async {
    final repository = FakeMembershipRepository(
      membersByBudget: {
        'budget-1': [
          member('owner-1', MemberRole.owner),
          member('owner-2', MemberRole.owner),
        ],
      },
    );
    final useCase = UpdateMemberRole(
      membershipRepository: repository,
      authorization: FakeBudgetAuthorizationGuard(userId: 'owner-1'),
    );

    await useCase(
      budgetId: 'budget-1',
      userId: 'owner-2',
      role: MemberRole.editor,
    );

    expect(
      repository.snapshot('budget-1')
          .singleWhere((member) => member.userId == 'owner-2')
          .role,
      MemberRole.editor,
    );
  });
}
