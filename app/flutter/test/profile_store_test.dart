import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bunker_vpn/profiles/profile_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('saves and restores profiles and active selection', () async {
    final store = ProfileStore();
    final id = await store.save('VLESS · example.com', '{"outbounds":[]}');

    final restored = await store.load();
    expect(restored, hasLength(1));
    expect(restored.first.id, id);
    expect(restored.first.name, 'VLESS · example.com');
    expect(restored.first.configJson, '{"outbounds":[]}');
    expect(await store.activeId(), id);
  });

  test('deletes profile and clears active selection', () async {
    final store = ProfileStore();
    final id = await store.save('Test', '{}');

    await store.delete(id);

    expect(await store.load(), isEmpty);
    expect(await store.activeId(), isNull);
  });
}
