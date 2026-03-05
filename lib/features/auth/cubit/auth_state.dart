// lib/features/auth/cubit/auth_state.dart

part of 'auth_cubit.dart';

// ══════════════════════════════════════════════════════════════
//  Auth States
// ══════════════════════════════════════════════════════════════
sealed class AuthState {}

/// App just opened — no action taken yet
final class AuthInitial extends AuthState {}

/// Any sign-in / sign-up is in progress
final class AuthLoading extends AuthState {}

/// Signed in, no PIN set yet → navigate to /pin-setup
final class AuthNeedsPinSetup extends AuthState {
  AuthNeedsPinSetup(this.user);
  final User user;
}

/// Signed in, PIN already exists → navigate to /pin-lock
final class AuthNeedsPinLock extends AuthState {
  AuthNeedsPinLock(this.user);
  final User user;
}

/// Auth failed — holds a human-readable message
final class AuthError extends AuthState {
  AuthError(this.message);
  final String message;
}

/// Password reset email sent successfully
final class AuthPasswordResetSent extends AuthState {}