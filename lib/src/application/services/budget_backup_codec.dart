import 'dart:convert';

import 'package:cryptography/cryptography.dart';

import '../../domain/models/budget_snapshot.dart';
import '../errors/budget_backup_error.dart';

final class DecodedBudgetBackup {
  const DecodedBudgetBackup({
    required this.sourceBudgetId,
    required this.createdAt,
    required this.snapshot,
  });

  final String sourceBudgetId;
  final DateTime createdAt;
  final BudgetSnapshotPackage snapshot;
}

final class BudgetBackupCodec {
  BudgetBackupCodec({
    Cipher? cipher,
    KdfAlgorithm? kdf,
  }) : _cipher = cipher ?? AesGcm.with256bits(),
       _kdf =
           kdf ??
           Pbkdf2(
             macAlgorithm: Hmac.sha256(),
             iterations: 210000,
             bits: 256,
           );

  static const currentVersion = 1;
  static const kdfName = 'pbkdf2-hmac-sha256';
  static const cipherName = 'aes-256-gcm';

  final Cipher _cipher;
  final KdfAlgorithm _kdf;

  Future<String> encrypt({
    required String password,
    required String sourceBudgetId,
    required BudgetSnapshotPackage snapshot,
  }) async {
    final normalizedPassword = password.trim();
    if (normalizedPassword.length < 8) {
      throw const BudgetBackupError(
        BudgetBackupErrorCode.invalidFormat,
        'Пароль backup должен содержать не менее 8 символов.',
      );
    }

    final salt = Cryptography.instance.randomBytes(16);
    final nonce = _cipher.newNonce();
    final secretKey = await _kdf.deriveKey(
      secretKey: SecretKey(utf8.encode(normalizedPassword)),
      nonce: salt,
    );
    final plaintext = utf8.encode(
      jsonEncode({
        'source_budget_id': sourceBudgetId,
        'snapshot_body': snapshot.bodyJson,
        'snapshot_digest': snapshot.digestBase64,
      }),
    );
    final box = await _cipher.encrypt(
      plaintext,
      secretKey: secretKey,
      nonce: nonce,
      aad: utf8.encode('budget-accounting-backup:v$currentVersion'),
    );

    return jsonEncode({
      'format': 'budget-accounting-backup',
      'v': currentVersion,
      'created_at': DateTime.now().toUtc().toIso8601String(),
      'crypto': {
        'kdf': kdfName,
        'iterations': 210000,
        'salt': base64Url.encode(salt),
        'cipher': cipherName,
        'nonce': base64Url.encode(nonce),
      },
      'ciphertext': base64Url.encode(box.cipherText),
      'mac': base64Url.encode(box.mac.bytes),
    });
  }

  Future<DecodedBudgetBackup> decrypt({
    required String password,
    required String payload,
  }) async {
    Map<String, dynamic> envelope;
    try {
      final decoded = jsonDecode(payload);
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException();
      }
      envelope = decoded;
    } on Object {
      throw const BudgetBackupError(
        BudgetBackupErrorCode.invalidFormat,
        'Файл backup имеет неверный формат.',
      );
    }

    if (envelope['format'] != 'budget-accounting-backup') {
      throw const BudgetBackupError(
        BudgetBackupErrorCode.invalidFormat,
        'Неизвестный формат backup.',
      );
    }
    if (envelope['v'] != currentVersion) {
      throw BudgetBackupError(
        BudgetBackupErrorCode.unsupportedVersion,
        'Неподдерживаемая версия backup: ${envelope['v']}.',
      );
    }

    final crypto = envelope['crypto'];
    if (crypto is! Map<String, dynamic> ||
        crypto['kdf'] != kdfName ||
        crypto['iterations'] != 210000 ||
        crypto['cipher'] != cipherName) {
      throw const BudgetBackupError(
        BudgetBackupErrorCode.invalidFormat,
        'Параметры шифрования backup не поддерживаются.',
      );
    }

    try {
      final salt = base64Url.decode(_string(crypto, 'salt'));
      final nonce = base64Url.decode(_string(crypto, 'nonce'));
      final cipherText = base64Url.decode(_string(envelope, 'ciphertext'));
      final mac = Mac(base64Url.decode(_string(envelope, 'mac')));
      final secretKey = await _kdf.deriveKey(
        secretKey: SecretKey(utf8.encode(password.trim())),
        nonce: salt,
      );
      final clear = await _cipher.decrypt(
        SecretBox(cipherText, nonce: nonce, mac: mac),
        secretKey: secretKey,
        aad: utf8.encode('budget-accounting-backup:v$currentVersion'),
      );
      final content = jsonDecode(utf8.decode(clear));
      if (content is! Map<String, dynamic>) {
        throw const FormatException();
      }

      final sourceBudgetId = _string(content, 'source_budget_id');
      final createdAtRaw = envelope['created_at'];
      final createdAt =
          createdAtRaw is String ? DateTime.tryParse(createdAtRaw) : null;
      if (createdAt == null) {
        throw const FormatException();
      }

      return DecodedBudgetBackup(
        sourceBudgetId: sourceBudgetId,
        createdAt: createdAt.toUtc(),
        snapshot: BudgetSnapshotPackage(
          bodyJson: _string(content, 'snapshot_body'),
          digestBase64: _string(content, 'snapshot_digest'),
        ),
      );
    } on BudgetBackupError {
      rethrow;
    } on Object {
      throw const BudgetBackupError(
        BudgetBackupErrorCode.wrongPasswordOrCorrupted,
        'Неверный пароль или поврежденный backup.',
      );
    }
  }
}

String _string(Map<String, dynamic> value, String key) {
  final result = value[key];
  if (result is! String || result.isEmpty) {
    throw const FormatException();
  }
  return result;
}
