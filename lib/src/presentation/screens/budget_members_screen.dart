import 'package:flutter/material.dart';

import '../../application/app_services.dart';
import '../../application/authorization/budget_action.dart';
import '../../application/errors/authorization_error.dart';
import '../../domain/models/budget_member_profile.dart';
import '../../domain/models/domain_types.dart';
import 'budget_invite_panel.dart';

final class BudgetMembersScreen extends StatelessWidget {
  const BudgetMembersScreen({
    required this.services,
    required this.budgetId,
    super.key,
  });

  final AppServices services;
  final String budgetId;

  Future<void> _changeRole(
    BuildContext context,
    BudgetMemberProfile member,
    MemberRole role,
  ) async {
    try {
      await services.updateMemberRole(
        budgetId: budgetId,
        userId: member.userId,
        role: role,
      );
    } on AuthorizationError catch (error) {
      if (context.mounted) {
        _showMessage(context, error.message);
      }
    } on Object {
      if (context.mounted) {
        _showMessage(context, 'Не удалось изменить роль участника.');
      }
    }
  }

  void _showMessage(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<BudgetMemberProfile>>(
      stream: services.watchBudgetMembers(budgetId),
      builder: (context, memberSnapshot) {
        if (memberSnapshot.hasError) {
          return const Center(child: Text('Не удалось загрузить участников.'));
        }
        if (!memberSnapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        return FutureBuilder<bool>(
          future: services.canPerformBudgetAction(
            budgetId: budgetId,
            action: BudgetAction.manageMembers,
          ),
          builder: (context, permissionSnapshot) {
            final canManage = permissionSnapshot.data ?? false;
            final members = memberSnapshot.data!;

            return ListView(
              key: const ValueKey('budget-members-screen'),
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  'Участники бюджета',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                const Text(
                  'OWNER управляет участниками, EDITOR изменяет бюджетные '
                  'данные, VIEWER имеет доступ только на чтение и экспорт.',
                ),
                const SizedBox(height: 16),
                BudgetInvitePanel(
                  services: services,
                  budgetId: budgetId,
                  canCreate: canManage,
                ),
                const SizedBox(height: 16),
                for (final member in members)
                  ListTile(
                    key: ValueKey('budget-member-${member.userId}'),
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.person_outline),
                    title: Text(member.name),
                    subtitle: Text(member.userId),
                    trailing: canManage
                        ? DropdownButton<MemberRole>(
                            key: ValueKey('member-role-${member.userId}'),
                            value: member.role,
                            items: [
                              for (final role in MemberRole.values)
                                DropdownMenuItem(
                                  value: role,
                                  child: Text(_roleLabel(role)),
                                ),
                            ],
                            onChanged: (role) {
                              if (role != null && role != member.role) {
                                _changeRole(context, member, role);
                              }
                            },
                          )
                        : Chip(label: Text(_roleLabel(member.role))),
                  ),
              ],
            );
          },
        );
      },
    );
  }
}

String _roleLabel(MemberRole role) {
  return switch (role) {
    MemberRole.owner => 'OWNER',
    MemberRole.editor => 'EDITOR',
    MemberRole.viewer => 'VIEWER',
  };
}
