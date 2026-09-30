import 'package:budget_accounting_system/src/domain/models/budget_member_profile.dart';
import 'package:budget_accounting_system/src/domain/models/domain_types.dart';
import 'package:budget_accounting_system/src/presentation/screens/budget_members_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/onboarding_fakes.dart';

void main() {
  BudgetMemberProfile member(String id, String name, MemberRole role) {
    return BudgetMemberProfile(
      userId: id,
      name: name,
      role: role,
      joinedAt: DateTime(2026, 1, 1),
      revokedAt: null,
    );
  }

  testWidgets('OWNER can change another member role', (tester) async {
    final memberships = FakeMembershipRepository(
      membersByBudget: {
        'budget-1': [
          member('owner-1', 'Owner', MemberRole.owner),
          member('user-2', 'Bob', MemberRole.editor),
        ],
      },
    );
    final services = fakeAppServices(
      repository: FakeBudgetRepository(),
      sessionStore: FakeSessionStore(currentUserId: 'owner-1'),
      membershipRepository: memberships,
      authorization: FakeBudgetAuthorizationGuard(
        userId: 'owner-1',
        role: MemberRole.owner,
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BudgetMembersScreen(services: services, budgetId: 'budget-1'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final dropdown = find.byKey(const ValueKey('member-role-user-2'));
    expect(dropdown, findsOneWidget);

    await tester.tap(dropdown);
    await tester.pumpAndSettle();
    await tester.tap(find.text('VIEWER').last);
    await tester.pumpAndSettle();

    expect(
      memberships
          .snapshot('budget-1')
          .singleWhere((item) => item.userId == 'user-2')
          .role,
      MemberRole.viewer,
    );
  });

  testWidgets('VIEWER sees roles without management controls', (tester) async {
    final memberships = FakeMembershipRepository(
      membersByBudget: {
        'budget-1': [member('viewer-1', 'Viewer', MemberRole.viewer)],
      },
    );
    final services = fakeAppServices(
      repository: FakeBudgetRepository(),
      sessionStore: FakeSessionStore(currentUserId: 'viewer-1'),
      membershipRepository: memberships,
      authorization: FakeBudgetAuthorizationGuard(
        userId: 'viewer-1',
        role: MemberRole.viewer,
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BudgetMembersScreen(services: services, budgetId: 'budget-1'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('member-role-viewer-1')), findsNothing);
    expect(find.text('VIEWER'), findsOneWidget);
  });
}
