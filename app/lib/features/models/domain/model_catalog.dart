import 'dart:convert';

import 'package:vaultvoice/core/errors/failure.dart';
import 'package:vaultvoice/core/errors/result.dart';

/// Catalog `schema` values this app can read. Anything else is rejected
/// (CatalogRejection.unknownSchema) so a future format is never half-parsed.
const kSupportedCatalogSchemas = {1};

/// Model categories (catalog `type`).
enum ModelType {
  stt('stt'),
  llm('llm'),
  vad('vad'),
  diarizationSeg('diarization-seg'),
  diarizationEmb('diarization-emb'),
  coremlEncoder('coreml-encoder');

  ModelType(this.wire);
  final String wire;
}

/// Entitlement tier that unlocks a model (catalog `tier`).
enum ModelTier {
  free('free'),
  pro('pro'),
  enterprise('enterprise');

  ModelTier(this.wire);
  final String wire;
}

/// Device performance tier (catalog `recommended_device_tiers`).
enum DeviceTier {
  low('low'),
  mid('mid'),
  high('high');

  DeviceTier(this.wire);
  final String wire;
}

/// `major.minor.patch`, compared numerically.
class SemVer implements Comparable<SemVer> {
  const SemVer(this.major, this.minor, this.patch);

  /// Parses `x.y.z` (no leading zeros, no pre-release); null if invalid.
  static SemVer? tryParse(String s) {
    final m = _semverRe.firstMatch(s);
    if (m == null) return null;
    return SemVer(
      int.parse(m.group(1)!),
      int.parse(m.group(2)!),
      int.parse(m.group(3)!),
    );
  }

  static final _semverRe = RegExp(
    r'^(0|[1-9]\d{0,8})\.(0|[1-9]\d{0,8})\.(0|[1-9]\d{0,8})$',
  );

  final int major;
  final int minor;
  final int patch;

  @override
  int compareTo(SemVer other) => major != other.major
      ? major.compareTo(other.major)
      : minor != other.minor
      ? minor.compareTo(other.minor)
      : patch.compareTo(other.patch);

  @override
  String toString() => '$major.$minor.$patch';
}

/// One downloadable model file (catalog `models[]`).
class CatalogModel {
  const CatalogModel({
    required this.id,
    required this.type,
    required this.version,
    required this.displayName,
    required this.tier,
    required this.file,
    required this.size,
    required this.sha256,
    required this.minRamMb,
    required this.recommendedDeviceTiers,
    required this.license,
    required this.licenseUrl,
    required this.urls,
    required this.companions,
    this.attribution,
    this.minAppVersion,
  });

  final String id;
  final ModelType type;
  final String version;
  final String displayName;
  final ModelTier tier;

  /// Plain file name (no path separators); installed as `models/<id>/<file>`.
  final String file;

  /// Exact size in bytes.
  final int size;

  /// Lower-case hex SHA-256 of the file.
  final String sha256;
  final int minRamMb;
  final List<DeviceTier> recommendedDeviceTiers;
  final String license;
  final Uri licenseUrl;
  final String? attribution;
  final SemVer? minAppVersion;

  /// Primary first, then mirrors (all https, no query).
  final List<Uri> urls;

  /// Ids of models that must be installed alongside (e.g. CoreML encoder).
  final List<String> companions;
}

/// A verified model catalog. Build only via [ModelCatalog.parse] after the
/// signature check in `CatalogVerifier`.
class ModelCatalog {
  const ModelCatalog({
    required this.schema,
    required this.issuedAt,
    required this.minAppVersion,
    required this.models,
  });

  final int schema;

  /// UTC issue time; used for rollback protection.
  final DateTime issuedAt;
  final SemVer minAppVersion;
  final List<CatalogModel> models;

  /// Model by id, or null.
  CatalogModel? byId(String id) {
    for (final m in models) {
      if (m.id == id) return m;
    }
    return null;
  }

  /// Models of [type] usable by an app at [appVersion].
  List<CatalogModel> usable(ModelType type, SemVer appVersion) => [
    for (final m in models)
      if (m.type == type &&
          (m.minAppVersion == null ||
              m.minAppVersion!.compareTo(appVersion) <= 0))
        m,
  ];

  /// Parses and validates catalog bytes. Mirrors `validate_catalog` in
  /// `tools/model-catalog/catalog.py`; keep both in sync.
  static Result<ModelCatalog> parse(List<int> bytes) {
    final Object? doc;
    try {
      doc = jsonDecode(utf8.decode(bytes));
    } on FormatException {
      return Err(CatalogFailure(CatalogRejection.malformed));
    }
    if (doc is! Map<String, Object?>) return _malformed;
    final schema = doc['schema'];
    if (schema is! int || !kSupportedCatalogSchemas.contains(schema)) {
      return Err(CatalogFailure(CatalogRejection.unknownSchema));
    }
    try {
      final issuedAt = _time(doc['issued_at']);
      final minApp = _semver(doc['min_app_version']);
      final rawModels = doc['models'];
      if (rawModels is! List<Object?> || rawModels.isEmpty) {
        throw const _Invalid();
      }
      final models = [for (final m in rawModels) _model(m)];
      final ids = <String>{};
      for (final m in models) {
        if (!ids.add(m.id)) throw const _Invalid();
      }
      for (final m in models) {
        for (final c in m.companions) {
          if (c == m.id || !ids.contains(c)) throw const _Invalid();
        }
      }
      return Ok(
        ModelCatalog(
          schema: schema,
          issuedAt: issuedAt,
          minAppVersion: minApp,
          models: List.unmodifiable(models),
        ),
      );
    } on _Invalid {
      return _malformed;
    }
  }

  static final _malformed = Err<ModelCatalog>(
    CatalogFailure(CatalogRejection.malformed),
  );
}

class _Invalid implements Exception {
  const _Invalid();
}

final _idRe = RegExp(r'^[a-z0-9][a-z0-9._-]{0,63}$');
final _fileRe = RegExp(r'^[A-Za-z0-9][A-Za-z0-9._-]{0,127}$');
final _shaRe = RegExp(r'^[0-9a-f]{64}$');
final _timeRe = RegExp(r'^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z$');

T _req<T>(Object? v) => v is T ? v : throw const _Invalid();

String _str(Object? v) {
  final s = _req<String>(v);
  if (s.trim().isEmpty) throw const _Invalid();
  return s;
}

DateTime _time(Object? v) {
  final s = _req<String>(v);
  if (!_timeRe.hasMatch(s)) throw const _Invalid();
  final t = DateTime.tryParse(s);
  // DateTime.parse normalises overflow (e.g. month 13); require round-trip.
  if (t == null ||
      !t.isUtc ||
      t.toIso8601String() != '${s.substring(0, 19)}.000Z') {
    throw const _Invalid();
  }
  return t;
}

SemVer _semver(Object? v) =>
    SemVer.tryParse(_req<String>(v)) ?? (throw const _Invalid());

Uri _https(Object? v) {
  final u = Uri.tryParse(_req<String>(v));
  if (u == null ||
      u.scheme != 'https' ||
      u.host.isEmpty ||
      u.userInfo.isNotEmpty ||
      u.hasPort ||
      u.hasQuery ||
      u.hasFragment) {
    throw const _Invalid();
  }
  return u;
}

E _enum<E extends Enum>(List<E> values, String Function(E) wire, Object? v) {
  final s = _req<String>(v);
  for (final e in values) {
    if (wire(e) == s) return e;
  }
  throw const _Invalid();
}

CatalogModel _model(Object? raw) {
  final m = _req<Map<String, Object?>>(raw);
  final id = _req<String>(m['id']);
  if (!_idRe.hasMatch(id)) throw const _Invalid();
  final file = _req<String>(m['file']);
  if (!_fileRe.hasMatch(file)) throw const _Invalid();
  final size = _req<int>(m['size']);
  final sha = _req<String>(m['sha256']);
  final ram = _req<int>(m['min_ram_mb']);
  if (size <= 0 || ram < 0 || !_shaRe.hasMatch(sha)) throw const _Invalid();

  final tiers = [
    for (final t in _req<List<Object?>>(m['recommended_device_tiers']))
      _enum(DeviceTier.values, (e) => e.wire, t),
  ];
  if (tiers.isEmpty || tiers.toSet().length != tiers.length) {
    throw const _Invalid();
  }
  final urls = [for (final u in _req<List<Object?>>(m['urls'])) _https(u)];
  if (urls.isEmpty || urls.toSet().length != urls.length) {
    throw const _Invalid();
  }
  final attribution = m['attribution'];
  final minApp = m['min_app_version'];
  if (!m.containsKey('attribution')) throw const _Invalid();

  return CatalogModel(
    id: id,
    type: _enum(ModelType.values, (e) => e.wire, m['type']),
    version: _str(m['version']),
    displayName: _str(m['display_name']),
    tier: _enum(ModelTier.values, (e) => e.wire, m['tier']),
    file: file,
    size: size,
    sha256: sha,
    minRamMb: ram,
    recommendedDeviceTiers: List.unmodifiable(tiers),
    license: _str(m['license']),
    licenseUrl: _https(m['license_url']),
    attribution: attribution == null ? null : _str(attribution),
    minAppVersion: minApp == null ? null : _semver(minApp),
    urls: List.unmodifiable(urls),
    companions: List.unmodifiable([
      for (final c in _req<List<Object?>>(m['companions'])) _req<String>(c),
    ]),
  );
}
