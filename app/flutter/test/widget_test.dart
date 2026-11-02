import 'package:bunker_vpn/app.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows honest disconnected foundation state', (tester) async {
    await tester.pumpWidget(const BunkerVpnApp());

    expect(find.text('BUNKER VPN'), findsOneWidget);
    expect(find.text('Бункер пока закрыт'), findsOneWidget);
    expect(find.text('ПОДКЛЮЧЕНИЕ СКОРО'), findsOneWidget);
  });
}
