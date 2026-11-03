import 'dart:convert';

import 'package:flutter/material.dart';

import '../../../platform/vpn_platform.dart';
import '../../../profiles/profile_importer.dart';
import '../../../profiles/profile_store.dart';
import '../../../profiles/subscription_service.dart';
import '../../../theme/bunker_theme.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final VpnPlatform _platform = VpnPlatform();
  final ProfileImporter _profileImporter = const ProfileImporter();
  final ProfileStore _profileStore = ProfileStore();
  final SubscriptionService _subscriptionService = SubscriptionService();
  List<String> _subscriptionUrls = <String>[];
  List<StoredProfile> _savedProfiles = <StoredProfile>[];
  String? _activeProfileId;

  @override
  void initState() {
    super.initState();
    _loadSavedProfiles();
  }

  Future<void> _loadSavedProfiles() async {
    final profiles = await _profileStore.load();
    final activeId = await _profileStore.activeId();
    final subscriptionUrls = await _profileStore.loadSubscriptions();
    if (!mounted) return;
    setState(() {
      _savedProfiles = profiles;
      _activeProfileId = activeId;
      _subscriptionUrls = subscriptionUrls;
    });
  }

  Future<void> _startStoredProfile(StoredProfile stored) async {
    if (_changingVpnService) return;
    setState(() {
      _changingVpnService = true;
      _bridgeMessage = null;
    });
    try {
      await _profileStore.setActive(stored.id);
      await _platform.validateProfile(stored.configJson);
      final granted = await _platform.requestVpnPermission();
      if (!granted) throw Exception('Разрешение Android VPN не выдано.');
      await _platform.startProfile(stored.configJson);
      final state = await _waitForServiceState({'CONNECTED'});
      if (!mounted) return;
      setState(() {
        _activeProfileId = stored.id;
        _vpnServiceRunning = state == 'CONNECTED';
        _bridgeMessage = state == 'CONNECTED'
            ? 'Туннель создан для профиля «${stored.name}». Проверяем трафик отдельно.'
            : 'Состояние запуска профиля: $state';
      });
    } on Exception catch (error) {
      if (!mounted) return;
      setState(() => _bridgeMessage = 'Не удалось запустить профиль: $error');
    } finally {
      if (mounted) setState(() => _changingVpnService = false);
    }
  }

  Future<List<({String name, String configJson})>> _validateSubscriptionProfiles(
    SubscriptionResult result,
  ) async {
    final entries = <({String name, String configJson})>[];
    for (final profile in result.profiles) {
      final config = jsonEncode(profile);
      await _platform.validateProfile(config);
      final isWireGuard = (profile['endpoints'] as List?)?.any(
            (item) => item is Map && item['type'] == 'wireguard',
          ) ==
          true;
      final outbounds = profile['outbounds'] as List? ?? const [];
      final outbound = outbounds.isEmpty
          ? const <String, dynamic>{}
          : outbounds.firstWhere(
              (item) => item is Map && item['tag'] == 'proxy',
              orElse: () => outbounds.first,
            ) as Map;
      final name = isWireGuard
          ? 'Cloudflare WARP'
          : '${outbound['type'] ?? 'VPN'} · ${outbound['server'] ?? 'сервер'}';
      entries.add((name: name, configJson: config));
    }
    if (entries.isEmpty) {
      throw const FormatException('Подписка не содержит пригодных профилей.');
    }
    return entries;
  }

  Future<void> _importSubscription() async {
    final url = await showDialog<String>(
      context: context,
      builder: (_) => const _SubscriptionUrlDialog(),
    );
    if (url == null || !mounted) return;
    setState(() {
      _changingVpnService = true;
      _bridgeMessage = 'Загружаю и проверяю подписку...';
    });
    try {
      final result = await _subscriptionService.fetch(url);
      final entries = await _validateSubscriptionProfiles(result);
      await _profileStore.replaceSubscriptionProfiles(result.sourceUrl, entries);
      await _loadSavedProfiles();
      if (!mounted) return;
      setState(() {
        _bridgeMessage = 'Подписка добавлена: серверов — ${entries.length}.';
      });
    } on Exception catch (error) {
      if (!mounted) return;
      setState(() => _bridgeMessage = 'Не удалось импортировать подписку: $error');
    } finally {
      if (mounted) setState(() => _changingVpnService = false);
    }
  }

  Future<void> _updateSubscription(String url) async {
    if (_changingVpnService) return;
    setState(() {
      _changingVpnService = true;
      _bridgeMessage = 'Обновляю и проверяю подписку...';
    });
    try {
      final result = await _subscriptionService.fetch(url);
      final entries = await _validateSubscriptionProfiles(result);
      await _profileStore.replaceSubscriptionProfiles(result.sourceUrl, entries);
      await _loadSavedProfiles();
      if (!mounted) return;
      setState(() => _bridgeMessage =
          'Подписка обновлена: актуальных серверов — ${entries.length}.');
    } on Exception catch (error) {
      if (!mounted) return;
      setState(() => _bridgeMessage = 'Ошибка обновления подписки: $error');
    } finally {
      if (mounted) setState(() => _changingVpnService = false);
    }
  }

  Future<void> _deleteStoredProfile(StoredProfile stored) async {
    await _profileStore.delete(stored.id);
    await _loadSavedProfiles();
  }

  bool _checkingBridge = false;
  bool _vpnServiceRunning = false;
  bool _changingVpnService = false;
  String? _bridgeMessage;

  Future<String> _waitForServiceState(Set<String> expected) async {
    var state = await _platform.getVpnServiceState();
    for (var attempt = 0; attempt < 20; attempt++) {
      if (expected.contains(state) || state == 'ENGINE_ERROR') return state;
      await Future<void>.delayed(const Duration(milliseconds: 300));
      state = await _platform.getVpnServiceState();
    }
    return state;
  }

  Future<void> _toggleVpnService() async {
    if (_changingVpnService) return;
    setState(() {
      _changingVpnService = true;
      _bridgeMessage = null;
    });

    try {
      if (_vpnServiceRunning) {
        await _platform.stopVpnService();
        if (!mounted) return;
        setState(() {
          _vpnServiceRunning = false;
          _bridgeMessage =
              'Служба Android остановлена. VPN-трафик не запускался.';
        });
      } else {
        final granted = await _platform.requestVpnPermission();
        if (!granted) {
          if (!mounted) return;
          setState(() {
            _bridgeMessage = 'Разрешение Android VPN не выдано.';
          });
          return;
        }
        await _platform.startVpnService();
        final state = await _waitForServiceState({
          'ENGINE_READY_NO_PROFILE',
          'PROFILE_STARTED',
        });
        if (!mounted) return;
        setState(() {
          _vpnServiceRunning =
              state == 'ENGINE_READY_NO_PROFILE' || state == 'PROFILE_STARTED';
          _bridgeMessage = state == 'ENGINE_READY_NO_PROFILE'
              ? 'Движок запущен, но VPN-профиль ещё не подключён.'
              : state == 'ENGINE_ERROR'
                  ? 'Android не смог запустить движок. Проверь конфигурацию и журнал.'
                  : 'Ответ службы: $state';
        });
      }
    } on Exception catch (error) {
      if (!mounted) return;
      setState(() {
        _bridgeMessage = 'Ошибка VPN-службы: $error';
      });
    } finally {
      if (mounted) {
        setState(() => _changingVpnService = false);
      }
    }
  }

  Future<void> _importAndStartProfile() async {
    final configJson = await showDialog<String>(
      context: context,
      builder: (_) => const _ProfileImportDialog(),
    );
    if (configJson == null || !mounted) return;

    setState(() {
      _changingVpnService = true;
      _bridgeMessage = null;
    });
    try {
      final profile = _profileImporter.parse(configJson);
      final normalizedConfig = jsonEncode(profile);
      await _platform.validateProfile(normalizedConfig);
      final outbounds = profile['outbounds'] as List;
      final outbound = outbounds.firstWhere(
        (item) => item is Map && item['tag'] == 'proxy',
        orElse: () => outbounds.first,
      ) as Map;
      final name = (profile['endpoints'] as List?)?.any(
                (item) => item is Map && item['type'] == 'wireguard',
              ) == true
          ? 'Cloudflare WARP'
          : '${outbound['type'] ?? 'VPN'} · ${outbound['server'] ?? 'сервер'}';
      await _profileStore.save(name, normalizedConfig);
      await _loadSavedProfiles();
      final granted = await _platform.requestVpnPermission();
      if (!granted) {
        throw Exception('Разрешение Android VPN не выдано.');
      }
      await _platform.startProfile(normalizedConfig);
      final state = await _waitForServiceState({'CONNECTED'});
      if (!mounted) return;
      setState(() {
        _vpnServiceRunning = state == 'CONNECTED';
        _bridgeMessage = state == 'CONNECTED'
            ? 'VPN-туннель создан Android. Проверяем доступ к сети и отсутствие утечек.'
            : state == 'ENGINE_ERROR'
                ? 'sing-box не смог запустить профиль. Проверь JSON и настройки.'
                : 'Профиль отправлен, состояние службы: $state';
      });
    } on Exception catch (error) {
      if (!mounted) return;
      setState(() {
        _bridgeMessage = 'Проверка или запуск профиля не удались: $error';
      });
    } finally {
      if (mounted) {
        setState(() => _changingVpnService = false);
      }
    }
  }

  Future<void> _checkBridge() async {
    setState(() {
      _checkingBridge = true;
      _bridgeMessage = null;
    });

    try {
      final info = await _platform.getPlatformInfo();
      final ping = await _platform.ping();
      if (!mounted) return;
      setState(() {
        _bridgeMessage =
            '$ping · Android ${info.androidVersion} (API ${info.sdkInt})';
      });
    } on Exception catch (error) {
      if (!mounted) return;
      setState(() {
        _bridgeMessage = 'Мост пока недоступен: $error';
      });
    } finally {
      if (mounted) {
        setState(() => _checkingBridge = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.shield_moon_outlined, color: BunkerColors.accent),
            SizedBox(width: 10),
            Text('BUNKER VPN'),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Проверить Android-мост',
            onPressed: _checkingBridge ? null : _checkBridge,
            icon: const Icon(Icons.developer_board_outlined),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
          children: [
            const Text(
              'ТВОЁ СОЕДИНЕНИЕ',
              style: TextStyle(
                color: BunkerColors.textMuted,
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: BunkerColors.surface,
                borderRadius: BorderRadius.circular(26),
                border: Border.all(color: BunkerColors.border),
              ),
              child: Column(
                children: [
                  Container(
                    width: 132,
                    height: 132,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: BunkerColors.surfaceRaised,
                      border: Border.all(
                        color: BunkerColors.accent.withValues(alpha: 0.45),
                        width: 2,
                      ),
                    ),
                    child: const Icon(
                      Icons.shield_outlined,
                      size: 62,
                      color: BunkerColors.accent,
                    ),
                  ),
                  const SizedBox(height: 22),
                  const Text(
                    'Подключение через sing-box',
                    style: TextStyle(
                      color: BunkerColors.textPrimary,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Импортируй профиль sing-box, чтобы создать VPN-туннель '
                    'и направить через него трафик устройства.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: BunkerColors.textMuted,
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 22),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _changingVpnService
                          ? null
                          : _vpnServiceRunning
                              ? _toggleVpnService
                              : _importAndStartProfile,
                      child: Text(
                        _changingVpnService
                            ? 'ВЫПОЛНЯЮ...'
                            : _vpnServiceRunning
                                ? 'ОТКЛЮЧИТЬ VPN'
                                : 'ПОДКЛЮЧИТЬ VPN',
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _changingVpnService ? null : _importAndStartProfile,
                icon: const Icon(Icons.data_object_outlined),
                label: const Text('ИМПОРТИРОВАТЬ ПРОФИЛЬ / ССЫЛКУ'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: BunkerColors.accent,
                  side: const BorderSide(color: BunkerColors.accent),
                  minimumSize: const Size(0, 50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'СОХРАНЁННЫЕ СЕРВЕРЫ',
              style: TextStyle(
                color: BunkerColors.textMuted,
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 10),
            if (_savedProfiles.isEmpty)
              const Text(
                'Пока нет сохранённых профилей. Импортируй ссылку — сервер появится здесь.',
                style: TextStyle(color: BunkerColors.textMuted),
              )
            else
              ..._savedProfiles.map(
                (profile) => Card(
                  color: BunkerColors.surface,
                  child: ListTile(
                    leading: Icon(
                      profile.id == _activeProfileId
                          ? Icons.radio_button_checked
                          : Icons.dns_outlined,
                      color: BunkerColors.accent,
                    ),
                    title: Text(profile.name),
                    subtitle: Text(
                      profile.id == _activeProfileId
                          ? 'Выбранный профиль'
                          : 'Сохранён на устройстве',
                    ),
                    onTap: _changingVpnService
                        ? null
                        : () => _startStoredProfile(profile),
                    trailing: IconButton(
                      tooltip: 'Удалить профиль',
                      icon: const Icon(Icons.delete_outline),
                      onPressed: _changingVpnService
                          ? null
                          : () => _deleteStoredProfile(profile),
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 18),
            const SizedBox(height: 18),
            const Text(
              'ПОДПИСКИ',
              style: TextStyle(
                color: BunkerColors.textMuted,
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _changingVpnService ? null : _importSubscription,
              icon: const Icon(Icons.playlist_add),
              label: const Text('ДОБАВИТЬ ПОДПИСКУ ПО URL'),
            ),
            ..._subscriptionUrls.map(
              (url) => ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.link, color: BunkerColors.accent),
                title: Text(url, maxLines: 1, overflow: TextOverflow.ellipsis),
                trailing: IconButton(
                  tooltip: 'Обновить подписку',
                  onPressed: _changingVpnService ? null : () => _updateSubscription(url),
                  icon: const Icon(Icons.refresh),
                ),
              ),
            ),
            const SizedBox(height: 18),
            const _InfoTile(
              icon: Icons.hub_outlined,
              title: 'Сетевой движок',
              value: 'sing-box · libbox 1.14.3',
            ),
            const SizedBox(height: 10),
            _InfoTile(
              icon: Icons.route_outlined,
              title: 'Маршрутизация',
              value: _vpnServiceRunning ? 'TUN-интерфейс создан' : 'Ожидает подключения',
            ),
            const SizedBox(height: 10),
            _InfoTile(
              icon: Icons.security_outlined,
              title: 'Защита',
              value: _vpnServiceRunning
                  ? 'Android TUN активен'
                  : 'VPN не запущен',
            ),
            if (_bridgeMessage != null) ...[
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: BunkerColors.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: BunkerColors.border),
                ),
                child: Text(
                  _bridgeMessage!,
                  style: const TextStyle(color: BunkerColors.textMuted),
                ),
              ),
            ],
            const SizedBox(height: 18),
            OutlinedButton.icon(
              onPressed: _checkingBridge ? null : _checkBridge,
              icon: _checkingBridge
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.cable_outlined),
              label: Text(
                _checkingBridge ? 'ПРОВЕРЯЮ...' : 'ПРОВЕРИТЬ ANDROID-МОСТ',
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: BunkerColors.textPrimary,
                side: const BorderSide(color: BunkerColors.border),
                minimumSize: const Size(0, 50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  const _InfoTile({
    required this.icon,
    required this.title,
    required this.value,
  });

  final IconData icon;
  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
      decoration: BoxDecoration(
        color: BunkerColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: BunkerColors.border),
      ),
      child: Row(
        children: [
          Icon(icon, color: BunkerColors.accent, size: 21),
          const SizedBox(width: 13),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                color: BunkerColors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              color: BunkerColors.textMuted,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}


class _SubscriptionUrlDialog extends StatefulWidget {
  const _SubscriptionUrlDialog();

  @override
  State<_SubscriptionUrlDialog> createState() => _SubscriptionUrlDialogState();
}

class _SubscriptionUrlDialogState extends State<_SubscriptionUrlDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Добавить подписку'),
      content: TextField(
        controller: _controller,
        keyboardType: TextInputType.url,
        autocorrect: false,
        decoration: const InputDecoration(
          hintText: 'https://example.com/sub.txt',
          border: OutlineInputBorder(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('ОТМЕНА'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_controller.text.trim()),
          child: const Text('ЗАГРУЗИТЬ'),
        ),
      ],
    );
  }
}

class _ProfileImportDialog extends StatefulWidget {
  const _ProfileImportDialog();

  @override
  State<_ProfileImportDialog> createState() => _ProfileImportDialogState();
}

class _ProfileImportDialogState extends State<_ProfileImportDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Импорт VPN-профиля'),
      content: SizedBox(
        width: double.maxFinite,
        child: TextField(
          controller: _controller,
          minLines: 5,
          maxLines: 10,
          keyboardType: TextInputType.multiline,
          autocorrect: false,
          enableSuggestions: false,
          decoration: const InputDecoration(
            hintText: 'Вставь VLESS / VMess / Trojan / Shadowsocks или sing-box JSON',
            border: OutlineInputBorder(),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('ОТМЕНА'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_controller.text),
          child: const Text('ПОДКЛЮЧИТЬ'),
        ),
      ],
    );
  }
}
