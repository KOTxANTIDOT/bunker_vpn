import 'dart:convert';
import 'dart:io';

import 'profile_importer.dart';

class SubscriptionResult {
  const SubscriptionResult({required this.profiles, required this.sourceUrl});
  final List<Map<String, dynamic>> profiles;
  final String sourceUrl;
}

class SubscriptionService {
  SubscriptionService({ProfileImporter importer = const ProfileImporter()})
      : _importer = importer;
  final ProfileImporter _importer;

  Future<SubscriptionResult> fetch(String sourceUrl) async {
    final uri = Uri.tryParse(sourceUrl.trim());
    if (uri == null || (uri.scheme != 'https' && uri.scheme != 'http') || uri.host.isEmpty) {
      throw const FormatException('Укажи корректную HTTP(S)-ссылку подписки.');
    }
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 15);
    try {
      final request = await client.getUrl(uri).timeout(const Duration(seconds: 20));
      request.headers.set(HttpHeaders.acceptHeader, 'text/plain, */*');
      final response = await request.close().timeout(const Duration(seconds: 25));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw HttpException('Сервер подписки ответил HTTP ${response.statusCode}.');
      }
      final body = await response.transform(utf8.decoder).join().timeout(const Duration(seconds: 25));
      final links = _decodeLines(body);
      final profiles = <Map<String, dynamic>>[];
      final failures = <String>[];
      for (final link in links) {
        try {
          profiles.add(_importer.parse(link));
        } on FormatException catch (error) {
          failures.add(error.message);
        }
      }
      if (profiles.isEmpty) {
        final reason = failures.isEmpty ? '' : ': ${failures.first}';
        throw FormatException('В подписке не найдено поддерживаемых профилей$reason.');
      }
      return SubscriptionResult(profiles: profiles, sourceUrl: uri.toString());
    } finally {
      client.close(force: true);
    }
  }

  List<String> _decodeLines(String body) {
    var content = body.replaceFirst('\uFEFF', '').trim();
    if (content.isEmpty) throw const FormatException('Подписка пустая.');
    if (!content.contains('://') && !content.startsWith('{')) {
      try {
        content = utf8.decode(base64.decode(base64.normalize(content.replaceAll(RegExp(r'\\s+'), ''))));
      } on FormatException {
        // Keep plain text and report unsupported formats below.
      }
    }
    return content
        .split(RegExp(r'[\\r\\n]+'))
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty && !line.startsWith('#') && !line.startsWith(';') && (line.contains('://') || line.startsWith('{')))
        .toList();
  }
}