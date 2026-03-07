// lib/features/auth/cubit/pin_state.dart

part of 'pin_cubit.dart';

abstract class PinState extends Equatable {
  const PinState();
  @override
  List<Object?> get props => [];
}

class PinInitial        extends PinState {}
class PinLoading        extends PinState {}
class PinSetSuccess     extends PinState {}   // PIN saved → go to /welcome
class PinVerifySuccess  extends PinState {}   // PIN correct → go to /home
class PinResetSuccess   extends PinState {}   // PIN deleted + signed out → go to /login

class PinError extends PinState {
  final String message;
  const PinError(this.message);
  @override
  List<Object?> get props => [message];
}

class PinWrongAttempt extends PinState {
  final int attemptsLeft;
  const PinWrongAttempt(this.attemptsLeft);
  @override
  List<Object?> get props => [attemptsLeft];
}