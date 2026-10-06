import 'dart:async';

import 'package:flutter/material.dart';

import '../../application/app_services.dart';
import '../../application/ports/secure_lan_channel.dart';
import '../../application/services/lan_peer_session_manager.dart';
import '../../domain/models/lan_peer_endpoint.dart';

final class SynchronizationScreen extends StatefulWidget {
  const SynchronizationScreen({
    required this.services,
    required this.userId,
    required this.budgetId,
    super.key,
  });

  final AppServices services;
  final String userId;
  final String budgetId;

  @override
  State<SynchronizationScreen> createState() => _SynchronizationScreenState();
}

final class _SynchronizationScreenState extends State<SynchronizationScreen> {
  final _manualEndpointController = TextEditingController();
  StreamSubscription<List<LanPeerEndpoint>>? _peerSubscription;
  StreamSubscription<SecureLanChannel>? _hostSubscription;
  LanPeerBrowser? _browser;
  LanHostedSession? _hosted;
  List<LanPeerEndpoint> _peers = const [];
  String _status = 'Готово к синхронизации.';
  bool _busy = false;

  bool get _available =>
      widget.services.lanPeerSessions != null &&
      widget.services.syncSessions != null;

  @override
  void dispose() {
    unawaited(_peerSubscription?.cancel());
    unawaited(_hostSubscription?.cancel());
    unawaited(_browser?.close());
    unawaited(_hosted?.close());
    _manualEndpointController.dispose();
    super.dispose();
  }

  Future<String> _localDeviceId() async {
    final identity = await widget.services.getPublicIdentity(widget.userId);
    return identity.deviceId;
  }

  Future<void> _stopNetworkHandles() async {
    await _peerSubscription?.cancel();
    await _hostSubscription?.cancel();
    _peerSubscription = null;
    _hostSubscription = null;
    final browser = _browser;
    _browser = null;
    if (browser != null) await browser.close();
    final hosted = _hosted;
    _hosted = null;
    if (hosted != null) await hosted.close();
  }

  Future<void> _startDiscovery() async {
    if (!_available || _busy) return;
    setState(() {
      _busy = true;
      _status = 'Ищу устройства этого бюджета в локальной сети…';
    });
    try {
      await _stopNetworkHandles();
      final browser = await widget.services.lanPeerSessions!.discover(
        widget.budgetId,
      );
      _browser = browser;
      _peerSubscription = browser.peers.listen((peers) {
        if (!mounted) return;
        setState(() {
          _peers = peers;
          _status = peers.isEmpty
              ? 'Устройства пока не найдены.'
              : 'Найдено устройств: ${peers.length}.';
        });
      });
    } on Object {
      if (mounted) {
        setState(() => _status = 'Не удалось запустить поиск устройств.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _startHost({required bool initial}) async {
    if (!_available || _busy) return;
    setState(() {
      _busy = true;
      _status = initial
          ? 'Ожидаю новое устройство для первичной синхронизации…'
          : 'Ожидаю устройство для обычной синхронизации…';
    });
    try {
      await _stopNetworkHandles();
      final hosted = await widget.services.lanPeerSessions!.host(
        widget.budgetId,
      );
      _hosted = hosted;
      _hostSubscription = hosted.channels.listen((channel) async {
        try {
          final localDeviceId = await _localDeviceId();
          if (initial) {
            final snapshots = widget.services.budgetSnapshotSessions;
            if (snapshots == null) {
              throw StateError('Snapshot service is unavailable.');
            }
            await snapshots.send(channel: channel, budgetId: widget.budgetId);
          }
          await widget.services.syncSessions!.synchronize(
            channel: channel,
            budgetId: widget.budgetId,
            localDeviceId: localDeviceId,
          );
          if (mounted) {
            setState(() => _status = 'Синхронизация завершена.');
          }
        } on Object {
          if (mounted) {
            setState(() => _status = 'Ошибка во время синхронизации.');
          }
        } finally {
          await channel.close();
        }
      });
      if (mounted) {
        setState(() {
          final code = hosted.manualEndpointCode;
          _status = code == null
              ? 'Хост запущен. Ожидаю подключение.'
              : 'Хост запущен. Код ручного подключения показан ниже.';
        });
      }
    } on Object {
      if (mounted) {
        setState(() => _status = 'Не удалось запустить режим ожидания.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _connect(
    LanPeerEndpoint endpoint, {
    required bool initial,
  }) async {
    if (!_available || _busy) return;
    setState(() {
      _busy = true;
      _status = initial
          ? 'Получаю первоначальное состояние бюджета…'
          : 'Синхронизирую изменения…';
    });
    try {
      final channel = await widget.services.lanPeerSessions!.connect(
        budgetId: widget.budgetId,
        endpoint: endpoint,
      );
      try {
        final localDeviceId = await _localDeviceId();
        if (initial) {
          final snapshots = widget.services.budgetSnapshotSessions;
          if (snapshots == null) {
            throw StateError('Snapshot service is unavailable.');
          }
          await snapshots.receiveAndApply(
            channel: channel,
            budgetId: widget.budgetId,
          );
        }
        await widget.services.syncSessions!.synchronize(
          channel: channel,
          budgetId: widget.budgetId,
          localDeviceId: localDeviceId,
        );
      } finally {
        await channel.close();
      }
      if (mounted) {
        setState(() => _status = 'Синхронизация завершена.');
      }
    } on Object {
      if (mounted) {
        setState(
          () => _status = 'Не удалось синхронизироваться с устройством.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _connectManual({required bool initial}) async {
    if (!_available) return;
    final raw = _manualEndpointController.text.trim();
    if (raw.isEmpty) {
      setState(() => _status = 'Введите код ручного подключения.');
      return;
    }
    try {
      final endpoint = widget.services.lanPeerSessions!.decodeManualEndpoint(
        raw,
      );
      await _connect(endpoint, initial: initial);
    } on Object {
      if (mounted) {
        setState(() => _status = 'Код ручного подключения некорректен.');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_available) {
      return const Center(
        child: Text('P2P-синхронизация недоступна в этой конфигурации.'),
      );
    }

    final hostedCode = _hosted?.manualEndpointCode;
    return ListView(
      key: const ValueKey('synchronization-screen'),
      padding: const EdgeInsets.all(16),
      children: [
        Text('Синхронизация', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        Text(_status, key: const ValueKey('sync-status')),
        const SizedBox(height: 20),
        Text(
          'Новое устройство',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        const Text(
          'На устройстве с данными включите отправку snapshot. '
          'На новом устройстве найдите его и выберите «Получить впервые».',
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          key: const ValueKey('sync-host-initial'),
          onPressed: _busy ? null : () => _startHost(initial: true),
          icon: const Icon(Icons.upload_outlined),
          label: const Text('Отправить данные новому устройству'),
        ),
        const SizedBox(height: 20),
        Text(
          'Обычная синхронизация',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          key: const ValueKey('sync-host-regular'),
          onPressed: _busy ? null : () => _startHost(initial: false),
          icon: const Icon(Icons.wifi_tethering),
          label: const Text('Ожидать подключение'),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          key: const ValueKey('sync-discover'),
          onPressed: _busy ? null : _startDiscovery,
          icon: const Icon(Icons.search),
          label: const Text('Найти устройства'),
        ),
        if (hostedCode != null) ...[
          const SizedBox(height: 12),
          const Text('Код ручного подключения:'),
          SelectableText(
            hostedCode,
            key: const ValueKey('sync-manual-endpoint-code'),
          ),
        ],
        if (_peers.isNotEmpty) ...[
          const SizedBox(height: 12),
          for (final peer in _peers)
            Card(
              child: ListTile(
                title: Text(peer.serviceName),
                subtitle: Text('${peer.host}:${peer.port}'),
                trailing: Wrap(
                  spacing: 8,
                  children: [
                    TextButton(
                      onPressed: _busy
                          ? null
                          : () => _connect(peer, initial: true),
                      child: const Text('Получить впервые'),
                    ),
                    FilledButton(
                      onPressed: _busy
                          ? null
                          : () => _connect(peer, initial: false),
                      child: const Text('Синхронизировать'),
                    ),
                  ],
                ),
              ),
            ),
        ],
        const SizedBox(height: 20),
        TextField(
          key: const ValueKey('sync-manual-endpoint-input'),
          controller: _manualEndpointController,
          decoration: const InputDecoration(
            labelText: 'Код ручного подключения',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            OutlinedButton(
              onPressed: _busy ? null : () => _connectManual(initial: true),
              child: const Text('Получить впервые'),
            ),
            OutlinedButton(
              onPressed: _busy ? null : () => _connectManual(initial: false),
              child: const Text('Синхронизировать'),
            ),
          ],
        ),
      ],
    );
  }
}
