// lib/features/auth/cubit/auth_state.dart

part of 'auth_cubit.dart';

// ══════════════════════════════════════════════════════════════
//  Auth States
// ══════════════════════════════════════════════════════════════
sealed class AuthState {}

/// App just opened — no action taken yet
final class AuthInitial extends AuthState {}

/// Any sign-in is in progress (email or Google)
final class AuthLoading extends AuthState {}

/// Successfully authenticated
final class AuthSuccess extends AuthState {
  AuthSuccess(this.user);
  final User user;
}

/// Auth failed — holds a human-readable message
final class AuthError extends AuthState {
  AuthError(this.message);
  final String message;
}

/// Password reset email sent
final class AuthPasswordResetSent extends AuthState {}