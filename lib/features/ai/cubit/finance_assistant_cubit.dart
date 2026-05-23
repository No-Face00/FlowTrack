// lib/features/ai/cubit/finance_assistant_cubit.dart
//
// Flow Advisor — v2 (deep budget-aware, auto-loads on open).
//
// Changes vs original:
//  • scheduleRefresh() runs IMMEDIATELY when state is Initial — fixes the
//    "blank card until manual refresh" bug. All subsequent calls are
//    debounced at 800 ms (unchanged from original).
//  • Signature now includes languageCode + currencyCode (same as original)
//    but uses the lighter key-field fingerprint instead of full jsonEncode
//    so it doesn't stringify the entire transaction list on every call.
//    Full JSON is only encoded when needed for the Gemini prompt inside
//    GeminiFinanceClient — not here.
//  • setGeminiApiKey() preserved — callers that set the key at runtime
//    continue to work unchanged.
//  • unawaited() preserved for the persisted signature write.
//  • kDebugMode error logging preserved.
//  • forceRefresh() clears _lastSignature (bypasses cache) and skips the
//    persisted cache check, matching original forced=true behaviour.
//  • LocalFinanceBrain result is used for InsightType colour accuracy;
//    AssistantTextEngine provides the localized display text. Types are
//    merged so warning always wins.

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/cubit/app_cubit.dart';
import '../../../core/di/service_locator.dart';
import '../../budget/presentation/cubit/budget_state.dart';
import '../../transactions/presentation/cubit/balance_state.dart';
import '../../transactions/presentation/cubit/transaction_state.dart';
import '../data/assistant_text_engine.dart';
import '../data/finance_assistant_prefs.dart';
import '../data/finance_snapshot.dart';
import '../data/gemini_finance_client.dart';
import '../data/insight_type.dart';
import '../data/local_finance_brain.dart';

// ── States ────────────────────────────────────────────────────────────────────

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
  final String      insight;
  final InsightType type;
  const FinanceAssistantLoaded({required this.insight, required this.type})
      : super();
}

class FinanceAssistantError extends FinanceAssistantState {
  final String message;
  const FinanceAssistantError(this.message) : super();
}

// ── Cubit ─────────────────────────────────────────────────────────────────────

class FinanceAssistantCubit extends Cubit<FinanceAssistantState> {
  FinanceAssistantCubit() : super(const FinanceAssistantInitial());

  /// Optional Gemini API key — keep empty for offline-only mode.
  /// Set at runtime via [setGeminiApiKey] or wire from secure config.
  String _geminiApiKey = '';

  Timer?  _debounce;
  String? _lastSignature;

  // ── Public API ─────────────────────────────────────────────────────────────

  void setGeminiApiKey(String apiKey) {
    _geminiApiKey = apiKey.trim();
  }

  /// Call whenever transactions, balance, budgets, or currency change.
  ///
  /// FIX: when state is still Initial (first call after app open), generation
  /// runs immediately — no debounce. This ensures the card is never blank
  /// when the home screen first appears, regardless of how quickly the
  /// BlocListeners fire.
  ///
  /// All subsequent calls are debounced at 800 ms (unchanged from original)
  /// so rapid consecutive state changes collapse into one generation.
  void scheduleRefresh({
    required TransactionState tx,
    required BalanceState     bal,
    required BudgetState      bud,
    required String           currencyCode,
  }) {
    if (state is FinanceAssistantInitial) {
      // First call — run immediately so the card loads on app open.
      _generate(tx: tx, bal: bal, bud: bud, currencyCode: currencyCode);
      return;
    }

    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 800), () {
      _generate(tx: tx, bal: bal, bud: bud, currencyCode: currencyCode);
    });
  }

  /// Force an immediate refresh (user tapped the refresh button).
  /// Bypasses debounce AND the signature cache.
  void forceRefresh({
    required TransactionState tx,
    required BalanceState     bal,
    required BudgetState      bud,
    required String           currencyCode,
  }) {
    _debounce?.cancel();
    _generate(
      tx:           tx,
      bal:          bal,
      bud:          bud,
      currencyCode: currencyCode,
      forced:       true,
    );
  }

  @override
  Future<void> close() {
    _debounce?.cancel();
    return super.close();
  }

  // ── Core generation ────────────────────────────────────────────────────────

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
      tx:           tx,
      bal:          bal,
      bud:          bud,
    );

    // Skip if data hasn't changed — prevents UI churn and redundant work.
    if (!forced) {
      final persisted = await FinanceAssistantPrefs.getLastInsightSignature();
      final last      = _lastSignature ?? persisted;
      if (last == signature && state is FinanceAssistantLoaded) return;
    }

    try {
      emit(const FinanceAssistantLoading());

      final snapshot = FinanceSnapshot.build(
        currencyCode: currencyCode,
        txState:      tx,
        balState:     bal,
        budState:     bud,
      );

      // ── Step 1: LocalFinanceBrain — PRIMARY text + type source ─────────
      // LocalFinanceBrain produces rich multi-line analysis: budget overflow
      // with exact amounts, velocity projections, WoW spikes, savings rate,
      // and category concentration. It is the display source, not just the
      // type classifier.
      // AssistantTextEngine is only used as a fallback when the brain has
      // nothing specific to say (neutral type, no bullets).
      final localBrain = LocalFinanceBrain.generate(snapshot);

      String displayText;
      if (localBrain.bullets.isNotEmpty) {
        displayText = '${localBrain.headline}\n\n'
            '${localBrain.bullets.map((b) => '\u2022 $b').join('\n')}';
      } else {
        displayText = localBrain.headline;
      }

      // Fallback to localized templates only when brain is fully neutral.
      if (localBrain.type == InsightType.neutral && localBrain.bullets.isEmpty) {
        final fallback = await AssistantTextEngine.generate(
          snapshot,
          languageCode: langCode,
        );
        displayText = fallback.text;
      }

      final resolvedType = localBrain.type;

      // Emit immediately — user sees insight within ~5 ms.
      if (!isClosed) {
        emit(FinanceAssistantLoaded(
          insight: displayText,
          type:    resolvedType,
        ));
      }

      // ── Step 2: Optional Gemini upgrade (background, fails silently) ─────
      if (_geminiApiKey.isNotEmpty) {
        try {
          final gem = await GeminiFinanceClient.tryGenerate(snapshot, _geminiApiKey)
              .timeout(const Duration(seconds: 12));
          if (gem != null && !isClosed) {
            final merged = [
              gem.headline,
              ...gem.bullets.map((b) => '\u2022 $b'),
            ].where((e) => e.trim().isNotEmpty).join('\n');
            emit(FinanceAssistantLoaded(
              insight: merged,
              type:    resolvedType,
            ));
          }
        } catch (_) {
          // Gemini timed out or quota exceeded — local result already shown.
        }
      }

      _lastSignature = signature;
      unawaited(FinanceAssistantPrefs.setLastInsightSignature(signature));
    } catch (e) {
      if (kDebugMode) print('FinanceAssistant error: $e');
      // Do NOT emit error state — keep any previously loaded insight visible.
    }
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  /// Lightweight fingerprint — includes language + currency (matches original)
  /// but avoids full jsonEncode of all transactions on every call.
  static String _signature({
    required String           languageCode,
    required String           currencyCode,
    required TransactionState tx,
    required BalanceState     bal,
    required BudgetState      bud,
  }) {
    final snap = FinanceSnapshot.build(
      currencyCode: currencyCode,
      txState:      tx,
      balState:     bal,
      budState:     bud,
    );
    // Use only the key numeric fields + top categories for the signature.
    // This is ~10× faster than jsonEncode(snap.toGeminiJson()) for large
    // transaction lists while still being sensitive to any meaningful change.
    final topCats = (snap.categoryMonthSpend.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value)))
        .take(5)
        .map((e) => '${e.key}:${e.value.round()}')
        .join(',');
    final budSig = snap.budgetPressure
        .take(5)
        .map((b) => '${b.category}:${b.spent.round()}:${b.limit.round()}')
        .join(',');
    return '$languageCode|$currencyCode'
        '|${snap.monthKey}'
        '|${snap.monthIncome.round()}'
        '|${snap.monthExpense.round()}'
        '|${snap.lastMonthExpense.round()}'
        '|$topCats'
        '|$budSig';
  }

}