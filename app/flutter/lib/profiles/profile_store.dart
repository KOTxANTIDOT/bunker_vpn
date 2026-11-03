import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class StoredProfile {
  const StoredProfile({
    required this.id,
    required this.name,
    required this.configJson,
    this.sourceUrl,
  });

  final String id;
  final String name;
  final String configJson;
  final String? sourceUrl;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'configJson': configJson,
        if (sourceUrl != null) 'sourceUrl': sourceUrl,
      };

  factory StoredProfile.fromJson(Map<String, dynamic> json) => StoredProfile(
        id: json['id'] as String,
        name: json['name'] as String,
        configJson: json['configJson'] as String,
        sourceUrl: json['sourceUrl'] as String?,
      );
}

class ProfileStore {
  static const _profilesKey = 'bunker.saved_profiles.v1';
  static const _activeKey = 'bunker.active_profile.v1';
  static const _subscriptionsKey = 'bunker.subscriptions.v1';

  Future<List<StoredProfile>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_profilesKey) ?? const <String>[];
    final profiles = <StoredProfile>[];
    for (final item in raw) {
      try {
        final decoded = jsonDecode(item);
        if (decoded is Map<String, dynamic>) {
          profiles.add(StoredProfile.fromJson(decoded));
        }
      } on FormatException {
        // Ignore a damaged entry without losing the remaining profiles.
      } on TypeError {
        // Ignore entries written by an incompatible older format.
      }
    }
    return profiles;
  }

  Future<String> save(String name, String configJson) async {
    final prefs = await SharedPreferences.getInstance();
    final profiles = await load();
    final existingIndex =
        profiles.indexWhere((profile) => profile.configJson == configJson);
    final id = existingIndex >= 0
        ? profiles[existingIndex].id
        : DateTime.now().microsecondsSinceEpoch.toString();
    if (existingIndex >= 0) {
      profiles.removeAt(existingIndex);
    }
    profiles.insert(
      0,
      StoredProfile(id: id, name: name, configJson: configJson),
    );
    await prefs.setStringList(
      _profilesKey,
      profiles.map((profile) => jsonEncode(profile.toJson())).toList(),
    );
    await prefs.setString(_activeKey, id);
    return id;
  }

  Future<List<String>> loadSubscriptions() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_subscriptionsKey) ?? <String>[];
  }

  Future<void> saveSubscriptionUrl(String url) async {
    final prefs = await SharedPreferences.getInstance();
    final urls = prefs.getStringList(_subscriptionsKey) ?? <String>[];
    if (!urls.contains(url)) urls.insert(0, url);
    await prefs.setStringList(_subscriptionsKey, urls);
  }

  Future<void> replaceSubscriptionProfiles(
    String sourceUrl,
    List<({String name, String configJson})> entries,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final profiles = await load();
    final previousSubscriptionIds = profiles
        .where((profile) => profile.sourceUrl == sourceUrl)
        .map((profile) => profile.id)
        .toSet();
    profiles.removeWhere((profile) => profile.sourceUrl == sourceUrl);
    final now = DateTime.now().microsecondsSinceEpoch;
    final replacements = <StoredProfile>[];
    for (var index = 0; index < entries.length; index++) {
      final entry = entries[index];
      final duplicateIndex = profiles.indexWhere(
        (profile) => profile.configJson == entry.configJson,
      );
      if (duplicateIndex >= 0) {
        final existing = profiles.removeAt(duplicateIndex);
        replacements.add(StoredProfile(
          id: existing.id,
          name: entry.name,
          configJson: entry.configJson,
          sourceUrl: sourceUrl,
        ));
      } else {
        replacements.add(StoredProfile(
          id: 'sub-$now-$index',
          name: entry.name,
          configJson: entry.configJson,
          sourceUrl: sourceUrl,
        ));
      }
    }
    profiles.insertAll(0, replacements);
    await prefs.setStringList(
      _profilesKey,
      profiles.map((profile) => jsonEncode(profile.toJson())).toList(),
    );
    await saveSubscriptionUrl(sourceUrl);
    final activeId = prefs.getString(_activeKey);
    if (activeId == null || previousSubscriptionIds.contains(activeId)) {
      if (replacements.isNotEmpty) {
        await prefs.setString(_activeKey, replacements.first.id);
      } else {
        await prefs.remove(_activeKey);
      }
    }
  }

  Future<void> setActive(String id) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_activeKey, id);
  }

  Future<String?> activeId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_activeKey);
  }

  Future<void> delete(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final profiles = await load();
    profiles.removeWhere((profile) => profile.id == id);
    await prefs.setStringList(
      _profilesKey,
      profiles.map((profile) => jsonEncode(profile.toJson())).toList(),
    );
    if (prefs.getString(_activeKey) == id) {
      if (profiles.isEmpty) {
        await prefs.remove(_activeKey);
      } else {
        await prefs.setString(_activeKey, profiles.first.id);
      }
    }
  }
}
