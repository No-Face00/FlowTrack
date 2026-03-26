// lib/features/transaction/presentation/cubit/transaction_state.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

import '../../domain/entities/transaction_entity.dart';

// ─────────────────────────────────────────────────────────────────────
// WHY 7 SEPARATE STATES?
//
//   TransactionInitial    → App just opened, nothing loaded yet
//   TransactionLoading    → Show shimmer placeholder cards
//   TransactionSubmitting → Disable Save button (prevent double-tap)
//   TransactionLoaded     → Show the list (emitted by Firestore stream)
//   TransactionSaved      → One-shot "save succeeded" signal → pop screen
//   TransactionDeleted    → Show "Undo" SnackBar for 5 seconds
//   TransactionError      → Show error message, keep old list visible
//
// WHY TransactionSaved separate from TransactionLoaded?
//   TransactionLoaded is emitted continuously by the Firestore stream.
//   If AddTransactionScreen listened for TransactionLoaded to pop,
//   it would pop immediately on open (the stream already has loaded data).
//   TransactionSaved is a distinct one-time signal emitted ONLY after
//   a successful save — it is safe to use as the pop trigger.
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
class TransactionSubmitting extends TransactionState {}

/// ONE-TIME save-success signal — AddTransactionScreen pops on this.
/// Distinct from TransactionLoaded which the Firestore stream emits
/// continuously (including when the screen first opens).
class TransactionSaved extends TransactionState {}

/// Transactions loaded successfully (emitted by the real-time stream).
class TransactionLoaded extends TransactionState {
  final List<TransactionEntity> transactions;
  final DocumentSnapshot? lastDoc;
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
class TransactionDeleted extends TransactionState {
  final String deletedId;
  const TransactionDeleted(this.deletedId);
  @override
  List<Object?> get props => [deletedId];
}

/// An error occurred. Message is user-friendly.
class TransactionError extends TransactionState {
  final String message;
  const TransactionError(this.message);
  @override
  List<Object?> get props => [message];
}