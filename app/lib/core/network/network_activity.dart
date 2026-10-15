import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';

/// What happened to one request the app tried to make (SEC-02).
enum NetworkOutcome {
  /// Sent; [NetworkActivityEntry.statusCode] holds the answer.
  completed,

  /// Refused by the gateway before anything left the device (host not
  /// allowlisted, not https, offline mode).
  denied,

  /// Sent but failed (no connection, TLS error, …).
  failed,

  /// Authorised for a native transport (iOS background download session,
  /// MDL-02); the OS performs the transfer.
  handedToSystem,
}

/// One row of the in-app "Network activity" log: timestamp, host, path,
/// bytes. Never headers, bodies or query strings (signed CDN URLs carry
/// tokens in the query).
class NetworkActivityEntry {
  const NetworkActivityEntry({
    required this.at,
    required this.host,
    required this.path,
    required this.outcome,
    this.statusCode,
    this.bytes,
  });

  factory NetworkActivityEntry.request(
    DateTime at,
    Uri uri,
    NetworkOutcome outcome, {
    int? statusCode,
    int? bytes,
  }) => NetworkActivityEntry(
    at: at.toUtc(),
    host: uri.host,
    path: uri.path.isEmpty ? '/' : uri.path,
    outcome: outcome,
    statusCode: statusCode,
    bytes: bytes,
  );

  static NetworkActivityEntry? fromJson(Object? json) {
    if (json is! Map<String, Object?>) return null;
    final at = json['at'];
    final host = json['host'];
    final path = json['path'];
    final outcome = NetworkOutcome.values.asNameMap()[json['outcome']];
    if (at is! int || host is! String || path is! String || outcome == null) {
      return null;
    }
    return NetworkActivityEntry(
      at: DateTime.fromMillisecondsSinceEpoch(at, isUtc: true),
      host: host,
      path: path,
      outcome: outcome,
      statusCode: json['status'] as int?,
      bytes: json['bytes'] as int?,
    );
  }

  final DateTime at;
  final String host;
  final String path;
  final NetworkOutcome outcome;
  final int? statusCode;
  final int? bytes;

  Map<String, Object?> toJson() => {
    'at': at.millisecondsSinceEpoch,
    'host': host,
    'path': path,
    'outcome': outcome.name,
    'status': ?statusCode,
    'bytes': ?bytes,
  };
}

/// Bounded log of every request (newest last), optionally persisted as JSON
/// lines so it survives restarts. Lives under `vv/network/` (wiped by "Delete
/// all data", never backed up).
class NetworkActivityLog {
  NetworkActivityLog({this.file, this.capacity = 500}) {
    _load();
  }

  final File? file;
  final int capacity;
  final _entries = ListQueue<NetworkActivityEntry>();
  final _changes = StreamController<List<NetworkActivityEntry>>.broadcast();

  List<NetworkActivityEntry> get entries => List.unmodifiable(_entries);

  /// Current entries, then every change.
  Stream<List<NetworkActivityEntry>> watch() async* {
    yield entries;
    yield* _changes.stream;
  }

  void record(NetworkActivityEntry entry) {
    _entries.addLast(entry);
    var trimmed = false;
    while (_entries.length > capacity) {
      _entries.removeFirst();
      trimmed = true;
    }
    _persist(entry, rewrite: trimmed);
    if (!_changes.isClosed) _changes.add(entries);
  }

  void clear() {
    _entries.clear();
    _persist(null, rewrite: true);
    if (!_changes.isClosed) _changes.add(entries);
  }

  void _load() {
    final f = file;
    if (f == null) return;
    try {
      if (!f.existsSync()) return;
      for (final line in f.readAsLinesSync()) {
        final e = NetworkActivityEntry.fromJson(_decode(line));
        if (e != null) _entries.addLast(e);
      }
      while (_entries.length > capacity) {
        _entries.removeFirst();
      }
    } on FileSystemException {
      // The log is informational: start empty.
    }
  }

  static Object? _decode(String line) {
    try {
      return jsonDecode(line);
    } on FormatException {
      return null;
    }
  }

  void _persist(NetworkActivityEntry? entry, {required bool rewrite}) {
    final f = file;
    if (f == null) return;
    try {
      f.parent.createSync(recursive: true);
      if (rewrite) {
        f.writeAsStringSync(
          _entries.map((e) => '${jsonEncode(e.toJson())}\n').join(),
        );
      } else if (entry != null) {
        f.writeAsStringSync(
          '${jsonEncode(entry.toJson())}\n',
          mode: FileMode.append,
        );
      }
    } on FileSystemException {
      // Best effort.
    }
  }

  Future<void> dispose() => _changes.close();
}
