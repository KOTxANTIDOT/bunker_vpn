import 'package:flutter_test/flutter_test.dart';
import 'package:bunker_vpn/profiles/profile_importer.dart';

void main() {
  const importer = ProfileImporter();

  test('parses VLESS share link into sing-box TUN profile', () {
    final config = importer.parse(
      'vless://11111111-1111-1111-1111-111111111111@example.com:443'
      '?security=tls&sni=example.com#test',
    );
    final outbound = config['outbounds'] as List<dynamic>;
    expect(outbound.first['type'], 'vless');
    expect(outbound.first['server'], 'example.com');
    expect(outbound.first['uuid'], '11111111-1111-1111-1111-111111111111');
    expect((config['inbounds'] as List).first['type'], 'tun');
  });

  test('parses Trojan share link', () {
    final config = importer.parse('trojan://secret@example.com:443?sni=example.com');
    final outbound = (config['outbounds'] as List).first;
    expect(outbound['type'], 'trojan');
    expect(outbound['password'], 'secret');
  });

  test('parses Hysteria link', () {
    final config = importer.parse('hysteria://secret@example.com:443?sni=example.com');
    final outbound = (config['outbounds'] as List).first;
    expect(outbound['type'], 'hysteria');
    expect(outbound['password'], 'secret');
  });

  test('parses Hysteria2 and hy2 links', () {
    for (final scheme in ['hysteria2', 'hy2']) {
      final config = importer.parse('$scheme://secret@example.com:443?sni=example.com');
      final outbound = (config['outbounds'] as List).first;
      expect(outbound['type'], 'hysteria2');
      expect(outbound['password'], 'secret');
    }
  });
  test('keeps full sing-box JSON profiles', () {
    final config = importer.parse('{"outbounds":[{"type":"direct"}]}');
    expect((config['outbounds'] as List).first['type'], 'direct');
  });

  test('rejects unsupported schemes with a readable error', () {
    expect(() => importer.parse('ftp://example.com'), throwsFormatException);
  });
}
