import 'package:drift/drift.dart';
// DriftRemoteException is how errors cross the drift isolate boundary.
// ignore: experimental_member_use
import 'package:drift/remote.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:vaultvoice/core/errors/failure.dart';
import 'package:vaultvoice/core/errors/result.dart';

/// Runs a repository write and maps database errors to a content-free
/// [StorageFailure] so nothing throws across the repository boundary.
///
/// Only the SQLite result code is kept: driver messages can quote values.
Future<Result<T>> guardDb<T>(Future<T> Function() body) async {
  try {
    return Ok(await body());
  } on Object catch (error) {
    return Err(dbFailure(error));
  }
}

/// Maps [error] (possibly wrapped by the drift isolate) to a [Failure].
Failure dbFailure(Object error) {
  final cause = error is DriftRemoteException ? error.remoteCause : error;
  return switch (cause) {
    SqliteException(:final extendedResultCode) => StorageFailure(
      'sqlite error $extendedResultCode',
    ),
    InvalidDataException() => const StorageFailure('invalid row data'),
    _ => UnexpectedFailure(cause.runtimeType.toString()),
  };
}

/// The failure returned when a row addressed by key does not exist.
const notFound = StorageFailure('not found');

/// Reads one row; a missing row is a [notFound] failure.
Future<Result<T>> guardRow<T extends Object>(Future<T?> Function() body) =>
    guardDb(body).then(_requireRow);

Result<T> _requireRow<T extends Object>(Result<T?> result) => switch (result) {
  Ok(value: final T row) => Ok(row),
  Ok() => const Err(notFound),
  Err(:final failure) => Err(failure),
};

/// Runs an update/delete that must affect at least one row; zero affected
/// rows is a [notFound] failure.
Future<Result<void>> guardAffected(Future<int> Function() body) async {
  final result = await guardDb(body);
  return switch (result) {
    Ok(value: 0) => const Err(notFound),
    Ok() => const Ok<void>(null),
    Err(:final failure) => Err(failure),
  };
}
