// lib/features/transaction/presentation/cubit/transaction_state.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

import '../../domain/entities/transaction_entity.dart';

// ─────────────────────────────────────────────────────────────────────
// WHY 6 SEPARATE STATES (not just loading/loaded/error)?
//
// Each state gives the UI SPECIFIC information to act on:
//
//   TransactionInitial    → App just opened, nothing loaded yet
//   TransactionLoading    → Show shimmer placeholder cards
//   TransactionSubmitting → Disable Save button (prevent double-tap)
//   TransactionLoaded     → Show the list + pagination info
//   TransactionDeleted    → Show "Undo" SnackBar for 5 seconds
//   TransactionError      → Show error message, keep old list visible
//
// BlocBuilder uses buildWhen: to rebuild ONLY the widgets that care
// about specific state transitions — prevents unnecessary rebuilds.
// ─────────────────────────────────────────────────────────────────────

abstract class TransactionState extends Equatable {
  const TransactionState();
  @override
  List<Object?> get props => [];
}

/// App just opened — no data loaded yet.
class TransactionInitial extends TransactionState {}

/// Fetching transactions. Show shimmer/loading indicators.
class TransactionLoading extends TransactionState {}

/// Save is in progress — Save button must be DISABLED.
/// This is the anti-double-tap protection (Production Criteria 3).
/// BlocBuilder in AddTransactionScreen watches for this state.
class TransactionSubmitting extends TransactionState {}

/// Transactions loaded successfully.
class TransactionLoaded extends TransactionState {
  final List<TransactionEntity> transactions;

  /// Last document from Firestore — used as cursor for next page.
  /// null = first page (no cursor needed).
  final DocumentSnapshot? lastDoc;

  /// false = all transactions loaded, hide "load more" button.
  final bool hasMore;

  const TransactionLoaded({
    required this.transactions,
    this.lastDoc,
    this.hasMore = true,
  });

  @override
  List<Object?> get props => [transactions, lastDoc, hasMore];
}

/// Transaction soft-deleted. UI shows Undo SnackBar.
/// Holds the id so undoDelete(id) can restore it.
class TransactionDeleted extends TransactionState {
  final String deletedId;
  const TransactionDeleted(this.deletedId);
  @override
  List<Object?> get props => [deletedId];
}

/// An error occurred. Message is user-friendly (mapped by ErrorHandler).
class TransactionError extends TransactionState {
  final String message;
  const TransactionError(this.message);
  @override
  List<Object?> get props => [message];
}