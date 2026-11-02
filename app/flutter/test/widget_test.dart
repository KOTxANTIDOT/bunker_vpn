import 'package:bunker_vpn/app.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows honest disconnected foundation state', (tester) async {
    await tester.pumpWidget(const BunkerVpnApp());

    expect(find.text('BUNKER VPN'), findsOneWidget);
    expect(find.text('Android-основа готова'), findsOneWidget);
    expect(
      find.text('ЗАПУСТИТЬ СЛУЖБУ ANDROID'),
      findsOneWidget,
    );
    expect(find.text('VPN не запущен'), findsOneWidget);
    expect(find.text('sing-box · подготовка'), findsOneWidget);
  });
}
