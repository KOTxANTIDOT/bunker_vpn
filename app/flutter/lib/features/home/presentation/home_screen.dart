import 'dart:convert';

import 'package:flutter/material.dart';

import '../../../platform/vpn_platform.dart';
import '../../../theme/bunker_theme.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final VpnPlatform _platform = VpnPlatform();

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
    final controller = TextEditingController();
    final configJson = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Импорт sing-box JSON'),
        content: SizedBox(
          width: double.maxFinite,
          child: TextField(
            controller: controller,
            minLines: 5,
            maxLines: 10,
            keyboardType: TextInputType.multiline,
            autocorrect: false,
            enableSuggestions: false,
            decoration: const InputDecoration(
              hintText: 'Вставь сюда полный sing-box JSON',
              border: OutlineInputBorder(),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('ОТМЕНА'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, controller.text),
            child: const Text('ПОДКЛЮЧИТЬ'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (configJson == null || !mounted) return;

    setState(() {
      _changingVpnService = true;
      _bridgeMessage = null;
    });
    try {
      final decoded = jsonDecode(configJson);
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('В корне JSON должен быть объект.');
      }
      final granted = await _platform.requestVpnPermission();
      if (!granted) {
        throw Exception('Разрешение Android VPN не выдано.');
      }
      await _platform.startProfile(configJson);
      final state = await _waitForServiceState({'PROFILE_STARTED'});
      if (!mounted) return;
      setState(() {
        _vpnServiceRunning = state == 'PROFILE_STARTED';
        _bridgeMessage = state == 'PROFILE_STARTED'
            ? 'sing-box принял профиль. Нужна проверка реального трафика на устройстве.'
            : state == 'ENGINE_ERROR'
                ? 'sing-box не смог запустить профиль. Проверь JSON и настройки.'
                : 'Профиль отправлен, состояние службы: $state';
      });
    } on Exception catch (error) {
      if (!mounted) return;
      setState(() {
        _bridgeMessage = 'Не удалось запустить профиль: $error';
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
                    'Android-основа готова',
                    style: TextStyle(
                      color: BunkerColors.textPrimary,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Проверим системное VPN-разрешение и запустим служебный '
                    'компонент. Передача трафика начнётся только после '
                    'подключения sing-box.',
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
                          : _toggleVpnService,
                      child: Text(
                        _changingVpnService
                            ? 'ВЫПОЛНЯЮ...'
                            : _vpnServiceRunning
                                ? 'ОСТАНОВИТЬ СЛУЖБУ'
                                : 'ЗАПУСТИТЬ СЛУЖБУ ANDROID',
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
                label: const Text('ВСТАВИТЬ JSON-ПРОФИЛЬ'),
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
            const _InfoTile(
              icon: Icons.hub_outlined,
              title: 'Сетевой движок',
              value: 'sing-box · подготовка',
            ),
            const SizedBox(height: 10),
            const _InfoTile(
              icon: Icons.route_outlined,
              title: 'Маршрутизация',
              value: 'Ещё не активна',
            ),
            const SizedBox(height: 10),
            _InfoTile(
              icon: Icons.security_outlined,
              title: 'Защита',
              value: _vpnServiceRunning
                  ? 'Сервис активен · без туннеля'
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
