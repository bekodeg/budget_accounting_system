import 'dart:collection';
import 'dart:convert';
import 'dart:typed_data';

import '../../domain/models/budget_invite.dart';
import '../../domain/models/domain_types.dart';
import '../errors/invite_error.dart';

final class BudgetInviteCodec {
  const BudgetInviteCodec();

  static const _prefix = 'budgetinvite:';

  String encode(BudgetInvite invite) {
    final json = _canonicalJson(_map(invite, includeSignature: true));
    return '$_prefix${base64Url.encode(utf8.encode(json))}';
  }

  BudgetInvite decode(String raw) {
    try {
      if (!raw.startsWith(_prefix)) {
        throw const InviteError(
          InviteErrorCode.invalidFormat,
          'Неверный формат приглашения.',
        );
      }

      final encoded = raw.substring(_prefix.length);
      final jsonText = utf8.decode(base64Url.decode(encoded));
      final decoded = jsonDecode(jsonText);
      if (decoded is! Map<String, dynamic>) {
        throw const InviteError(
          InviteErrorCode.invalidFormat,
          'Неверный JSON приглашения.',
        );
      }

      final version = decoded['version'];
      if (version != BudgetInvite.currentVersion) {
        throw const InviteError(
          InviteErrorCode.unsupportedVersion,
          'Эта версия приглашения не поддерживается.',
        );
      }

      final budget = _mapValue(decoded, 'budget');
      final owner = _mapValue(decoded, 'owner');
      final crypto = _mapValue(decoded, 'crypto');
      final role = _role(_string(decoded, 'role'));

      return BudgetInvite(
        version: version as int,
        inviteId: _string(decoded, 'invite_id'),
        budgetId: _string(budget, 'id'),
        budgetName: _string(budget, 'name'),
        baseCurrency: _string(budget, 'base_currency'),
        ownerUserId: _string(owner, 'user_id'),
        ownerName: _string(owner, 'name'),
        ownerDeviceId: _string(owner, 'device_id'),
        ownerPublicKey: _string(owner, 'public_key'),
        role: role,
        nonce: _string(decoded, 'nonce'),
        issuedAt: DateTime.parse(_string(decoded, 'issued_at')).toUtc(),
        expiresAt: DateTime.parse(_string(decoded, 'expires_at')).toUtc(),
        crypto: InviteCryptoParameters(
          signatureAlgorithm: _string(crypto, 'signature'),
          kdf: _string(crypto, 'kdf'),
          transportCipher: _string(crypto, 'transport_cipher'),
          salt: _string(crypto, 'salt'),
          bootstrapSecret: _string(crypto, 'bootstrap_secret'),
        ),
        signature: _string(decoded, 'signature'),
      );
    } on InviteError {
      rethrow;
    } on Object {
      throw const InviteError(
        InviteErrorCode.invalidFormat,
        'Не удалось прочитать приглашение.',
      );
    }
  }

  Uint8List unsignedBytes(BudgetInvite invite) {
    final json = _canonicalJson(_map(invite, includeSignature: false));
    return Uint8List.fromList(utf8.encode(json));
  }

  Map<String, Object?> _map(
    BudgetInvite invite, {
    required bool includeSignature,
  }) {
    return {
      'version': invite.version,
      'invite_id': invite.inviteId,
      'budget': {
        'id': invite.budgetId,
        'name': invite.budgetName,
        'base_currency': invite.baseCurrency,
      },
      'owner': {
        'user_id': invite.ownerUserId,
        'name': invite.ownerName,
        'device_id': invite.ownerDeviceId,
        'public_key': invite.ownerPublicKey,
      },
      'role': _roleName(invite.role),
      'nonce': invite.nonce,
      'issued_at': invite.issuedAt.toUtc().toIso8601String(),
      'expires_at': invite.expiresAt.toUtc().toIso8601String(),
      'crypto': {
        'signature': invite.crypto.signatureAlgorithm,
        'kdf': invite.crypto.kdf,
        'transport_cipher': invite.crypto.transportCipher,
        'salt': invite.crypto.salt,
        'bootstrap_secret': invite.crypto.bootstrapSecret,
      },
      if (includeSignature) 'signature': invite.signature,
    };
  }
}

String _canonicalJson(Object? value) {
  Object? sort(Object? current) {
    if (current is Map) {
      final sorted = SplayTreeMap<String, Object?>();
      for (final entry in current.entries) {
        sorted[entry.key.toString()] = sort(entry.value);
      }
      return sorted;
    }
    if (current is List) {
      return current.map(sort).toList(growable: false);
    }
    return current;
  }

  return jsonEncode(sort(value));
}

Map<String, dynamic> _mapValue(Map<String, dynamic> map, String key) {
  final value = map[key];
  if (value is! Map<String, dynamic>) {
    throw const InviteError(
      InviteErrorCode.invalidFormat,
      'В приглашении отсутствует обязательный объект.',
    );
  }
  return value;
}

String _string(Map<String, dynamic> map, String key) {
  final value = map[key];
  if (value is! String || value.isEmpty) {
    throw const InviteError(
      InviteErrorCode.invalidFormat,
      'В приглашении отсутствует обязательное поле.',
    );
  }
  return value;
}

MemberRole _role(String value) {
  return switch (value) {
    'EDITOR' => MemberRole.editor,
    'VIEWER' => MemberRole.viewer,
    _ => throw const InviteError(
      InviteErrorCode.invalidRole,
      'Приглашение может выдавать только роль EDITOR или VIEWER.',
    ),
  };
}

String _roleName(MemberRole role) {
  return switch (role) {
    MemberRole.editor => 'EDITOR',
    MemberRole.viewer => 'VIEWER',
    MemberRole.owner => throw const InviteError(
      InviteErrorCode.invalidRole,
      'Нельзя создать приглашение с ролью OWNER.',
    ),
  };
}
