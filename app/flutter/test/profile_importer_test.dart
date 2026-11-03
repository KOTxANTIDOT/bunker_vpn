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
    final dns = (config['dns'] as Map)['servers'] as List;
    expect(dns.first['type'], 'udp');
    expect(dns.first['server'], '1.1.1.1');
    expect(dns.first.containsKey('address'), isFalse);
    expect(outbound.any((item) => item['type'] == 'dns'), isFalse);
    expect((config['route'] as Map)['rules'], [
      {'protocol': 'dns', 'action': 'hijack-dns'}
    ]);
  });

  test('enables default uTLS fingerprint for VLESS Reality', () {
    final config = importer.parse(
      'vless://11111111-1111-1111-1111-111111111111@example.com:443'
      '?security=reality&sni=example.com&pbk=public-key&sid=abcd',
    );
    final outbound = (config['outbounds'] as List).first;
    final tls = outbound['tls'] as Map;
    expect(tls['reality']['enabled'], isTrue);
    expect(tls['utls'], {'enabled': true, 'fingerprint': 'chrome'});
  });

  test('uses explicit uTLS fingerprint for VLESS Reality', () {
    final config = importer.parse(
      'vless://11111111-1111-1111-1111-111111111111@example.com:443'
      '?security=reality&sni=example.com&pbk=public-key&sid=abcd&fp=firefox',
    );
    final outbound = (config['outbounds'] as List).first;
    expect(outbound['tls']['utls'], {'enabled': true, 'fingerprint': 'firefox'});
  });

  test('rejects VLESS Reality link without public key', () {
    expect(
      () => importer.parse(
        'vless://11111111-1111-1111-1111-111111111111@example.com:443?security=reality',
      ),
      throwsFormatException,
    );
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
  test('parses WireGuard configuration for WARP endpoint', () {
    const wireguard = '''
[Interface]
PrivateKey = private-key
Address = 172.16.0.2/32, 2606:4700:110::2/128
DNS = 1.1.1.1
MTU = 1280

[Peer]
PublicKey = cloudflare-public-key
AllowedIPs = 0.0.0.0/0, ::/0
Endpoint = engage.cloudflareclient.com:2408
PersistentKeepalive = 25
Reserved = 1, 2, 3
''';
    final config = importer.parse(wireguard);
    final endpoint = (config['endpoints'] as List).first;
    expect(endpoint['type'], 'wireguard');
    expect(endpoint['tag'], 'warp');
    expect(endpoint['private_key'], 'private-key');
    expect((endpoint['peers'] as List).first['reserved'], [1, 2, 3]);
    expect(config['route']['final'], 'warp');
    expect((config['outbounds'] as List).any((item) => item['type'] == 'dns'), isFalse);
    expect(config['route']['rules'], [
      {'protocol': 'dns', 'action': 'hijack-dns'}
    ]);
  });

  test('uses fallback DNS when WireGuard DNS is empty', () {
    const wireguard = '''
[Interface]
PrivateKey = private-key
Address = 172.16.0.2/32
DNS =
[Peer]
PublicKey = cloudflare-public-key
Endpoint = engage.cloudflareclient.com:2408
''';
    final config = importer.parse(wireguard);
    final dns = (config['dns'] as Map)['servers'] as List;
    expect(dns.first['type'], 'udp');
    expect(dns.first['server'], '1.1.1.1');
  });

  test('migrates legacy DNS outbound in imported sing-box JSON', () {
    final config = importer.parse('''
{
  "outbounds": [
    {"type": "vless", "tag": "proxy", "server": "example.com", "server_port": 443, "uuid": "11111111-1111-1111-1111-111111111111"},
    {"type": "direct", "tag": "direct"},
    {"type": "dns", "tag": "dns-out"}
  ],
  "route": {
    "rules": [{"protocol": "dns", "outbound": "dns-out"}],
    "final": "proxy"
  }
}
''');
    final outbounds = config['outbounds'] as List;
    expect(outbounds.any((item) => item['type'] == 'dns'), isFalse);
    expect((config['route'] as Map)['rules'], [
      {'protocol': 'dns', 'action': 'hijack-dns'}
    ]);
  });

  test('keeps full sing-box JSON profiles', () {
    final config = importer.parse('{"outbounds":[{"type":"direct"}]}');
    expect((config['outbounds'] as List).first['type'], 'direct');
  });

  test('rejects unsupported schemes with a readable error', () {
    expect(() => importer.parse('ftp://example.com'), throwsFormatException);
  });
}
