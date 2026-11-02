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
  String? _bridgeMessage;

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
                    'Бункер пока закрыт',
                    style: TextStyle(
                      color: BunkerColors.textPrimary,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'VPN-движок ещё не подключён. На следующем этапе добавим '
                    'реальное соединение через sing-box.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: BunkerColors.textMuted,
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 22),
                  const SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: null,
                      child: Text('ПОДКЛЮЧЕНИЕ СКОРО'),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            _InfoTile(
              icon: Icons.hub_outlined,
              title: 'Сетевой движок',
              value: 'sing-box · подготовка',
            ),
            const SizedBox(height: 10),
            _InfoTile(
              icon: Icons.route_outlined,
              title: 'Маршрутизация',
              value: 'Ещё не активна',
            ),
            const SizedBox(height: 10),
            _InfoTile(
              icon: Icons.security_outlined,
              title: 'Защита',
              value: 'VPN не запущен',
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
