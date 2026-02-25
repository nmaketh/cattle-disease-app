import 'package:equatable/equatable.dart';

class SignupOtpChallenge extends Equatable {
  const SignupOtpChallenge({
    required this.signupToken,
    required this.email,
    this.expiresInSeconds,
  });

  final String signupToken;
  final String email;
  final int? expiresInSeconds;

  @override
  List<Object?> get props => [signupToken, email, expiresInSeconds];
}
