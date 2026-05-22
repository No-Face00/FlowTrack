// lib/features/home/finance/finance_assistant_cubit.dart
//
// Flow Advisor — Gemini-powered financial insight card on the Home screen.
//
// KEY DESIGN:
//   • Language-aware: all AI responses are in the app's selected language.
//   • Debounced: rapid state changes (e.g. multiple transactions loading)
//     are collapsed into a single Gemini call after 800ms of quiet.
//   • Fallback: if Gemini is unavailable or quota exceeded, falls back to
//     a static, fully translated insight.
//   • No stale cache: language change always triggers a new generation.

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/cubit/app_cubit.dart';
import '../../../core/di/service_locator.dart';
import '../../budget/presentation/cubit/budget_state.dart';
import '../../transactions/presentation/cubit/balance_state.dart';
import '../../transactions/presentation/cubit/transaction_state.dart';
import 'assistant_text_engine.dart';
import 'finance_assistant_prefs.dart';
import 'finance_snapshot.dart';
import 'gemini_finance_client.dart';
import 'insight_type.dart';

// ── State ─────────────────────────────────────────────────────────────────────

abstract class FinanceAssistantState {
  const FinanceAssistantState();
}

class FinanceAssistantInitial extends FinanceAssistantState {
  const FinanceAssistantInitial() : super();
}

class FinanceAssistantLoading extends FinanceAssistantState {
  const FinanceAssistantLoading() : super();
}

class FinanceAssistantLoaded extends FinanceAssistantState {
  final String     insight;
  final InsightType type;
  const FinanceAssistantLoaded({required this.insight, required this.type}) : super();
}

class FinanceAssistantError extends FinanceAssistantState {
  final String message;
  const FinanceAssistantError(this.message) : super();
}

// ── Cubit ─────────────────────────────────────────────────────────────────────

class FinanceAssistantCubit extends Cubit<FinanceAssistantState> {
  FinanceAssistantCubit() : super(FinanceAssistantInitial());

  /// Optional Gemini API key.
  ///
  /// Keep empty for offline-only assistant. If you want to enable live Gemini:
  /// - set it at runtime (recommended) via [setGeminiApiKey]
  /// - or wire it from secure remote config / secrets
  String _geminiApiKey = '';

  Timer?  _debounce;
  String? _lastSignature;

  // ── Public API ──────────────────────────────────────────────────────────────

  void setGeminiApiKey(String apiKey) {
    _geminiApiKey = apiKey.trim();
  }

  /// Call this whenever transactions, balance, budgets, or currency change.
  /// Debounced 800ms so rapid consecutive calls result in ONE Gemini request.
  void scheduleRefresh({
    required TransactionState tx,
    required BalanceState     bal,
    required BudgetState      bud,
    required String           currencyCode,
  }) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 800), () {
      _generate(tx: tx, bal: bal, bud: bud, currencyCode: currencyCode);
    });
  }

  /// Force an immediate refresh (e.g. user taps the refresh button).
  void forceRefresh({
    required TransactionState tx,
    required BalanceState     bal,
    required BudgetState      bud,
    required String           currencyCode,
  }) {
    _debounce?.cancel();
    _generate(tx: tx, bal: bal, bud: bud, currencyCode: currencyCode, forced: true);
  }

  @override
  Future<void> close() {
    _debounce?.cancel();
    return super.close();
  }

  // ── Private: main generation ────────────────────────────────────────────────

  Future<void> _generate({
    required TransactionState tx,
    required BalanceState     bal,
    required BudgetState      bud,
    required String           currencyCode,
    bool forced = false,
  }) async {
    if (isClosed) return;

    final langCode = getIt<AppCubit>().state.languageCode;
    final signature = _signature(
      languageCode: langCode,
      currencyCode: currencyCode,
      tx: tx,
      bal: bal,
      bud: bud,
    );

    // Skip regenerating if nothing materially changed (prevents spam + UI churn)
    if (!forced) {
      final persisted = await FinanceAssistantPrefs.getLastInsightSignature();
      final last = _lastSignature ?? persisted;
      if (last == signature) return;
    }

    try {
      emit(FinanceAssistantLoading());

      final snapshot = FinanceSnapshot.build(
        currencyCode: currencyCode,
        txState: tx,
        balState: bal,
        budState: bud,
      );

      // 1) Offline-first dynamic insight (localized + rotating)
      var generated = await AssistantTextEngine.generate(
        snapshot,
        languageCode: langCode,
      );

      // 2) Optional Gemini enhancement (kept short + structured)
      if (_geminiApiKey.isNotEmpty) {
        try {
          final gem = await GeminiFinanceClient.tryGenerate(snapshot, _geminiApiKey);
          if (gem != null) {
            final merged = <String>[
              gem.headline,
              ...gem.bullets.map((b) => '• $b'),
            ].where((e) => e.trim().isNotEmpty).join('\n');
            generated = GeneratedInsight(text: merged, type: generated.type);
          }
        } catch (_) {}
      }

      if (!isClosed) {
        emit(FinanceAssistantLoaded(insight: generated.text, type: generated.type));
      }

      _lastSignature = signature;
      unawaited(FinanceAssistantPrefs.setLastInsightSignature(signature));
    } catch (e) {
      if (kDebugMode) {
        // ignore: avoid_print
        print('FinanceAssistant error: $e');
      }
    }
  }

  static String _signature({
    required String languageCode,
    required String currencyCode,
    required TransactionState tx,
    required BalanceState bal,
    required BudgetState bud,
  }) {
    // Use snapshot JSON (stable ordering) + language/currency as signature input.
    final snap = FinanceSnapshot.build(
      currencyCode: currencyCode,
      txState: tx,
      balState: bal,
      budState: bud,
    ).toGeminiJson();
    final json = jsonEncode(snap);
    return '$languageCode|$currencyCode|$json';
  }
}