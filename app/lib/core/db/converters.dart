import 'dart:convert';

import 'package:drift/drift.dart';

/// JSON object stored in a TEXT column.
typedef JsonMap = Map<String, Object?>;

/// Stores a [DateTime] as UTC epoch milliseconds (vv-local-database rule:
/// timestamps are UTC epoch ms ints, never local time or seconds).
class EpochMsConverter extends TypeConverter<DateTime, int> {
  const EpochMsConverter();

  @override
  DateTime fromSql(int fromDb) =>
      DateTime.fromMillisecondsSinceEpoch(fromDb, isUtc: true);

  @override
  int toSql(DateTime value) => value.toUtc().millisecondsSinceEpoch;
}

/// Stores a JSON object as TEXT.
class JsonMapConverter extends TypeConverter<JsonMap, String> {
  const JsonMapConverter();

  @override
  JsonMap fromSql(String fromDb) {
    final decoded = jsonDecode(fromDb);
    return decoded is Map<String, Object?> ? decoded : <String, Object?>{};
  }

  @override
  String toSql(JsonMap value) => jsonEncode(value);
}

/// Stores a list of strings (e.g. tags) as a JSON array in TEXT.
class StringListConverter extends TypeConverter<List<String>, String> {
  const StringListConverter();

  @override
  List<String> fromSql(String fromDb) {
    final decoded = jsonDecode(fromDb);
    if (decoded is! List<Object?>) return const [];
    return [for (final e in decoded) ?e?.toString()];
  }

  @override
  String toSql(List<String> value) => jsonEncode(value);
}
