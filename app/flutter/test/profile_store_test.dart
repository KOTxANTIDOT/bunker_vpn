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

  test('subscription refresh replaces stale profiles and keeps manual ones', () async {
    final store = ProfileStore();
    await store.save('Manual', '{"manual":true}');
    await store.replaceSubscriptionProfiles('https://sub.example/list', [
      (name: 'VLESS · one.example', configJson: '{"server":"one"}'),
      (name: 'VLESS · two.example', configJson: '{"server":"two"}'),
    ]);

    await store.replaceSubscriptionProfiles('https://sub.example/list', [
      (name: 'VLESS · two.example', configJson: '{"server":"two"}'),
      (name: 'VLESS · three.example', configJson: '{"server":"three"}'),
    ]);

    final profiles = await store.load();
    expect(profiles, hasLength(3));
    expect(profiles.map((profile) => profile.configJson),
        contains('{"manual":true}'));
    expect(profiles.map((profile) => profile.configJson),
        isNot(contains('{"server":"one"}')));
    expect(profiles.map((profile) => profile.configJson),
        contains('{"server":"three"}'));
    expect(profiles.where((profile) => profile.sourceUrl != null), hasLength(2));
  });

  test('deletes profile and clears active selection', () async {
    final store = ProfileStore();
    final id = await store.save('Test', '{}');

    await store.delete(id);

    expect(await store.load(), isEmpty);
    expect(await store.activeId(), isNull);
  });
}
