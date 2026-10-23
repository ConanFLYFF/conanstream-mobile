import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'utils/app_logger.dart';

class AccountProfile {
  final String id;
  final String name;
  final String serverUrl;
  final String username;
  final String password;
  final Map userInfo;

  AccountProfile({
    String? id,
    String? name,
    required this.serverUrl,
    required this.username,
    required this.password,
    this.userInfo = const {},
  })  : id = id ?? username,
        name = name ?? username;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'serverUrl': serverUrl,
        'username': username,
        'password': password,
        'userInfo': userInfo,
      };

  factory AccountProfile.fromJson(Map<String, dynamic> json) => AccountProfile(
        id: json['id'] ?? json['username'] ?? '',
        name: json['name'] ?? json['username'] ?? '',
        serverUrl: json['serverUrl'] ?? '',
        username: json['username'] ?? '',
        password: json['password'] ?? '',
        userInfo: json['userInfo'] ?? {},
      );
}

class SharedPrefsHelper {
  static const String _accountsKey = 'saved_accounts_list';
  static const String _activeAccountKey = 'active_account_data';

  static Future<List<AccountProfile>> getAccounts() async {
    final prefs = await SharedPreferences.getInstance();
    final String? data = prefs.getString(_accountsKey);
    if (data == null) return [];
    try {
      final List decoded = json.decode(data);
      return decoded.map((e) => AccountProfile.fromJson(e)).toList();
    } catch (e, stack) {
      AppLogger.error('GET_ACCOUNTS', e, stack);
      return [];
    }
  }

  static Future<void> saveAccount(AccountProfile account) async {
    final prefs = await SharedPreferences.getInstance();
    List<AccountProfile> accounts = await getAccounts();
    accounts.removeWhere((acc) => acc.username == account.username && acc.serverUrl == account.serverUrl);
    accounts.add(account);
    List<Map<String, dynamic>> jsonList = accounts.map((acc) => acc.toJson()).toList();
    await prefs.setString(_accountsKey, json.encode(jsonList));
    AppLogger.storage(_accountsKey, account.username);
  }

  static Future<void> deleteAccount(String username) async {
    final prefs = await SharedPreferences.getInstance();
    List<AccountProfile> accounts = await getAccounts();
    accounts.removeWhere((acc) => acc.username == username);
    List<Map<String, dynamic>> jsonList = accounts.map((acc) => acc.toJson()).toList();
    await prefs.setString(_accountsKey, json.encode(jsonList));
    AppLogger.action('ACCOUNT', 'Compte supprimé : $username');
  }

  static Future<void> setActiveAccount(dynamic account) async {
    final prefs = await SharedPreferences.getInstance();
    if (account is AccountProfile) {
      await prefs.setString(_activeAccountKey, json.encode(account.toJson()));
      AppLogger.storage(_activeAccountKey, account.username);
    } else if (account is String) {
      await prefs.setString(_activeAccountKey, account);
      AppLogger.storage(_activeAccountKey, account);
    }
  }

  static Future<double> getVodProgress(String vodId) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getDouble('vod_progress_$vodId') ?? 0.0;
  }

  static Future<void> saveVodProgress(String vodId, double progress) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('vod_progress_$vodId', progress);
    AppLogger.storage('vod_progress_$vodId', '${(progress * 100).toStringAsFixed(1)}%');
  }

  static String _normalizeKey(String key) {
    if (key == 'favorite_channels') return 'fav_live';
    if (key == 'favorite_movies') return 'fav_movies';
    if (key == 'favorite_series') return 'fav_series';
    return key;
  }

  static Future<List<dynamic>> getFavorites(String key) async {
    final prefs = await SharedPreferences.getInstance();
    final normalizedKey = _normalizeKey(key);
    try {
      final String? data = prefs.getString(normalizedKey);
      if (data != null && data.isNotEmpty) {
        final decoded = json.decode(data);
        if (decoded is List) {
          return decoded.map((item) {
            if (item is Map) {
              return Map<String, dynamic>.from(item);
            } else {
              return {
                'id': item.toString(),
                'name': 'Favori #${item.toString()}',
                'stream_id': item.toString(),
                'title': 'Favori #${item.toString()}'
              };
            }
          }).toList();
        }
      }
    } catch (e, stack) {
      AppLogger.error('GET_FAVORITES', e, stack);
    }
    return [];
  }

  static Future<void> toggleFavorite(String key, dynamic item) async {
    final prefs = await SharedPreferences.getInstance();
    final normalizedKey = _normalizeKey(key);
    List<dynamic> favorites = await getFavorites(normalizedKey);

    Map<String, dynamic> itemMap;
    if (item is Map) {
      itemMap = Map<String, dynamic>.from(item);
      itemMap['name'] = itemMap['name'] ?? itemMap['title'] ?? itemMap['stream_name'] ?? 'Favori';
      itemMap['title'] = itemMap['title'] ?? itemMap['name'] ?? itemMap['stream_name'] ?? 'Favori';
      itemMap['stream_id'] = (itemMap['stream_id'] ?? itemMap['series_id'] ?? itemMap['id'] ?? '').toString();
    } else {
      itemMap = {
        'id': item.toString(),
        'name': 'Favori #${item.toString()}',
        'stream_id': item.toString(),
        'title': 'Favori #${item.toString()}'
      };
    }

    final String itemId = (itemMap['stream_id'] ?? itemMap['series_id'] ?? itemMap['id'] ?? '').toString();

    int existingIndex = favorites.indexWhere((fav) {
      if (fav is Map) {
        return (fav['stream_id'] ?? fav['series_id'] ?? fav['id'] ?? '').toString() == itemId;
      }
      return fav.toString() == itemId;
    });

    if (existingIndex >= 0) {
      favorites.removeAt(existingIndex);
      AppLogger.action('FAVORITE', 'Retrait du favori ($normalizedKey) : ${itemMap['name']}');
    } else {
      favorites.add(itemMap);
      AppLogger.action('FAVORITE', 'Ajout aux favoris ($normalizedKey) : ${itemMap['name']}');
    }

    await prefs.setString(normalizedKey, json.encode(favorites));
  }

  static Future<bool> isFavorite(String key, String itemId) async {
    final normalizedKey = _normalizeKey(key);
    List<dynamic> favorites = await getFavorites(normalizedKey);
    return favorites.any((fav) {
      if (fav is Map) {
        return (fav['stream_id'] ?? fav['series_id'] ?? fav['id'] ?? '').toString() == itemId;
      }
      return fav.toString() == itemId;
    });
  }

  static Future<void> trackInProgress(String type, Map<String, dynamic> item) async {
    final prefs = await SharedPreferences.getInstance();
    final key = type == 'movie' ? 'in_progress_movies' : 'in_progress_series';
    List<dynamic> list = await getFavorites(key);

    Map<String, dynamic> itemMap = Map<String, dynamic>.from(item);
    itemMap['name'] = itemMap['name'] ?? itemMap['title'] ?? 'Titre';
    itemMap['title'] = itemMap['title'] ?? itemMap['name'] ?? 'Titre';
    
    final itemId = (itemMap['stream_id'] ?? itemMap['series_id'] ?? itemMap['id'] ?? '').toString();
    if (itemId.isEmpty) return;

    list.removeWhere((element) {
      if (element is Map) {
        return (element['stream_id'] ?? element['series_id'] ?? element['id'] ?? '').toString() == itemId;
      }
      return false;
    });

    list.insert(0, itemMap);
    await prefs.setString(key, json.encode(list));
    AppLogger.action('IN_PROGRESS', 'Mise à jour en cours ($type) : ${itemMap['name']}');
  }

  // --- GESTION DE LA MISE EN CACHE INTELLIGENTE EPG ---
  
  static Future<List<dynamic>?> getCachedEpg(String streamId) async {
    final prefs = await SharedPreferences.getInstance();
    final String? cachedJson = prefs.getString('epg_cache_$streamId');
    final int? cacheTime = prefs.getInt('epg_time_$streamId');

    if (cachedJson != null && cacheTime != null) {
      final DateTime savedTime = DateTime.fromMillisecondsSinceEpoch(cacheTime);
      // Le cache est valide pendant 2 heures
      if (DateTime.now().difference(savedTime) < const Duration(hours: 2)) {
        try {
          final decoded = json.decode(cachedJson);
          if (decoded is List) return decoded;
        } catch (_) {}
      }
    }
    return null;
  }

  static Future<void> saveCachedEpg(String streamId, List<dynamic> listings) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('epg_cache_$streamId', json.encode(listings));
    await prefs.setInt('epg_time_$streamId', DateTime.now().millisecondsSinceEpoch);
  }

  // ----------------------------------------------------

  static Future<void> setAudioLanguage(String lang) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('pref_audio_lang', lang);
    AppLogger.storage('pref_audio_lang', lang);
  }

  static Future<String> getAudioLanguage() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('pref_audio_lang') ?? 'Français';
  }

  static Future<void> setSubtitleLanguage(String sub) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('pref_sub_lang', sub);
    AppLogger.storage('pref_sub_lang', sub);
  }

  static Future<String> getSubtitleLanguage() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('pref_sub_lang') ?? 'Désactivés';
  }

  static Future<bool> getAutoPauseOnFocusLoss() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('auto_pause_on_focus_loss') ?? true;
  }

  static Future<void> setAutoPauseOnFocusLoss(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('auto_pause_on_focus_loss', value);
    AppLogger.storage('auto_pause_on_focus_loss', value.toString());
  }
}