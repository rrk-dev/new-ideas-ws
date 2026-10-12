import 'package:vaultvoice/core/errors/failure.dart';

/// Outcome of an operation that can fail with a [Failure].
///
/// Repositories and engines return this instead of throwing across layers.
sealed class Result<T> {
  const Result();

  /// Whether this is an [Ok].
  bool get isOk => this is Ok<T>;

  /// The value, or null on failure.
  T? get valueOrNull => switch (this) {
    Ok<T>(:final value) => value,
    Err<T>() => null,
  };

  /// The failure, or null on success.
  Failure? get failureOrNull => switch (this) {
    Ok<T>() => null,
    Err<T>(:final failure) => failure,
  };

  /// Folds both cases into one value.
  R when<R>({
    required R Function(T value) ok,
    required R Function(Failure failure) err,
  }) => switch (this) {
    Ok<T>(:final value) => ok(value),
    Err<T>(:final failure) => err(failure),
  };

  /// Transforms the value, passing a failure through unchanged.
  Result<U> map<U>(U Function(T value) transform) => switch (this) {
    Ok<T>(:final value) => Ok(transform(value)),
    Err<T>(:final failure) => Err(failure),
  };
}

/// Success carrying [value].
final class Ok<T> extends Result<T> {
  const Ok(this.value);

  final T value;
}

/// Failure carrying a [Failure].
final class Err<T> extends Result<T> {
  const Err(this.failure);

  final Failure failure;
}
