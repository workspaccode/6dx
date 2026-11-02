import 'package:freezed_annotation/freezed_annotation.dart';

part 'failures.freezed.dart';

@freezed
abstract class Failure with _$Failure {
  const factory Failure.server(String message) = ServerFailure;
  const factory Failure.network(String message) = NetworkFailure;
  const factory Failure.cache(String message) = CacheFailure;
  const factory Failure.unauthorized() = UnauthorizedFailure;
  const factory Failure.unknown(String message) = UnknownFailure;
}

extension FailureMessage on Failure {
  /// Human readable message shown to the user.
  String get message => switch (this) {
        ServerFailure(:final message) => message,
        NetworkFailure(:final message) => message,
        CacheFailure(:final message) => message,
        UnauthorizedFailure() => 'انتهت الجلسة، سجّل الدخول من جديد',
        UnknownFailure(:final message) => message,
        _ => 'حدث خطأ غير متوقع',
      };
}
