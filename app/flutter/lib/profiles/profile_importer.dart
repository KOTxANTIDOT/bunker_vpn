import 'dart:convert';

/// Converts common share links into a minimal sing-box TUN configuration.
/// Subscription URLs are intentionally not fetched here; they need a separate
/// network/update flow with explicit user consent.
class ProfileImporter {
  const ProfileImporter();

  Map<String, dynamic> parse(String input) {
    final value = input.trim();
    if (value.isEmpty) {
      throw const FormatException('Пустая ссылка или профиль.');
    }
    if (value.startsWith('[Interface]') || value.contains('\n[Interface]')) {
      return _wireGuard(value);
    }
    if (value.startsWith('{')) {
      final decoded = jsonDecode(value);
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('Корень JSON должен быть объектом.');
      }
      return _migrateLegacyDns(decoded);
    }

    final uri = Uri.tryParse(value);
    if (uri == null || !uri.hasScheme) {
      throw const FormatException('Не удалось распознать ссылку.');
    }
    switch (uri.scheme.toLowerCase()) {
      case 'vless':
        return _vless(uri);
      case 'trojan':
        return _trojan(uri);
      case 'hysteria':
        return _hysteria(uri);
      case 'hysteria2':
      case 'hy2':
        return _hysteria2(uri);
      case 'ss':
      case 'shadowsocks':
        return _shadowsocks(uri);
      case 'vmess':
        return _vmess(value);
      default:
        throw FormatException('Пока не поддерживается протокол: ${uri.scheme}');
    }
  }


  /// Migrates legacy sing-box JSON received from subscriptions or pasted configs.
  /// sing-box 1.13+ removed the DNS outbound; DNS packets must be hijacked by
  /// a route action instead.
  Map<String, dynamic> _migrateLegacyDns(Map<String, dynamic> source) {
    final config = Map<String, dynamic>.from(source);
    final outbounds = (config['outbounds'] as List<dynamic>? ?? const [])
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
    final removedDnsTags = outbounds
        .where((item) => item['type'] == 'dns')
        .map((item) => item['tag']?.toString())
        .whereType<String>()
        .toSet();
    if (removedDnsTags.isEmpty) return config;

    config['outbounds'] = outbounds
        .where((item) => item['type'] != 'dns')
        .toList();

    final routeValue = config['route'];
    if (routeValue is Map) {
      final route = Map<String, dynamic>.from(routeValue);
      final rulesValue = route['rules'];
      if (rulesValue is List) {
        route['rules'] = rulesValue.map((value) {
          if (value is! Map) return value;
          final rule = Map<String, dynamic>.from(value);
          if (removedDnsTags.contains(rule['outbound'])) {
            rule.remove('outbound');
            rule['action'] = 'hijack-dns';
          }
          return rule;
        }).toList();
      }
      if (removedDnsTags.contains(route['final'])) {
        route.remove('final');
      }
      config['route'] = route;
    }
    return config;
  }

  Map<String, dynamic> _wireGuard(String text) {
    final sections = <String, Map<String, String>>{};
    String? current;
    for (final rawLine in text.split(RegExp(r'\r?\n'))) {
      final line = rawLine.split('#').first.trim();
      if (line.isEmpty) continue;
      if (line.startsWith('[') && line.endsWith(']')) {
        current = line.substring(1, line.length - 1).toLowerCase();
        sections[current] = <String, String>{};
        continue;
      }
      final separator = line.indexOf('=');
      if (current == null || separator < 1) continue;
      sections[current]![line.substring(0, separator).trim().toLowerCase()] =
          line.substring(separator + 1).trim();
    }
    final iface = sections['interface'];
    final peer = sections['peer'];
    if (iface == null || peer == null) {
      throw const FormatException('WireGuard/WARP: нужны секции [Interface] и [Peer].');
    }
    final privateKey = iface['privatekey'] ?? '';
    final publicKey = peer['publickey'] ?? '';
    final endpoint = peer['endpoint'] ?? '';
    final address = (iface['address'] ?? '')
        .split(',')
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toList();
    final allowedIps = (peer['allowedips'] ?? '0.0.0.0/0, ::/0')
        .split(',')
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toList();
    final endpointUri = Uri.parse('udp://$endpoint');
    if (privateKey.isEmpty || publicKey.isEmpty || endpointUri.host.isEmpty ||
        endpointUri.port == 0 || address.isEmpty) {
      throw const FormatException('WireGuard/WARP: не хватает ключей, адреса или Endpoint.');
    }
    final reserved = (peer['reserved'] ?? '')
        .split(',')
        .map((value) => int.tryParse(value.trim()))
        .whereType<int>()
        .toList();
    final wireguardEndpoint = <String, dynamic>{
      'type': 'wireguard',
      'tag': 'warp',
      'mtu': int.tryParse(iface['mtu'] ?? '') ?? 1280,
      'address': address,
      'private_key': privateKey,
      'peers': [
        {
          'address': endpointUri.host,
          'port': endpointUri.port,
          'public_key': publicKey,
          if ((peer['presharedkey'] ?? '').isNotEmpty)
            'pre_shared_key': peer['presharedkey'],
          'allowed_ips': allowedIps,
          'persistent_keepalive_interval':
              int.tryParse(peer['persistentkeepalive'] ?? '25') ?? 25,
          if (reserved.length == 3) 'reserved': reserved,
        }
      ],
    };
    final dns = (iface['dns'] ?? '')
        .split(',')
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toList();
    if (dns.isEmpty) dns.add('1.1.1.1');
    return {
      'log': {'level': 'warn'},
      'dns': {
        'servers': [
          {'type': 'udp', 'tag': 'dns-remote', 'server': dns.first, 'detour': 'warp'}
        ],
        'final': 'dns-remote'
      },
      'inbounds': [
        {
          'type': 'tun',
          'tag': 'tun-in',
          'interface_name': 'bunker0',
          'address': ['172.19.0.1/30', 'fdfe:dcba:9876::1/126'],
          'mtu': 1400,
          'auto_route': true,
          'strict_route': true,
          'stack': 'mixed'
        }
      ],
      'endpoints': [wireguardEndpoint],
      'outbounds': [
        {'type': 'direct', 'tag': 'direct'}
      ],
      'route': {
        'auto_detect_interface': true,
        'final': 'warp',
        'rules': [
          {'protocol': 'dns', 'action': 'hijack-dns'}
        ]
      }
    };
  }

  Map<String, dynamic> _base(Map<String, dynamic> outbound) => {
        'log': {'level': 'warn'},
        'dns': {
          'servers': [
            {'type': 'udp', 'tag': 'dns-remote', 'server': '1.1.1.1', 'detour': 'proxy'}
          ],
          'final': 'dns-remote'
        },
        'inbounds': [
          {
            'type': 'tun',
            'tag': 'tun-in',
            'interface_name': 'bunker0',
            'address': ['172.19.0.1/30', 'fdfe:dcba:9876::1/126'],
            'mtu': 1400,
            'auto_route': true,
            'strict_route': true,
            'stack': 'mixed'
          }
        ],
        'outbounds': [
          outbound,
          {'type': 'direct', 'tag': 'direct'}
        ],
        'route': {
          'auto_detect_interface': true,
          'final': 'proxy',
          'rules': [
            {'protocol': 'dns', 'action': 'hijack-dns'}
          ]
        }
      };

  Map<String, dynamic> _vless(Uri uri) {
    final uuid = uri.userInfo;
    final host = uri.host;
    final port = uri.port;
    if (uuid.isEmpty || host.isEmpty || port == 0) {
      throw const FormatException('VLESS: нужны UUID, сервер и порт.');
    }
    final q = uri.queryParameters;
    final tls = (q['security'] ?? '').toLowerCase();
    final outbound = <String, dynamic>{
      'type': 'vless',
      'tag': 'proxy',
      'server': host,
      'server_port': port,
      'uuid': uuid,
    };
    if ((q['flow'] ?? '').isNotEmpty) outbound['flow'] = q['flow'];
    if (tls == 'tls' || tls == 'reality') {
      outbound['tls'] = {
        'enabled': true,
        'server_name': q['sni'] ?? q['serverName'] ?? host,
        'insecure': q['allowInsecure'] == '1',
      };
      if (tls == 'reality') {
        final publicKey = q['pbk'] ?? '';
        if (publicKey.isEmpty) {
          throw const FormatException('VLESS Reality: в ссылке отсутствует параметр pbk (public key).');
        }
        outbound['tls']['reality'] = {
          'enabled': true,
          'public_key': publicKey,
          'short_id': q['sid'] ?? ''
        };
        // sing-box requires uTLS for Reality clients. Chrome is the common
        // default when the share link does not include an explicit fp.
        outbound['tls']['utls'] = {
          'enabled': true,
          'fingerprint': (q['fp'] ?? '').isNotEmpty ? q['fp'] : 'chrome'
        };
      } else if ((q['fp'] ?? '').isNotEmpty) {
        outbound['tls']['utls'] = {'enabled': true, 'fingerprint': q['fp']};
      }
    }
    _addTransport(outbound, q);
    return _base(outbound);
  }

  Map<String, dynamic> _trojan(Uri uri) {
    final host = uri.host;
    final port = uri.port;
    if (uri.userInfo.isEmpty || host.isEmpty || port == 0) {
      throw const FormatException('Trojan: нужны пароль, сервер и порт.');
    }
    final q = uri.queryParameters;
    final outbound = <String, dynamic>{
      'type': 'trojan',
      'tag': 'proxy',
      'server': host,
      'server_port': port,
      'password': Uri.decodeComponent(uri.userInfo),
      'tls': {
        'enabled': true,
        'server_name': q['sni'] ?? q['peer'] ?? host,
        'insecure': q['allowInsecure'] == '1',
      }
    };
    _addTransport(outbound, q);
    return _base(outbound);
  }

  Map<String, dynamic> _hysteria(Uri uri) {
    final host = uri.host;
    final port = uri.port;
    final password = uri.userInfo;
    if (host.isEmpty || port == 0 || password.isEmpty) {
      throw const FormatException('Hysteria: нужны сервер, порт и пароль.');
    }
    final q = uri.queryParameters;
    final outbound = <String, dynamic>{
      'type': 'hysteria',
      'tag': 'proxy',
      'server': host,
      'server_port': port,
      'up_mbps': int.tryParse(q['upmbps'] ?? q['up_mbps'] ?? '100') ?? 100,
      'down_mbps': int.tryParse(q['downmbps'] ?? q['down_mbps'] ?? '100') ?? 100,
      'password': Uri.decodeComponent(password),
      'tls': {
        'enabled': true,
        'server_name': q['sni'] ?? q['peer'] ?? host,
        'insecure': q['insecure'] == '1' || q['allowInsecure'] == '1',
      },
    };
    final obfs = q['obfs'];
    final obfsPassword = q['obfs-password'] ?? q['obfs_password'];
    if (obfs != null && obfs.isNotEmpty) {
      outbound['obfs'] = {
        'type': obfs,
        if (obfsPassword != null && obfsPassword.isNotEmpty) 'password': obfsPassword,
      };
    }
    return _base(outbound);
  }

  Map<String, dynamic> _hysteria2(Uri uri) {
    final host = uri.host;
    final port = uri.port;
    final rawUserInfo = Uri.decodeComponent(uri.userInfo);
    final password = rawUserInfo.contains(':')
        ? rawUserInfo.substring(rawUserInfo.indexOf(':') + 1)
        : rawUserInfo;
    if (host.isEmpty || port == 0 || password.isEmpty) {
      throw const FormatException('Hysteria2: нужны сервер, порт и пароль.');
    }
    final q = uri.queryParameters;
    final outbound = <String, dynamic>{
      'type': 'hysteria2',
      'tag': 'proxy',
      'server': host,
      'server_port': port,
      'password': password,
      'tls': {
        'enabled': true,
        'server_name': q['sni'] ?? q['peer'] ?? host,
        'insecure': q['insecure'] == '1' || q['allowInsecure'] == '1',
      },
    };
    final obfs = q['obfs'];
    final obfsPassword = q['obfs-password'] ?? q['obfs_password'];
    if (obfs != null && obfs.isNotEmpty) {
      outbound['obfs'] = {
        'type': obfs,
        if (obfsPassword != null && obfsPassword.isNotEmpty) 'password': obfsPassword,
      };
    }
    return _base(outbound);
  }
  Map<String, dynamic> _shadowsocks(Uri uri) {
    var userInfo = uri.userInfo;
    if (userInfo.isEmpty && uri.host.isNotEmpty) {
      final decoded = utf8.decode(base64.decode(base64.normalize(uri.host)));
      userInfo = decoded;
    }
    final split = userInfo.indexOf(':');
    if (split <= 0 || uri.host.isEmpty || uri.port == 0) {
      throw const FormatException('Shadowsocks: неверный формат ссылки.');
    }
    return _base({
      'type': 'shadowsocks',
      'tag': 'proxy',
      'server': uri.host,
      'server_port': uri.port,
      'method': userInfo.substring(0, split),
      'password': userInfo.substring(split + 1),
    });
  }

  Map<String, dynamic> _vmess(String value) {
    final encoded = value.substring(value.indexOf('://') + 3).split('#').first;
    final data = jsonDecode(utf8.decode(base64.decode(base64.normalize(encoded))));
    if (data is! Map<String, dynamic>) {
      throw const FormatException('VMess: некорректные данные.');
    }
    final host = (data['add'] ?? '').toString();
    final port = int.tryParse((data['port'] ?? '').toString()) ?? 0;
    final id = (data['id'] ?? '').toString();
    if (host.isEmpty || port == 0 || id.isEmpty) {
      throw const FormatException('VMess: отсутствует сервер, порт или UUID.');
    }
    final outbound = <String, dynamic>{
      'type': 'vmess',
      'tag': 'proxy',
      'server': host,
      'server_port': port,
      'uuid': id,
      'security': (data['scy'] ?? 'auto').toString(),
    };
    final net = (data['net'] ?? 'tcp').toString();
    if (net == 'ws') {
      outbound['transport'] = {
        'type': 'ws',
        'path': (data['path'] ?? '').toString(),
        if ((data['host'] ?? '').toString().isNotEmpty)
          'headers': {'Host': data['host'].toString()}
      };
    } else if (net == 'grpc') {
      outbound['transport'] = {
        'type': 'grpc',
        'service_name': (data['path'] ?? '').toString()
      };
    }
    if ((data['tls'] ?? '').toString() == 'tls') {
      outbound['tls'] = {
        'enabled': true,
        'server_name': (data['sni'] ?? data['host'] ?? host).toString()
      };
    }
    return _base(outbound);
  }

  void _addTransport(Map<String, dynamic> outbound, Map<String, String> q) {
    final type = (q['type'] ?? '').toLowerCase();
    if (type == 'ws') {
      outbound['transport'] = {
        'type': 'ws',
        'path': q['path'] ?? '',
        if ((q['host'] ?? '').isNotEmpty)
          'headers': {'Host': q['host']}
      };
    } else if (type == 'grpc') {
      outbound['transport'] = {
        'type': 'grpc',
        'service_name': q['serviceName'] ?? q['service_name'] ?? ''
      };
    }
  }
}
