import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class StoredProfile {
  const StoredProfile({
    required this.id,
    required this.name,
    required this.configJson,
  });

  final String id;
  final String name;
  final String configJson;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'configJson': configJson,
      };

  factory StoredProfile.fromJson(Map<String, dynamic> json) => StoredProfile(
        id: json['id'] as String,
        name: json['name'] as String,
        configJson: json['configJson'] as String,
      );
}

class ProfileStore {
  static const _profilesKey = 'bunker.saved_profiles.v1';
  static const _activeKey = 'bunker.active_profile.v1';

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
    final id = DateTime.now().microsecondsSinceEpoch.toString();
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
