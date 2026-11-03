import 'package:bunker_vpn/app.dart';
import 'package:flutter/material.dart' show Scrollable;
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows honest disconnected foundation state', (tester) async {
    await tester.pumpWidget(const BunkerVpnApp());

    expect(find.text('BUNKER VPN'), findsOneWidget);
    expect(find.text('Подключение через sing-box'), findsOneWidget);
    expect(
      find.text('ПОДКЛЮЧИТЬ VPN'),
      findsOneWidget,
    );

    await tester.scrollUntilVisible(
      find.text('VPN не запущен'),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('VPN не запущен'), findsOneWidget);
    expect(find.text('sing-box · libbox 1.14.3'), findsOneWidget);
  });
}
