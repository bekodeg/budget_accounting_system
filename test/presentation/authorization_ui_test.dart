import 'package:budget_accounting_system/src/domain/models/budget_member_profile.dart';
import 'package:budget_accounting_system/src/domain/models/domain_types.dart';
import 'package:budget_accounting_system/src/presentation/screens/settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/onboarding_fakes.dart';

void main() {
  testWidgets('VIEWER settings hide mutation controls', (tester) async {
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
          body: SettingsScreen(
            services: services,
            userId: 'viewer-1',
            budgetId: 'budget-1',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('add-account')), findsNothing);

    await tester.tap(find.text('Категории'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('add-category')), findsNothing);

    await tester.tap(find.text('Участники'));
    await tester.pumpAndSettle();
    expect(find.text('VIEWER'), findsOneWidget);
    expect(find.byKey(const ValueKey('member-role-viewer-1')), findsNothing);
  });
}
