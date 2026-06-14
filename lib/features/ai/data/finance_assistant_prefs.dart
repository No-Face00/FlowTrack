// lib/features/home/finance/finance_assistant_prefs.dart
//
// Manages the Flow Advisor visibility toggle.
// Uses a ValueNotifier so HomeScreen rebuilds without a full BlocBuilder.

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FinanceAssistantPrefs {
  FinanceAssistantPrefs._();

  static const _kVisible = 'flow_advisor_visible';
  static const _kRecentPatternKeys = 'flow_advisor_recent_pattern_keys_v1';
  static const _kLastInsightSig = 'flow_advisor_last_insight_sig_v1';

  /// Observable — HomeScreen listens to this for reactive rebuild.
  static final visibleListenable = ValueNotifier<bool>(true);

  /// Call once after app startup / login to restore the persisted value.
  static Future<void> syncFromDisk() async {
    final prefs = await SharedPreferences.getInstance();
    visibleListenable.value = prefs.getBool(_kVisible) ?? true;
  }

  /// Toggle visibility and persist the new value.
  static Future<void> setVisible(bool value) async {
    visibleListenable.value = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kVisible, value);
  }

  /// Alias for [setVisible] — used by AccountScreen toggle.
  static Future<void> setCardVisible(bool value) => setVisible(value);

  // ── Non-UI memory (prevents repetitive insights) ───────────────────────────

  static Future<List<String>> getRecentPatternKeys() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_kRecentPatternKeys) ?? const [];
  }

  static Future<void> pushRecentPatternKey(String key, {int max = 8}) async {
    final prefs = await SharedPreferences.getInstance();
    final list = (prefs.getStringList(_kRecentPatternKeys) ?? const <String>[])
        .where((e) => e != key)
        .toList();
    list.insert(0, key);
    await prefs.setStringList(_kRecentPatternKeys, list.take(max).toList());
  }

  static Future<String?> getLastInsightSignature() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_kLastInsightSig);
  }

  static Future<void> setLastInsightSignature(String sig) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kLastInsightSig, sig);
  }
}