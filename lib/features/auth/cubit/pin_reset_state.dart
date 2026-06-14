

part of 'pin_reset_cubit.dart';

abstract class PinResetState extends Equatable {
  const PinResetState();
  @override
  List<Object?> get props => [];
}

/// Initial / idle
class PinResetInitial extends PinResetState {}

/// Any async op in progress
class PinResetLoading extends PinResetState {}

/// Re-authentication succeeded → show new PIN screen
class PinResetVerified extends PinResetState {}

/// New PIN saved → go to /home
class PinResetComplete extends PinResetState {}

/// Any error
class PinResetError extends PinResetState {
  final String message;
  const PinResetError(this.message);
  @override
  List<Object?> get props => [message];
}