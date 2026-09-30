import 'package:budget_accounting_system/src/domain/models/budget_member_profile.dart';
import 'package:budget_accounting_system/src/domain/models/domain_types.dart';
import 'package:budget_accounting_system/src/presentation/screens/budget_members_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../support/onboarding_fakes.dart';

void main() {
  testWidgets('OWNER creates EDITOR invite and sees QR', (tester) async {
    final memberships = FakeMembershipRepository(
      membersByBudget: {
        'budget-1': [
          BudgetMemberProfile(
            userId: 'user-1',
            name: 'Owner',
            role: MemberRole.owner,
            joinedAt: DateTime(2026, 1, 1),
            revokedAt: null,
          ),
        ],
      },
    );
    final services = fakeAppServices(
      repository: FakeBudgetRepository(),
      sessionStore: FakeSessionStore(currentUserId: 'user-1'),
      membershipRepository: memberships,
      authorization: FakeBudgetAuthorizationGuard(
        userId: 'user-1',
        role: MemberRole.owner,
      ),
      idGenerator: FakeIdGenerator([
        'device-owner',
        'invite-1',
      ]),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BudgetMembersScreen(
            services: services,
            budgetId: 'budget-1',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('create-budget-invite')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('invite-role-editor')));
    await tester.pumpAndSettle();

    expect(find.byType(QrImageView), findsOneWidget);
    expect(find.text('Роль: EDITOR'), findsOneWidget);
  });

  testWidgets('VIEWER cannot create invite but can import one', (tester) async {
    final memberships = FakeMembershipRepository(
      membersByBudget: {
        'budget-1': [
          BudgetMemberProfile(
            userId: 'viewer-1',
            name: 'Viewer',
            role: MemberRole.viewer,
            joinedAt: DateTime(2026, 1, 1),
            revokedAt: null,
          ),
        ],
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
          body: BudgetMembersScreen(
            services: services,
            budgetId: 'budget-1',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('create-budget-invite')), findsNothing);
    expect(
      find.byKey(const ValueKey('scan-budget-invite')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('import-budget-invite-file')),
      findsOneWidget,
    );
  });
}
