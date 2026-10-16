import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'models.dart';

class Storage {
  static SharedPreferences? _p;
  static Future<SharedPreferences> get _prefs async {
    _p ??= await SharedPreferences.getInstance();
    return _p!;
  }

  // ── User & Memory ──────────────────────────────────────────────────────────
  static Future<String?> getUserName() async => (await _prefs).getString('user_name');
  static Future<void> setUserName(String v) async => (await _prefs).setString('user_name', v);
  static Future<void> clearUserName() async => (await _prefs).remove('user_name');

  static Future<String> getMemory() async => (await _prefs).getString('user_memory') ?? '';
  static Future<void> setMemory(String v) async => (await _prefs).setString('user_memory', v);

  // ── Gemini API Settings ────────────────────────────────────────────────────
  static const _envApiKey = String.fromEnvironment('GEMINI_API_KEY', defaultValue: '');

  static Future<String> getGeminiApiKey() async {
    final saved = (await _prefs).getString('gemini_api_key');
    if (saved != null && saved.trim().isNotEmpty) return saved.trim();
    return _envApiKey;
  }

  static Future<void> setGeminiApiKey(String key) async =>
      (await _prefs).setString('gemini_api_key', key.trim());

  static Future<String> getGeminiModel() async =>
      (await _prefs).getString('gemini_model') ?? 'gemini-2.5-flash';

  static Future<void> setGeminiModel(String model) async =>
      (await _prefs).setString('gemini_model', model);

  // ── Financial Stats ────────────────────────────────────────────────────────
  static Future<Map<String, String?>> getStats() async {
    final raw = (await _prefs).getString('financial_stats');
    if (raw == null) return {};
    return (jsonDecode(raw) as Map<String, dynamic>).map((k, v) => MapEntry(k, v as String?));
  }

  static Future<void> setStats(Map<String, String?> stats) async =>
      (await _prefs).setString('financial_stats', jsonEncode(stats));

  // ── Security Settings ──────────────────────────────────────────────────────
  static Future<bool> getScreenshotProtection() async =>
      (await _prefs).getBool('screenshot_protection') ?? false;
  static Future<void> setScreenshotProtection(bool v) async =>
      (await _prefs).setBool('screenshot_protection', v);

  // ── AI Insight Notifications ───────────────────────────────────────────────
  /// Interval in minutes: 0 = Off, 2 = Demo (2m), 15 = 15m, 60 = 1h, 1440 = Daily
  static Future<int> getNotificationIntervalMinutes() async =>
      (await _prefs).getInt('ai_notif_interval_min') ?? 15;

  static Future<void> setNotificationIntervalMinutes(int minutes) async =>
      (await _prefs).setInt('ai_notif_interval_min', minutes);

  static Future<DateTime?> getLastInsightTime() async {
    final raw = (await _prefs).getString('last_insight_time');
    if (raw == null) return null;
    return DateTime.tryParse(raw);
  }

  static Future<void> setLastInsightTime(DateTime time) async =>
      (await _prefs).setString('last_insight_time', time.toIso8601String());

  static Future<List<AiInsightNotification>> getInsights() async {
    final raw = (await _prefs).getString('ai_insights_list');
    if (raw == null) return [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .map((e) => AiInsightNotification.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> saveInsights(List<AiInsightNotification> insights) async {
    final encoded = jsonEncode(insights.map((e) => e.toJson()).toList());
    await (await _prefs).setString('ai_insights_list', encoded);
  }

  static Future<void> addInsight(AiInsightNotification insight) async {
    final list = await getInsights();
    list.insert(0, insight);
    if (list.length > 50) list.removeRange(50, list.length);
    await saveInsights(list);
    await setLastInsightTime(insight.createdAt);
  }

  static Future<void> markInsightRead(String id) async {
    final list = await getInsights();
    final updated = list.map((e) => e.id == id ? e.copyWith(isRead: true) : e).toList();
    await saveInsights(updated);
  }

  static Future<void> markAllInsightsRead() async {
    final list = await getInsights();
    final updated = list.map((e) => e.copyWith(isRead: true)).toList();
    await saveInsights(updated);
  }

  static Future<void> deleteInsight(String id) async {
    final list = await getInsights();
    list.removeWhere((e) => e.id == id);
    await saveInsights(list);
  }

  static Future<void> clearInsights() async {
    await (await _prefs).remove('ai_insights_list');
  }

  // ── Conversations ──────────────────────────────────────────────────────────
  static Future<List<String>> getConvIds() async {
    final raw = (await _prefs).getString('conv_ids');
    if (raw == null) return [];
    return List<String>.from(jsonDecode(raw));
  }

  static Future<void> _saveIds(List<String> ids) async =>
      (await _prefs).setString('conv_ids', jsonEncode(ids));

  static Future<void> addConvId(String id) async {
    final ids = await getConvIds();
    ids.insert(0, id);
    await _saveIds(ids);
  }

  static Future<String> getTitle(String id) async =>
      (await _prefs).getString('conv_title_$id') ?? 'Yeni Sohbet';
  static Future<void> setTitle(String id, String title) async =>
      (await _prefs).setString('conv_title_$id', title);

  static Future<List<Map<String, dynamic>>> getMessages(String id) async {
    final raw = (await _prefs).getString('conv_msgs_$id');
    if (raw == null) return [];
    return List<Map<String, dynamic>>.from(jsonDecode(raw));
  }

  static Future<void> saveMessages(String id, List<Map<String, dynamic>> msgs) async =>
      (await _prefs).setString('conv_msgs_$id', jsonEncode(msgs));

  static Future<void> deleteConv(String id) async {
    final ids = await getConvIds();
    ids.remove(id);
    await _saveIds(ids);
    final p = await _prefs;
    await p.remove('conv_title_$id');
    await p.remove('conv_msgs_$id');
  }
}
