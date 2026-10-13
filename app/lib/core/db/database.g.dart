// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'database.dart';

// ignore_for_file: type=lint
class $RecordingsTable extends Recordings
    with TableInfo<$RecordingsTable, RecordingRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $RecordingsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  @override
  late final GeneratedColumnWithTypeConverter<DateTime, int> createdAt =
      GeneratedColumn<int>(
        'created_at',
        aliasedName,
        false,
        type: DriftSqlType.int,
        requiredDuringInsert: true,
      ).withConverter<DateTime>($RecordingsTable.$convertercreatedAt);
  static const VerificationMeta _durationMsMeta = const VerificationMeta(
    'durationMs',
  );
  @override
  late final GeneratedColumn<int> durationMs = GeneratedColumn<int>(
    'duration_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  @override
  late final GeneratedColumnWithTypeConverter<RecordingStatus, String> status =
      GeneratedColumn<String>(
        'status',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<RecordingStatus>($RecordingsTable.$converterstatus);
  @override
  late final GeneratedColumnWithTypeConverter<RecordingSource, String> source =
      GeneratedColumn<String>(
        'source',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<RecordingSource>($RecordingsTable.$convertersource);
  static const VerificationMeta _profileIdMeta = const VerificationMeta(
    'profileId',
  );
  @override
  late final GeneratedColumn<String> profileId = GeneratedColumn<String>(
    'profile_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  late final GeneratedColumnWithTypeConverter<List<String>, String> tags =
      GeneratedColumn<String>(
        'tags',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
        defaultValue: const Constant('[]'),
      ).withConverter<List<String>>($RecordingsTable.$convertertags);
  @override
  late final GeneratedColumnWithTypeConverter<DateTime?, int>
  consentConfirmedAt = GeneratedColumn<int>(
    'consent_confirmed_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  ).withConverter<DateTime?>($RecordingsTable.$converterconsentConfirmedAtn);
  @override
  late final GeneratedColumnWithTypeConverter<DateTime?, int> importAttestedAt =
      GeneratedColumn<int>(
        'import_attested_at',
        aliasedName,
        true,
        type: DriftSqlType.int,
        requiredDuringInsert: false,
      ).withConverter<DateTime?>($RecordingsTable.$converterimportAttestedAtn);
  @override
  late final GeneratedColumnWithTypeConverter<StopReason?, String> stopReason =
      GeneratedColumn<String>(
        'stop_reason',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      ).withConverter<StopReason?>($RecordingsTable.$converterstopReasonn);
  static const VerificationMeta _recoveredMeta = const VerificationMeta(
    'recovered',
  );
  @override
  late final GeneratedColumn<bool> recovered = GeneratedColumn<bool>(
    'recovered',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("recovered" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    title,
    createdAt,
    durationMs,
    status,
    source,
    profileId,
    tags,
    consentConfirmedAt,
    importAttestedAt,
    stopReason,
    recovered,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'recordings';
  @override
  VerificationContext validateIntegrity(
    Insertable<RecordingRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    }
    if (data.containsKey('duration_ms')) {
      context.handle(
        _durationMsMeta,
        durationMs.isAcceptableOrUnknown(data['duration_ms']!, _durationMsMeta),
      );
    }
    if (data.containsKey('profile_id')) {
      context.handle(
        _profileIdMeta,
        profileId.isAcceptableOrUnknown(data['profile_id']!, _profileIdMeta),
      );
    }
    if (data.containsKey('recovered')) {
      context.handle(
        _recoveredMeta,
        recovered.isAcceptableOrUnknown(data['recovered']!, _recoveredMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  RecordingRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return RecordingRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      createdAt: $RecordingsTable.$convertercreatedAt.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.int,
          data['${effectivePrefix}created_at'],
        )!,
      ),
      durationMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}duration_ms'],
      )!,
      status: $RecordingsTable.$converterstatus.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}status'],
        )!,
      ),
      source: $RecordingsTable.$convertersource.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}source'],
        )!,
      ),
      profileId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}profile_id'],
      ),
      tags: $RecordingsTable.$convertertags.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}tags'],
        )!,
      ),
      consentConfirmedAt: $RecordingsTable.$converterconsentConfirmedAtn
          .fromSql(
            attachedDatabase.typeMapping.read(
              DriftSqlType.int,
              data['${effectivePrefix}consent_confirmed_at'],
            ),
          ),
      importAttestedAt: $RecordingsTable.$converterimportAttestedAtn.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.int,
          data['${effectivePrefix}import_attested_at'],
        ),
      ),
      stopReason: $RecordingsTable.$converterstopReasonn.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}stop_reason'],
        ),
      ),
      recovered: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}recovered'],
      )!,
    );
  }

  @override
  $RecordingsTable createAlias(String alias) {
    return $RecordingsTable(attachedDatabase, alias);
  }

  static TypeConverter<DateTime, int> $convertercreatedAt =
      const EpochMsConverter();
  static JsonTypeConverter2<RecordingStatus, String, String> $converterstatus =
      const EnumNameConverter<RecordingStatus>(RecordingStatus.values);
  static JsonTypeConverter2<RecordingSource, String, String> $convertersource =
      const EnumNameConverter<RecordingSource>(RecordingSource.values);
  static TypeConverter<List<String>, String> $convertertags =
      const StringListConverter();
  static TypeConverter<DateTime, int> $converterconsentConfirmedAt =
      const EpochMsConverter();
  static TypeConverter<DateTime?, int?> $converterconsentConfirmedAtn =
      NullAwareTypeConverter.wrap($converterconsentConfirmedAt);
  static TypeConverter<DateTime, int> $converterimportAttestedAt =
      const EpochMsConverter();
  static TypeConverter<DateTime?, int?> $converterimportAttestedAtn =
      NullAwareTypeConverter.wrap($converterimportAttestedAt);
  static JsonTypeConverter2<StopReason, String, String> $converterstopReason =
      const EnumNameConverter<StopReason>(StopReason.values);
  static JsonTypeConverter2<StopReason?, String?, String?>
  $converterstopReasonn = JsonTypeConverter2.asNullable($converterstopReason);
}

class RecordingRow extends DataClass implements Insertable<RecordingRow> {
  final String id;
  final String title;
  final DateTime createdAt;
  final int durationMs;
  final RecordingStatus status;
  final RecordingSource source;
  final String? profileId;
  final List<String> tags;
  final DateTime? consentConfirmedAt;
  final DateTime? importAttestedAt;
  final StopReason? stopReason;
  final bool recovered;
  const RecordingRow({
    required this.id,
    required this.title,
    required this.createdAt,
    required this.durationMs,
    required this.status,
    required this.source,
    this.profileId,
    required this.tags,
    this.consentConfirmedAt,
    this.importAttestedAt,
    this.stopReason,
    required this.recovered,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['title'] = Variable<String>(title);
    {
      map['created_at'] = Variable<int>(
        $RecordingsTable.$convertercreatedAt.toSql(createdAt),
      );
    }
    map['duration_ms'] = Variable<int>(durationMs);
    {
      map['status'] = Variable<String>(
        $RecordingsTable.$converterstatus.toSql(status),
      );
    }
    {
      map['source'] = Variable<String>(
        $RecordingsTable.$convertersource.toSql(source),
      );
    }
    if (!nullToAbsent || profileId != null) {
      map['profile_id'] = Variable<String>(profileId);
    }
    {
      map['tags'] = Variable<String>(
        $RecordingsTable.$convertertags.toSql(tags),
      );
    }
    if (!nullToAbsent || consentConfirmedAt != null) {
      map['consent_confirmed_at'] = Variable<int>(
        $RecordingsTable.$converterconsentConfirmedAtn.toSql(
          consentConfirmedAt,
        ),
      );
    }
    if (!nullToAbsent || importAttestedAt != null) {
      map['import_attested_at'] = Variable<int>(
        $RecordingsTable.$converterimportAttestedAtn.toSql(importAttestedAt),
      );
    }
    if (!nullToAbsent || stopReason != null) {
      map['stop_reason'] = Variable<String>(
        $RecordingsTable.$converterstopReasonn.toSql(stopReason),
      );
    }
    map['recovered'] = Variable<bool>(recovered);
    return map;
  }

  RecordingsCompanion toCompanion(bool nullToAbsent) {
    return RecordingsCompanion(
      id: Value(id),
      title: Value(title),
      createdAt: Value(createdAt),
      durationMs: Value(durationMs),
      status: Value(status),
      source: Value(source),
      profileId: profileId == null && nullToAbsent
          ? const Value.absent()
          : Value(profileId),
      tags: Value(tags),
      consentConfirmedAt: consentConfirmedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(consentConfirmedAt),
      importAttestedAt: importAttestedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(importAttestedAt),
      stopReason: stopReason == null && nullToAbsent
          ? const Value.absent()
          : Value(stopReason),
      recovered: Value(recovered),
    );
  }

  factory RecordingRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return RecordingRow(
      id: serializer.fromJson<String>(json['id']),
      title: serializer.fromJson<String>(json['title']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      durationMs: serializer.fromJson<int>(json['durationMs']),
      status: $RecordingsTable.$converterstatus.fromJson(
        serializer.fromJson<String>(json['status']),
      ),
      source: $RecordingsTable.$convertersource.fromJson(
        serializer.fromJson<String>(json['source']),
      ),
      profileId: serializer.fromJson<String?>(json['profileId']),
      tags: serializer.fromJson<List<String>>(json['tags']),
      consentConfirmedAt: serializer.fromJson<DateTime?>(
        json['consentConfirmedAt'],
      ),
      importAttestedAt: serializer.fromJson<DateTime?>(
        json['importAttestedAt'],
      ),
      stopReason: $RecordingsTable.$converterstopReasonn.fromJson(
        serializer.fromJson<String?>(json['stopReason']),
      ),
      recovered: serializer.fromJson<bool>(json['recovered']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'title': serializer.toJson<String>(title),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'durationMs': serializer.toJson<int>(durationMs),
      'status': serializer.toJson<String>(
        $RecordingsTable.$converterstatus.toJson(status),
      ),
      'source': serializer.toJson<String>(
        $RecordingsTable.$convertersource.toJson(source),
      ),
      'profileId': serializer.toJson<String?>(profileId),
      'tags': serializer.toJson<List<String>>(tags),
      'consentConfirmedAt': serializer.toJson<DateTime?>(consentConfirmedAt),
      'importAttestedAt': serializer.toJson<DateTime?>(importAttestedAt),
      'stopReason': serializer.toJson<String?>(
        $RecordingsTable.$converterstopReasonn.toJson(stopReason),
      ),
      'recovered': serializer.toJson<bool>(recovered),
    };
  }

  RecordingRow copyWith({
    String? id,
    String? title,
    DateTime? createdAt,
    int? durationMs,
    RecordingStatus? status,
    RecordingSource? source,
    Value<String?> profileId = const Value.absent(),
    List<String>? tags,
    Value<DateTime?> consentConfirmedAt = const Value.absent(),
    Value<DateTime?> importAttestedAt = const Value.absent(),
    Value<StopReason?> stopReason = const Value.absent(),
    bool? recovered,
  }) => RecordingRow(
    id: id ?? this.id,
    title: title ?? this.title,
    createdAt: createdAt ?? this.createdAt,
    durationMs: durationMs ?? this.durationMs,
    status: status ?? this.status,
    source: source ?? this.source,
    profileId: profileId.present ? profileId.value : this.profileId,
    tags: tags ?? this.tags,
    consentConfirmedAt: consentConfirmedAt.present
        ? consentConfirmedAt.value
        : this.consentConfirmedAt,
    importAttestedAt: importAttestedAt.present
        ? importAttestedAt.value
        : this.importAttestedAt,
    stopReason: stopReason.present ? stopReason.value : this.stopReason,
    recovered: recovered ?? this.recovered,
  );
  RecordingRow copyWithCompanion(RecordingsCompanion data) {
    return RecordingRow(
      id: data.id.present ? data.id.value : this.id,
      title: data.title.present ? data.title.value : this.title,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      durationMs: data.durationMs.present
          ? data.durationMs.value
          : this.durationMs,
      status: data.status.present ? data.status.value : this.status,
      source: data.source.present ? data.source.value : this.source,
      profileId: data.profileId.present ? data.profileId.value : this.profileId,
      tags: data.tags.present ? data.tags.value : this.tags,
      consentConfirmedAt: data.consentConfirmedAt.present
          ? data.consentConfirmedAt.value
          : this.consentConfirmedAt,
      importAttestedAt: data.importAttestedAt.present
          ? data.importAttestedAt.value
          : this.importAttestedAt,
      stopReason: data.stopReason.present
          ? data.stopReason.value
          : this.stopReason,
      recovered: data.recovered.present ? data.recovered.value : this.recovered,
    );
  }

  @override
  String toString() {
    return (StringBuffer('RecordingRow(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('createdAt: $createdAt, ')
          ..write('durationMs: $durationMs, ')
          ..write('status: $status, ')
          ..write('source: $source, ')
          ..write('profileId: $profileId, ')
          ..write('tags: $tags, ')
          ..write('consentConfirmedAt: $consentConfirmedAt, ')
          ..write('importAttestedAt: $importAttestedAt, ')
          ..write('stopReason: $stopReason, ')
          ..write('recovered: $recovered')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    title,
    createdAt,
    durationMs,
    status,
    source,
    profileId,
    tags,
    consentConfirmedAt,
    importAttestedAt,
    stopReason,
    recovered,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is RecordingRow &&
          other.id == this.id &&
          other.title == this.title &&
          other.createdAt == this.createdAt &&
          other.durationMs == this.durationMs &&
          other.status == this.status &&
          other.source == this.source &&
          other.profileId == this.profileId &&
          other.tags == this.tags &&
          other.consentConfirmedAt == this.consentConfirmedAt &&
          other.importAttestedAt == this.importAttestedAt &&
          other.stopReason == this.stopReason &&
          other.recovered == this.recovered);
}

class RecordingsCompanion extends UpdateCompanion<RecordingRow> {
  final Value<String> id;
  final Value<String> title;
  final Value<DateTime> createdAt;
  final Value<int> durationMs;
  final Value<RecordingStatus> status;
  final Value<RecordingSource> source;
  final Value<String?> profileId;
  final Value<List<String>> tags;
  final Value<DateTime?> consentConfirmedAt;
  final Value<DateTime?> importAttestedAt;
  final Value<StopReason?> stopReason;
  final Value<bool> recovered;
  final Value<int> rowid;
  const RecordingsCompanion({
    this.id = const Value.absent(),
    this.title = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.durationMs = const Value.absent(),
    this.status = const Value.absent(),
    this.source = const Value.absent(),
    this.profileId = const Value.absent(),
    this.tags = const Value.absent(),
    this.consentConfirmedAt = const Value.absent(),
    this.importAttestedAt = const Value.absent(),
    this.stopReason = const Value.absent(),
    this.recovered = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  RecordingsCompanion.insert({
    required String id,
    this.title = const Value.absent(),
    required DateTime createdAt,
    this.durationMs = const Value.absent(),
    required RecordingStatus status,
    required RecordingSource source,
    this.profileId = const Value.absent(),
    this.tags = const Value.absent(),
    this.consentConfirmedAt = const Value.absent(),
    this.importAttestedAt = const Value.absent(),
    this.stopReason = const Value.absent(),
    this.recovered = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       createdAt = Value(createdAt),
       status = Value(status),
       source = Value(source);
  static Insertable<RecordingRow> custom({
    Expression<String>? id,
    Expression<String>? title,
    Expression<int>? createdAt,
    Expression<int>? durationMs,
    Expression<String>? status,
    Expression<String>? source,
    Expression<String>? profileId,
    Expression<String>? tags,
    Expression<int>? consentConfirmedAt,
    Expression<int>? importAttestedAt,
    Expression<String>? stopReason,
    Expression<bool>? recovered,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (title != null) 'title': title,
      if (createdAt != null) 'created_at': createdAt,
      if (durationMs != null) 'duration_ms': durationMs,
      if (status != null) 'status': status,
      if (source != null) 'source': source,
      if (profileId != null) 'profile_id': profileId,
      if (tags != null) 'tags': tags,
      if (consentConfirmedAt != null)
        'consent_confirmed_at': consentConfirmedAt,
      if (importAttestedAt != null) 'import_attested_at': importAttestedAt,
      if (stopReason != null) 'stop_reason': stopReason,
      if (recovered != null) 'recovered': recovered,
      if (rowid != null) 'rowid': rowid,
    });
  }

  RecordingsCompanion copyWith({
    Value<String>? id,
    Value<String>? title,
    Value<DateTime>? createdAt,
    Value<int>? durationMs,
    Value<RecordingStatus>? status,
    Value<RecordingSource>? source,
    Value<String?>? profileId,
    Value<List<String>>? tags,
    Value<DateTime?>? consentConfirmedAt,
    Value<DateTime?>? importAttestedAt,
    Value<StopReason?>? stopReason,
    Value<bool>? recovered,
    Value<int>? rowid,
  }) {
    return RecordingsCompanion(
      id: id ?? this.id,
      title: title ?? this.title,
      createdAt: createdAt ?? this.createdAt,
      durationMs: durationMs ?? this.durationMs,
      status: status ?? this.status,
      source: source ?? this.source,
      profileId: profileId ?? this.profileId,
      tags: tags ?? this.tags,
      consentConfirmedAt: consentConfirmedAt ?? this.consentConfirmedAt,
      importAttestedAt: importAttestedAt ?? this.importAttestedAt,
      stopReason: stopReason ?? this.stopReason,
      recovered: recovered ?? this.recovered,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(
        $RecordingsTable.$convertercreatedAt.toSql(createdAt.value),
      );
    }
    if (durationMs.present) {
      map['duration_ms'] = Variable<int>(durationMs.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(
        $RecordingsTable.$converterstatus.toSql(status.value),
      );
    }
    if (source.present) {
      map['source'] = Variable<String>(
        $RecordingsTable.$convertersource.toSql(source.value),
      );
    }
    if (profileId.present) {
      map['profile_id'] = Variable<String>(profileId.value);
    }
    if (tags.present) {
      map['tags'] = Variable<String>(
        $RecordingsTable.$convertertags.toSql(tags.value),
      );
    }
    if (consentConfirmedAt.present) {
      map['consent_confirmed_at'] = Variable<int>(
        $RecordingsTable.$converterconsentConfirmedAtn.toSql(
          consentConfirmedAt.value,
        ),
      );
    }
    if (importAttestedAt.present) {
      map['import_attested_at'] = Variable<int>(
        $RecordingsTable.$converterimportAttestedAtn.toSql(
          importAttestedAt.value,
        ),
      );
    }
    if (stopReason.present) {
      map['stop_reason'] = Variable<String>(
        $RecordingsTable.$converterstopReasonn.toSql(stopReason.value),
      );
    }
    if (recovered.present) {
      map['recovered'] = Variable<bool>(recovered.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('RecordingsCompanion(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('createdAt: $createdAt, ')
          ..write('durationMs: $durationMs, ')
          ..write('status: $status, ')
          ..write('source: $source, ')
          ..write('profileId: $profileId, ')
          ..write('tags: $tags, ')
          ..write('consentConfirmedAt: $consentConfirmedAt, ')
          ..write('importAttestedAt: $importAttestedAt, ')
          ..write('stopReason: $stopReason, ')
          ..write('recovered: $recovered, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $AudioChunksTable extends AudioChunks
    with TableInfo<$AudioChunksTable, AudioChunkRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AudioChunksTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _recordingIdMeta = const VerificationMeta(
    'recordingId',
  );
  @override
  late final GeneratedColumn<String> recordingId = GeneratedColumn<String>(
    'recording_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES recordings (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _seqMeta = const VerificationMeta('seq');
  @override
  late final GeneratedColumn<int> seq = GeneratedColumn<int>(
    'seq',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _pathMeta = const VerificationMeta('path');
  @override
  late final GeneratedColumn<String> path = GeneratedColumn<String>(
    'path',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sampleRateMeta = const VerificationMeta(
    'sampleRate',
  );
  @override
  late final GeneratedColumn<int> sampleRate = GeneratedColumn<int>(
    'sample_rate',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _startMsMeta = const VerificationMeta(
    'startMs',
  );
  @override
  late final GeneratedColumn<int> startMs = GeneratedColumn<int>(
    'start_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _endMsMeta = const VerificationMeta('endMs');
  @override
  late final GeneratedColumn<int> endMs = GeneratedColumn<int>(
    'end_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _bytesMeta = const VerificationMeta('bytes');
  @override
  late final GeneratedColumn<int> bytes = GeneratedColumn<int>(
    'bytes',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sha256Meta = const VerificationMeta('sha256');
  @override
  late final GeneratedColumn<String> sha256 = GeneratedColumn<String>(
    'sha256',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    recordingId,
    seq,
    path,
    sampleRate,
    startMs,
    endMs,
    bytes,
    sha256,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'audio_chunks';
  @override
  VerificationContext validateIntegrity(
    Insertable<AudioChunkRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('recording_id')) {
      context.handle(
        _recordingIdMeta,
        recordingId.isAcceptableOrUnknown(
          data['recording_id']!,
          _recordingIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_recordingIdMeta);
    }
    if (data.containsKey('seq')) {
      context.handle(
        _seqMeta,
        seq.isAcceptableOrUnknown(data['seq']!, _seqMeta),
      );
    } else if (isInserting) {
      context.missing(_seqMeta);
    }
    if (data.containsKey('path')) {
      context.handle(
        _pathMeta,
        path.isAcceptableOrUnknown(data['path']!, _pathMeta),
      );
    } else if (isInserting) {
      context.missing(_pathMeta);
    }
    if (data.containsKey('sample_rate')) {
      context.handle(
        _sampleRateMeta,
        sampleRate.isAcceptableOrUnknown(data['sample_rate']!, _sampleRateMeta),
      );
    } else if (isInserting) {
      context.missing(_sampleRateMeta);
    }
    if (data.containsKey('start_ms')) {
      context.handle(
        _startMsMeta,
        startMs.isAcceptableOrUnknown(data['start_ms']!, _startMsMeta),
      );
    } else if (isInserting) {
      context.missing(_startMsMeta);
    }
    if (data.containsKey('end_ms')) {
      context.handle(
        _endMsMeta,
        endMs.isAcceptableOrUnknown(data['end_ms']!, _endMsMeta),
      );
    } else if (isInserting) {
      context.missing(_endMsMeta);
    }
    if (data.containsKey('bytes')) {
      context.handle(
        _bytesMeta,
        bytes.isAcceptableOrUnknown(data['bytes']!, _bytesMeta),
      );
    } else if (isInserting) {
      context.missing(_bytesMeta);
    }
    if (data.containsKey('sha256')) {
      context.handle(
        _sha256Meta,
        sha256.isAcceptableOrUnknown(data['sha256']!, _sha256Meta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {recordingId, seq},
  ];
  @override
  AudioChunkRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AudioChunkRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      recordingId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}recording_id'],
      )!,
      seq: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}seq'],
      )!,
      path: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}path'],
      )!,
      sampleRate: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sample_rate'],
      )!,
      startMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}start_ms'],
      )!,
      endMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}end_ms'],
      )!,
      bytes: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}bytes'],
      )!,
      sha256: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sha256'],
      ),
    );
  }

  @override
  $AudioChunksTable createAlias(String alias) {
    return $AudioChunksTable(attachedDatabase, alias);
  }
}

class AudioChunkRow extends DataClass implements Insertable<AudioChunkRow> {
  final int id;
  final String recordingId;
  final int seq;
  final String path;
  final int sampleRate;
  final int startMs;
  final int endMs;
  final int bytes;
  final String? sha256;
  const AudioChunkRow({
    required this.id,
    required this.recordingId,
    required this.seq,
    required this.path,
    required this.sampleRate,
    required this.startMs,
    required this.endMs,
    required this.bytes,
    this.sha256,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['recording_id'] = Variable<String>(recordingId);
    map['seq'] = Variable<int>(seq);
    map['path'] = Variable<String>(path);
    map['sample_rate'] = Variable<int>(sampleRate);
    map['start_ms'] = Variable<int>(startMs);
    map['end_ms'] = Variable<int>(endMs);
    map['bytes'] = Variable<int>(bytes);
    if (!nullToAbsent || sha256 != null) {
      map['sha256'] = Variable<String>(sha256);
    }
    return map;
  }

  AudioChunksCompanion toCompanion(bool nullToAbsent) {
    return AudioChunksCompanion(
      id: Value(id),
      recordingId: Value(recordingId),
      seq: Value(seq),
      path: Value(path),
      sampleRate: Value(sampleRate),
      startMs: Value(startMs),
      endMs: Value(endMs),
      bytes: Value(bytes),
      sha256: sha256 == null && nullToAbsent
          ? const Value.absent()
          : Value(sha256),
    );
  }

  factory AudioChunkRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AudioChunkRow(
      id: serializer.fromJson<int>(json['id']),
      recordingId: serializer.fromJson<String>(json['recordingId']),
      seq: serializer.fromJson<int>(json['seq']),
      path: serializer.fromJson<String>(json['path']),
      sampleRate: serializer.fromJson<int>(json['sampleRate']),
      startMs: serializer.fromJson<int>(json['startMs']),
      endMs: serializer.fromJson<int>(json['endMs']),
      bytes: serializer.fromJson<int>(json['bytes']),
      sha256: serializer.fromJson<String?>(json['sha256']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'recordingId': serializer.toJson<String>(recordingId),
      'seq': serializer.toJson<int>(seq),
      'path': serializer.toJson<String>(path),
      'sampleRate': serializer.toJson<int>(sampleRate),
      'startMs': serializer.toJson<int>(startMs),
      'endMs': serializer.toJson<int>(endMs),
      'bytes': serializer.toJson<int>(bytes),
      'sha256': serializer.toJson<String?>(sha256),
    };
  }

  AudioChunkRow copyWith({
    int? id,
    String? recordingId,
    int? seq,
    String? path,
    int? sampleRate,
    int? startMs,
    int? endMs,
    int? bytes,
    Value<String?> sha256 = const Value.absent(),
  }) => AudioChunkRow(
    id: id ?? this.id,
    recordingId: recordingId ?? this.recordingId,
    seq: seq ?? this.seq,
    path: path ?? this.path,
    sampleRate: sampleRate ?? this.sampleRate,
    startMs: startMs ?? this.startMs,
    endMs: endMs ?? this.endMs,
    bytes: bytes ?? this.bytes,
    sha256: sha256.present ? sha256.value : this.sha256,
  );
  AudioChunkRow copyWithCompanion(AudioChunksCompanion data) {
    return AudioChunkRow(
      id: data.id.present ? data.id.value : this.id,
      recordingId: data.recordingId.present
          ? data.recordingId.value
          : this.recordingId,
      seq: data.seq.present ? data.seq.value : this.seq,
      path: data.path.present ? data.path.value : this.path,
      sampleRate: data.sampleRate.present
          ? data.sampleRate.value
          : this.sampleRate,
      startMs: data.startMs.present ? data.startMs.value : this.startMs,
      endMs: data.endMs.present ? data.endMs.value : this.endMs,
      bytes: data.bytes.present ? data.bytes.value : this.bytes,
      sha256: data.sha256.present ? data.sha256.value : this.sha256,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AudioChunkRow(')
          ..write('id: $id, ')
          ..write('recordingId: $recordingId, ')
          ..write('seq: $seq, ')
          ..write('path: $path, ')
          ..write('sampleRate: $sampleRate, ')
          ..write('startMs: $startMs, ')
          ..write('endMs: $endMs, ')
          ..write('bytes: $bytes, ')
          ..write('sha256: $sha256')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    recordingId,
    seq,
    path,
    sampleRate,
    startMs,
    endMs,
    bytes,
    sha256,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AudioChunkRow &&
          other.id == this.id &&
          other.recordingId == this.recordingId &&
          other.seq == this.seq &&
          other.path == this.path &&
          other.sampleRate == this.sampleRate &&
          other.startMs == this.startMs &&
          other.endMs == this.endMs &&
          other.bytes == this.bytes &&
          other.sha256 == this.sha256);
}

class AudioChunksCompanion extends UpdateCompanion<AudioChunkRow> {
  final Value<int> id;
  final Value<String> recordingId;
  final Value<int> seq;
  final Value<String> path;
  final Value<int> sampleRate;
  final Value<int> startMs;
  final Value<int> endMs;
  final Value<int> bytes;
  final Value<String?> sha256;
  const AudioChunksCompanion({
    this.id = const Value.absent(),
    this.recordingId = const Value.absent(),
    this.seq = const Value.absent(),
    this.path = const Value.absent(),
    this.sampleRate = const Value.absent(),
    this.startMs = const Value.absent(),
    this.endMs = const Value.absent(),
    this.bytes = const Value.absent(),
    this.sha256 = const Value.absent(),
  });
  AudioChunksCompanion.insert({
    this.id = const Value.absent(),
    required String recordingId,
    required int seq,
    required String path,
    required int sampleRate,
    required int startMs,
    required int endMs,
    required int bytes,
    this.sha256 = const Value.absent(),
  }) : recordingId = Value(recordingId),
       seq = Value(seq),
       path = Value(path),
       sampleRate = Value(sampleRate),
       startMs = Value(startMs),
       endMs = Value(endMs),
       bytes = Value(bytes);
  static Insertable<AudioChunkRow> custom({
    Expression<int>? id,
    Expression<String>? recordingId,
    Expression<int>? seq,
    Expression<String>? path,
    Expression<int>? sampleRate,
    Expression<int>? startMs,
    Expression<int>? endMs,
    Expression<int>? bytes,
    Expression<String>? sha256,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (recordingId != null) 'recording_id': recordingId,
      if (seq != null) 'seq': seq,
      if (path != null) 'path': path,
      if (sampleRate != null) 'sample_rate': sampleRate,
      if (startMs != null) 'start_ms': startMs,
      if (endMs != null) 'end_ms': endMs,
      if (bytes != null) 'bytes': bytes,
      if (sha256 != null) 'sha256': sha256,
    });
  }

  AudioChunksCompanion copyWith({
    Value<int>? id,
    Value<String>? recordingId,
    Value<int>? seq,
    Value<String>? path,
    Value<int>? sampleRate,
    Value<int>? startMs,
    Value<int>? endMs,
    Value<int>? bytes,
    Value<String?>? sha256,
  }) {
    return AudioChunksCompanion(
      id: id ?? this.id,
      recordingId: recordingId ?? this.recordingId,
      seq: seq ?? this.seq,
      path: path ?? this.path,
      sampleRate: sampleRate ?? this.sampleRate,
      startMs: startMs ?? this.startMs,
      endMs: endMs ?? this.endMs,
      bytes: bytes ?? this.bytes,
      sha256: sha256 ?? this.sha256,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (recordingId.present) {
      map['recording_id'] = Variable<String>(recordingId.value);
    }
    if (seq.present) {
      map['seq'] = Variable<int>(seq.value);
    }
    if (path.present) {
      map['path'] = Variable<String>(path.value);
    }
    if (sampleRate.present) {
      map['sample_rate'] = Variable<int>(sampleRate.value);
    }
    if (startMs.present) {
      map['start_ms'] = Variable<int>(startMs.value);
    }
    if (endMs.present) {
      map['end_ms'] = Variable<int>(endMs.value);
    }
    if (bytes.present) {
      map['bytes'] = Variable<int>(bytes.value);
    }
    if (sha256.present) {
      map['sha256'] = Variable<String>(sha256.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AudioChunksCompanion(')
          ..write('id: $id, ')
          ..write('recordingId: $recordingId, ')
          ..write('seq: $seq, ')
          ..write('path: $path, ')
          ..write('sampleRate: $sampleRate, ')
          ..write('startMs: $startMs, ')
          ..write('endMs: $endMs, ')
          ..write('bytes: $bytes, ')
          ..write('sha256: $sha256')
          ..write(')'))
        .toString();
  }
}

class $SpeechSegmentsTable extends SpeechSegments
    with TableInfo<$SpeechSegmentsTable, SpeechSegmentRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SpeechSegmentsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _recordingIdMeta = const VerificationMeta(
    'recordingId',
  );
  @override
  late final GeneratedColumn<String> recordingId = GeneratedColumn<String>(
    'recording_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES recordings (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _startMsMeta = const VerificationMeta(
    'startMs',
  );
  @override
  late final GeneratedColumn<int> startMs = GeneratedColumn<int>(
    'start_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _endMsMeta = const VerificationMeta('endMs');
  @override
  late final GeneratedColumn<int> endMs = GeneratedColumn<int>(
    'end_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [id, recordingId, startMs, endMs];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'speech_segments';
  @override
  VerificationContext validateIntegrity(
    Insertable<SpeechSegmentRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('recording_id')) {
      context.handle(
        _recordingIdMeta,
        recordingId.isAcceptableOrUnknown(
          data['recording_id']!,
          _recordingIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_recordingIdMeta);
    }
    if (data.containsKey('start_ms')) {
      context.handle(
        _startMsMeta,
        startMs.isAcceptableOrUnknown(data['start_ms']!, _startMsMeta),
      );
    } else if (isInserting) {
      context.missing(_startMsMeta);
    }
    if (data.containsKey('end_ms')) {
      context.handle(
        _endMsMeta,
        endMs.isAcceptableOrUnknown(data['end_ms']!, _endMsMeta),
      );
    } else if (isInserting) {
      context.missing(_endMsMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  SpeechSegmentRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SpeechSegmentRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      recordingId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}recording_id'],
      )!,
      startMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}start_ms'],
      )!,
      endMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}end_ms'],
      )!,
    );
  }

  @override
  $SpeechSegmentsTable createAlias(String alias) {
    return $SpeechSegmentsTable(attachedDatabase, alias);
  }
}

class SpeechSegmentRow extends DataClass
    implements Insertable<SpeechSegmentRow> {
  final int id;
  final String recordingId;
  final int startMs;
  final int endMs;
  const SpeechSegmentRow({
    required this.id,
    required this.recordingId,
    required this.startMs,
    required this.endMs,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['recording_id'] = Variable<String>(recordingId);
    map['start_ms'] = Variable<int>(startMs);
    map['end_ms'] = Variable<int>(endMs);
    return map;
  }

  SpeechSegmentsCompanion toCompanion(bool nullToAbsent) {
    return SpeechSegmentsCompanion(
      id: Value(id),
      recordingId: Value(recordingId),
      startMs: Value(startMs),
      endMs: Value(endMs),
    );
  }

  factory SpeechSegmentRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SpeechSegmentRow(
      id: serializer.fromJson<int>(json['id']),
      recordingId: serializer.fromJson<String>(json['recordingId']),
      startMs: serializer.fromJson<int>(json['startMs']),
      endMs: serializer.fromJson<int>(json['endMs']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'recordingId': serializer.toJson<String>(recordingId),
      'startMs': serializer.toJson<int>(startMs),
      'endMs': serializer.toJson<int>(endMs),
    };
  }

  SpeechSegmentRow copyWith({
    int? id,
    String? recordingId,
    int? startMs,
    int? endMs,
  }) => SpeechSegmentRow(
    id: id ?? this.id,
    recordingId: recordingId ?? this.recordingId,
    startMs: startMs ?? this.startMs,
    endMs: endMs ?? this.endMs,
  );
  SpeechSegmentRow copyWithCompanion(SpeechSegmentsCompanion data) {
    return SpeechSegmentRow(
      id: data.id.present ? data.id.value : this.id,
      recordingId: data.recordingId.present
          ? data.recordingId.value
          : this.recordingId,
      startMs: data.startMs.present ? data.startMs.value : this.startMs,
      endMs: data.endMs.present ? data.endMs.value : this.endMs,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SpeechSegmentRow(')
          ..write('id: $id, ')
          ..write('recordingId: $recordingId, ')
          ..write('startMs: $startMs, ')
          ..write('endMs: $endMs')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, recordingId, startMs, endMs);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SpeechSegmentRow &&
          other.id == this.id &&
          other.recordingId == this.recordingId &&
          other.startMs == this.startMs &&
          other.endMs == this.endMs);
}

class SpeechSegmentsCompanion extends UpdateCompanion<SpeechSegmentRow> {
  final Value<int> id;
  final Value<String> recordingId;
  final Value<int> startMs;
  final Value<int> endMs;
  const SpeechSegmentsCompanion({
    this.id = const Value.absent(),
    this.recordingId = const Value.absent(),
    this.startMs = const Value.absent(),
    this.endMs = const Value.absent(),
  });
  SpeechSegmentsCompanion.insert({
    this.id = const Value.absent(),
    required String recordingId,
    required int startMs,
    required int endMs,
  }) : recordingId = Value(recordingId),
       startMs = Value(startMs),
       endMs = Value(endMs);
  static Insertable<SpeechSegmentRow> custom({
    Expression<int>? id,
    Expression<String>? recordingId,
    Expression<int>? startMs,
    Expression<int>? endMs,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (recordingId != null) 'recording_id': recordingId,
      if (startMs != null) 'start_ms': startMs,
      if (endMs != null) 'end_ms': endMs,
    });
  }

  SpeechSegmentsCompanion copyWith({
    Value<int>? id,
    Value<String>? recordingId,
    Value<int>? startMs,
    Value<int>? endMs,
  }) {
    return SpeechSegmentsCompanion(
      id: id ?? this.id,
      recordingId: recordingId ?? this.recordingId,
      startMs: startMs ?? this.startMs,
      endMs: endMs ?? this.endMs,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (recordingId.present) {
      map['recording_id'] = Variable<String>(recordingId.value);
    }
    if (startMs.present) {
      map['start_ms'] = Variable<int>(startMs.value);
    }
    if (endMs.present) {
      map['end_ms'] = Variable<int>(endMs.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SpeechSegmentsCompanion(')
          ..write('id: $id, ')
          ..write('recordingId: $recordingId, ')
          ..write('startMs: $startMs, ')
          ..write('endMs: $endMs')
          ..write(')'))
        .toString();
  }
}

class $MarkersTable extends Markers with TableInfo<$MarkersTable, MarkerRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $MarkersTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _recordingIdMeta = const VerificationMeta(
    'recordingId',
  );
  @override
  late final GeneratedColumn<String> recordingId = GeneratedColumn<String>(
    'recording_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES recordings (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _atMsMeta = const VerificationMeta('atMs');
  @override
  late final GeneratedColumn<int> atMs = GeneratedColumn<int>(
    'at_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  late final GeneratedColumnWithTypeConverter<MarkerKind, String> kind =
      GeneratedColumn<String>(
        'kind',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<MarkerKind>($MarkersTable.$converterkind);
  static const VerificationMeta _labelMeta = const VerificationMeta('label');
  @override
  late final GeneratedColumn<String> label = GeneratedColumn<String>(
    'label',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [id, recordingId, atMs, kind, label];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'markers';
  @override
  VerificationContext validateIntegrity(
    Insertable<MarkerRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('recording_id')) {
      context.handle(
        _recordingIdMeta,
        recordingId.isAcceptableOrUnknown(
          data['recording_id']!,
          _recordingIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_recordingIdMeta);
    }
    if (data.containsKey('at_ms')) {
      context.handle(
        _atMsMeta,
        atMs.isAcceptableOrUnknown(data['at_ms']!, _atMsMeta),
      );
    } else if (isInserting) {
      context.missing(_atMsMeta);
    }
    if (data.containsKey('label')) {
      context.handle(
        _labelMeta,
        label.isAcceptableOrUnknown(data['label']!, _labelMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  MarkerRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return MarkerRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      recordingId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}recording_id'],
      )!,
      atMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}at_ms'],
      )!,
      kind: $MarkersTable.$converterkind.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}kind'],
        )!,
      ),
      label: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}label'],
      ),
    );
  }

  @override
  $MarkersTable createAlias(String alias) {
    return $MarkersTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<MarkerKind, String, String> $converterkind =
      const EnumNameConverter<MarkerKind>(MarkerKind.values);
}

class MarkerRow extends DataClass implements Insertable<MarkerRow> {
  final int id;
  final String recordingId;
  final int atMs;
  final MarkerKind kind;
  final String? label;
  const MarkerRow({
    required this.id,
    required this.recordingId,
    required this.atMs,
    required this.kind,
    this.label,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['recording_id'] = Variable<String>(recordingId);
    map['at_ms'] = Variable<int>(atMs);
    {
      map['kind'] = Variable<String>($MarkersTable.$converterkind.toSql(kind));
    }
    if (!nullToAbsent || label != null) {
      map['label'] = Variable<String>(label);
    }
    return map;
  }

  MarkersCompanion toCompanion(bool nullToAbsent) {
    return MarkersCompanion(
      id: Value(id),
      recordingId: Value(recordingId),
      atMs: Value(atMs),
      kind: Value(kind),
      label: label == null && nullToAbsent
          ? const Value.absent()
          : Value(label),
    );
  }

  factory MarkerRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return MarkerRow(
      id: serializer.fromJson<int>(json['id']),
      recordingId: serializer.fromJson<String>(json['recordingId']),
      atMs: serializer.fromJson<int>(json['atMs']),
      kind: $MarkersTable.$converterkind.fromJson(
        serializer.fromJson<String>(json['kind']),
      ),
      label: serializer.fromJson<String?>(json['label']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'recordingId': serializer.toJson<String>(recordingId),
      'atMs': serializer.toJson<int>(atMs),
      'kind': serializer.toJson<String>(
        $MarkersTable.$converterkind.toJson(kind),
      ),
      'label': serializer.toJson<String?>(label),
    };
  }

  MarkerRow copyWith({
    int? id,
    String? recordingId,
    int? atMs,
    MarkerKind? kind,
    Value<String?> label = const Value.absent(),
  }) => MarkerRow(
    id: id ?? this.id,
    recordingId: recordingId ?? this.recordingId,
    atMs: atMs ?? this.atMs,
    kind: kind ?? this.kind,
    label: label.present ? label.value : this.label,
  );
  MarkerRow copyWithCompanion(MarkersCompanion data) {
    return MarkerRow(
      id: data.id.present ? data.id.value : this.id,
      recordingId: data.recordingId.present
          ? data.recordingId.value
          : this.recordingId,
      atMs: data.atMs.present ? data.atMs.value : this.atMs,
      kind: data.kind.present ? data.kind.value : this.kind,
      label: data.label.present ? data.label.value : this.label,
    );
  }

  @override
  String toString() {
    return (StringBuffer('MarkerRow(')
          ..write('id: $id, ')
          ..write('recordingId: $recordingId, ')
          ..write('atMs: $atMs, ')
          ..write('kind: $kind, ')
          ..write('label: $label')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, recordingId, atMs, kind, label);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MarkerRow &&
          other.id == this.id &&
          other.recordingId == this.recordingId &&
          other.atMs == this.atMs &&
          other.kind == this.kind &&
          other.label == this.label);
}

class MarkersCompanion extends UpdateCompanion<MarkerRow> {
  final Value<int> id;
  final Value<String> recordingId;
  final Value<int> atMs;
  final Value<MarkerKind> kind;
  final Value<String?> label;
  const MarkersCompanion({
    this.id = const Value.absent(),
    this.recordingId = const Value.absent(),
    this.atMs = const Value.absent(),
    this.kind = const Value.absent(),
    this.label = const Value.absent(),
  });
  MarkersCompanion.insert({
    this.id = const Value.absent(),
    required String recordingId,
    required int atMs,
    required MarkerKind kind,
    this.label = const Value.absent(),
  }) : recordingId = Value(recordingId),
       atMs = Value(atMs),
       kind = Value(kind);
  static Insertable<MarkerRow> custom({
    Expression<int>? id,
    Expression<String>? recordingId,
    Expression<int>? atMs,
    Expression<String>? kind,
    Expression<String>? label,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (recordingId != null) 'recording_id': recordingId,
      if (atMs != null) 'at_ms': atMs,
      if (kind != null) 'kind': kind,
      if (label != null) 'label': label,
    });
  }

  MarkersCompanion copyWith({
    Value<int>? id,
    Value<String>? recordingId,
    Value<int>? atMs,
    Value<MarkerKind>? kind,
    Value<String?>? label,
  }) {
    return MarkersCompanion(
      id: id ?? this.id,
      recordingId: recordingId ?? this.recordingId,
      atMs: atMs ?? this.atMs,
      kind: kind ?? this.kind,
      label: label ?? this.label,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (recordingId.present) {
      map['recording_id'] = Variable<String>(recordingId.value);
    }
    if (atMs.present) {
      map['at_ms'] = Variable<int>(atMs.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(
        $MarkersTable.$converterkind.toSql(kind.value),
      );
    }
    if (label.present) {
      map['label'] = Variable<String>(label.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('MarkersCompanion(')
          ..write('id: $id, ')
          ..write('recordingId: $recordingId, ')
          ..write('atMs: $atMs, ')
          ..write('kind: $kind, ')
          ..write('label: $label')
          ..write(')'))
        .toString();
  }
}

class $SpeakersTable extends Speakers
    with TableInfo<$SpeakersTable, SpeakerRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SpeakersTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _recordingIdMeta = const VerificationMeta(
    'recordingId',
  );
  @override
  late final GeneratedColumn<String> recordingId = GeneratedColumn<String>(
    'recording_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES recordings (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _labelMeta = const VerificationMeta('label');
  @override
  late final GeneratedColumn<String> label = GeneratedColumn<String>(
    'label',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _displayNameMeta = const VerificationMeta(
    'displayName',
  );
  @override
  late final GeneratedColumn<String> displayName = GeneratedColumn<String>(
    'display_name',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [id, recordingId, label, displayName];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'speakers';
  @override
  VerificationContext validateIntegrity(
    Insertable<SpeakerRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('recording_id')) {
      context.handle(
        _recordingIdMeta,
        recordingId.isAcceptableOrUnknown(
          data['recording_id']!,
          _recordingIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_recordingIdMeta);
    }
    if (data.containsKey('label')) {
      context.handle(
        _labelMeta,
        label.isAcceptableOrUnknown(data['label']!, _labelMeta),
      );
    } else if (isInserting) {
      context.missing(_labelMeta);
    }
    if (data.containsKey('display_name')) {
      context.handle(
        _displayNameMeta,
        displayName.isAcceptableOrUnknown(
          data['display_name']!,
          _displayNameMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {recordingId, label},
  ];
  @override
  SpeakerRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SpeakerRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      recordingId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}recording_id'],
      )!,
      label: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}label'],
      )!,
      displayName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}display_name'],
      ),
    );
  }

  @override
  $SpeakersTable createAlias(String alias) {
    return $SpeakersTable(attachedDatabase, alias);
  }
}

class SpeakerRow extends DataClass implements Insertable<SpeakerRow> {
  final int id;
  final String recordingId;
  final String label;
  final String? displayName;
  const SpeakerRow({
    required this.id,
    required this.recordingId,
    required this.label,
    this.displayName,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['recording_id'] = Variable<String>(recordingId);
    map['label'] = Variable<String>(label);
    if (!nullToAbsent || displayName != null) {
      map['display_name'] = Variable<String>(displayName);
    }
    return map;
  }

  SpeakersCompanion toCompanion(bool nullToAbsent) {
    return SpeakersCompanion(
      id: Value(id),
      recordingId: Value(recordingId),
      label: Value(label),
      displayName: displayName == null && nullToAbsent
          ? const Value.absent()
          : Value(displayName),
    );
  }

  factory SpeakerRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SpeakerRow(
      id: serializer.fromJson<int>(json['id']),
      recordingId: serializer.fromJson<String>(json['recordingId']),
      label: serializer.fromJson<String>(json['label']),
      displayName: serializer.fromJson<String?>(json['displayName']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'recordingId': serializer.toJson<String>(recordingId),
      'label': serializer.toJson<String>(label),
      'displayName': serializer.toJson<String?>(displayName),
    };
  }

  SpeakerRow copyWith({
    int? id,
    String? recordingId,
    String? label,
    Value<String?> displayName = const Value.absent(),
  }) => SpeakerRow(
    id: id ?? this.id,
    recordingId: recordingId ?? this.recordingId,
    label: label ?? this.label,
    displayName: displayName.present ? displayName.value : this.displayName,
  );
  SpeakerRow copyWithCompanion(SpeakersCompanion data) {
    return SpeakerRow(
      id: data.id.present ? data.id.value : this.id,
      recordingId: data.recordingId.present
          ? data.recordingId.value
          : this.recordingId,
      label: data.label.present ? data.label.value : this.label,
      displayName: data.displayName.present
          ? data.displayName.value
          : this.displayName,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SpeakerRow(')
          ..write('id: $id, ')
          ..write('recordingId: $recordingId, ')
          ..write('label: $label, ')
          ..write('displayName: $displayName')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, recordingId, label, displayName);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SpeakerRow &&
          other.id == this.id &&
          other.recordingId == this.recordingId &&
          other.label == this.label &&
          other.displayName == this.displayName);
}

class SpeakersCompanion extends UpdateCompanion<SpeakerRow> {
  final Value<int> id;
  final Value<String> recordingId;
  final Value<String> label;
  final Value<String?> displayName;
  const SpeakersCompanion({
    this.id = const Value.absent(),
    this.recordingId = const Value.absent(),
    this.label = const Value.absent(),
    this.displayName = const Value.absent(),
  });
  SpeakersCompanion.insert({
    this.id = const Value.absent(),
    required String recordingId,
    required String label,
    this.displayName = const Value.absent(),
  }) : recordingId = Value(recordingId),
       label = Value(label);
  static Insertable<SpeakerRow> custom({
    Expression<int>? id,
    Expression<String>? recordingId,
    Expression<String>? label,
    Expression<String>? displayName,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (recordingId != null) 'recording_id': recordingId,
      if (label != null) 'label': label,
      if (displayName != null) 'display_name': displayName,
    });
  }

  SpeakersCompanion copyWith({
    Value<int>? id,
    Value<String>? recordingId,
    Value<String>? label,
    Value<String?>? displayName,
  }) {
    return SpeakersCompanion(
      id: id ?? this.id,
      recordingId: recordingId ?? this.recordingId,
      label: label ?? this.label,
      displayName: displayName ?? this.displayName,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (recordingId.present) {
      map['recording_id'] = Variable<String>(recordingId.value);
    }
    if (label.present) {
      map['label'] = Variable<String>(label.value);
    }
    if (displayName.present) {
      map['display_name'] = Variable<String>(displayName.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SpeakersCompanion(')
          ..write('id: $id, ')
          ..write('recordingId: $recordingId, ')
          ..write('label: $label, ')
          ..write('displayName: $displayName')
          ..write(')'))
        .toString();
  }
}

class $TranscriptsTable extends Transcripts
    with TableInfo<$TranscriptsTable, TranscriptRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TranscriptsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _recordingIdMeta = const VerificationMeta(
    'recordingId',
  );
  @override
  late final GeneratedColumn<String> recordingId = GeneratedColumn<String>(
    'recording_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES recordings (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _modelIdMeta = const VerificationMeta(
    'modelId',
  );
  @override
  late final GeneratedColumn<String> modelId = GeneratedColumn<String>(
    'model_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _languageMeta = const VerificationMeta(
    'language',
  );
  @override
  late final GeneratedColumn<String> language = GeneratedColumn<String>(
    'language',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  late final GeneratedColumnWithTypeConverter<DateTime, int> createdAt =
      GeneratedColumn<int>(
        'created_at',
        aliasedName,
        false,
        type: DriftSqlType.int,
        requiredDuringInsert: true,
      ).withConverter<DateTime>($TranscriptsTable.$convertercreatedAt);
  static const VerificationMeta _editedMeta = const VerificationMeta('edited');
  @override
  late final GeneratedColumn<bool> edited = GeneratedColumn<bool>(
    'edited',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("edited" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    recordingId,
    modelId,
    language,
    createdAt,
    edited,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'transcripts';
  @override
  VerificationContext validateIntegrity(
    Insertable<TranscriptRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('recording_id')) {
      context.handle(
        _recordingIdMeta,
        recordingId.isAcceptableOrUnknown(
          data['recording_id']!,
          _recordingIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_recordingIdMeta);
    }
    if (data.containsKey('model_id')) {
      context.handle(
        _modelIdMeta,
        modelId.isAcceptableOrUnknown(data['model_id']!, _modelIdMeta),
      );
    } else if (isInserting) {
      context.missing(_modelIdMeta);
    }
    if (data.containsKey('language')) {
      context.handle(
        _languageMeta,
        language.isAcceptableOrUnknown(data['language']!, _languageMeta),
      );
    } else if (isInserting) {
      context.missing(_languageMeta);
    }
    if (data.containsKey('edited')) {
      context.handle(
        _editedMeta,
        edited.isAcceptableOrUnknown(data['edited']!, _editedMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  TranscriptRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return TranscriptRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      recordingId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}recording_id'],
      )!,
      modelId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}model_id'],
      )!,
      language: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}language'],
      )!,
      createdAt: $TranscriptsTable.$convertercreatedAt.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.int,
          data['${effectivePrefix}created_at'],
        )!,
      ),
      edited: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}edited'],
      )!,
    );
  }

  @override
  $TranscriptsTable createAlias(String alias) {
    return $TranscriptsTable(attachedDatabase, alias);
  }

  static TypeConverter<DateTime, int> $convertercreatedAt =
      const EpochMsConverter();
}

class TranscriptRow extends DataClass implements Insertable<TranscriptRow> {
  final String id;
  final String recordingId;
  final String modelId;
  final String language;
  final DateTime createdAt;
  final bool edited;
  const TranscriptRow({
    required this.id,
    required this.recordingId,
    required this.modelId,
    required this.language,
    required this.createdAt,
    required this.edited,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['recording_id'] = Variable<String>(recordingId);
    map['model_id'] = Variable<String>(modelId);
    map['language'] = Variable<String>(language);
    {
      map['created_at'] = Variable<int>(
        $TranscriptsTable.$convertercreatedAt.toSql(createdAt),
      );
    }
    map['edited'] = Variable<bool>(edited);
    return map;
  }

  TranscriptsCompanion toCompanion(bool nullToAbsent) {
    return TranscriptsCompanion(
      id: Value(id),
      recordingId: Value(recordingId),
      modelId: Value(modelId),
      language: Value(language),
      createdAt: Value(createdAt),
      edited: Value(edited),
    );
  }

  factory TranscriptRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return TranscriptRow(
      id: serializer.fromJson<String>(json['id']),
      recordingId: serializer.fromJson<String>(json['recordingId']),
      modelId: serializer.fromJson<String>(json['modelId']),
      language: serializer.fromJson<String>(json['language']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      edited: serializer.fromJson<bool>(json['edited']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'recordingId': serializer.toJson<String>(recordingId),
      'modelId': serializer.toJson<String>(modelId),
      'language': serializer.toJson<String>(language),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'edited': serializer.toJson<bool>(edited),
    };
  }

  TranscriptRow copyWith({
    String? id,
    String? recordingId,
    String? modelId,
    String? language,
    DateTime? createdAt,
    bool? edited,
  }) => TranscriptRow(
    id: id ?? this.id,
    recordingId: recordingId ?? this.recordingId,
    modelId: modelId ?? this.modelId,
    language: language ?? this.language,
    createdAt: createdAt ?? this.createdAt,
    edited: edited ?? this.edited,
  );
  TranscriptRow copyWithCompanion(TranscriptsCompanion data) {
    return TranscriptRow(
      id: data.id.present ? data.id.value : this.id,
      recordingId: data.recordingId.present
          ? data.recordingId.value
          : this.recordingId,
      modelId: data.modelId.present ? data.modelId.value : this.modelId,
      language: data.language.present ? data.language.value : this.language,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      edited: data.edited.present ? data.edited.value : this.edited,
    );
  }

  @override
  String toString() {
    return (StringBuffer('TranscriptRow(')
          ..write('id: $id, ')
          ..write('recordingId: $recordingId, ')
          ..write('modelId: $modelId, ')
          ..write('language: $language, ')
          ..write('createdAt: $createdAt, ')
          ..write('edited: $edited')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, recordingId, modelId, language, createdAt, edited);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TranscriptRow &&
          other.id == this.id &&
          other.recordingId == this.recordingId &&
          other.modelId == this.modelId &&
          other.language == this.language &&
          other.createdAt == this.createdAt &&
          other.edited == this.edited);
}

class TranscriptsCompanion extends UpdateCompanion<TranscriptRow> {
  final Value<String> id;
  final Value<String> recordingId;
  final Value<String> modelId;
  final Value<String> language;
  final Value<DateTime> createdAt;
  final Value<bool> edited;
  final Value<int> rowid;
  const TranscriptsCompanion({
    this.id = const Value.absent(),
    this.recordingId = const Value.absent(),
    this.modelId = const Value.absent(),
    this.language = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.edited = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  TranscriptsCompanion.insert({
    required String id,
    required String recordingId,
    required String modelId,
    required String language,
    required DateTime createdAt,
    this.edited = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       recordingId = Value(recordingId),
       modelId = Value(modelId),
       language = Value(language),
       createdAt = Value(createdAt);
  static Insertable<TranscriptRow> custom({
    Expression<String>? id,
    Expression<String>? recordingId,
    Expression<String>? modelId,
    Expression<String>? language,
    Expression<int>? createdAt,
    Expression<bool>? edited,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (recordingId != null) 'recording_id': recordingId,
      if (modelId != null) 'model_id': modelId,
      if (language != null) 'language': language,
      if (createdAt != null) 'created_at': createdAt,
      if (edited != null) 'edited': edited,
      if (rowid != null) 'rowid': rowid,
    });
  }

  TranscriptsCompanion copyWith({
    Value<String>? id,
    Value<String>? recordingId,
    Value<String>? modelId,
    Value<String>? language,
    Value<DateTime>? createdAt,
    Value<bool>? edited,
    Value<int>? rowid,
  }) {
    return TranscriptsCompanion(
      id: id ?? this.id,
      recordingId: recordingId ?? this.recordingId,
      modelId: modelId ?? this.modelId,
      language: language ?? this.language,
      createdAt: createdAt ?? this.createdAt,
      edited: edited ?? this.edited,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (recordingId.present) {
      map['recording_id'] = Variable<String>(recordingId.value);
    }
    if (modelId.present) {
      map['model_id'] = Variable<String>(modelId.value);
    }
    if (language.present) {
      map['language'] = Variable<String>(language.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(
        $TranscriptsTable.$convertercreatedAt.toSql(createdAt.value),
      );
    }
    if (edited.present) {
      map['edited'] = Variable<bool>(edited.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TranscriptsCompanion(')
          ..write('id: $id, ')
          ..write('recordingId: $recordingId, ')
          ..write('modelId: $modelId, ')
          ..write('language: $language, ')
          ..write('createdAt: $createdAt, ')
          ..write('edited: $edited, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $TranscriptSegmentsTable extends TranscriptSegments
    with TableInfo<$TranscriptSegmentsTable, TranscriptSegmentRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TranscriptSegmentsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _transcriptIdMeta = const VerificationMeta(
    'transcriptId',
  );
  @override
  late final GeneratedColumn<String> transcriptId = GeneratedColumn<String>(
    'transcript_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES transcripts (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _seqMeta = const VerificationMeta('seq');
  @override
  late final GeneratedColumn<int> seq = GeneratedColumn<int>(
    'seq',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _startMsMeta = const VerificationMeta(
    'startMs',
  );
  @override
  late final GeneratedColumn<int> startMs = GeneratedColumn<int>(
    'start_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _endMsMeta = const VerificationMeta('endMs');
  @override
  late final GeneratedColumn<int> endMs = GeneratedColumn<int>(
    'end_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _speakerMeta = const VerificationMeta(
    'speaker',
  );
  @override
  late final GeneratedColumn<String> speaker = GeneratedColumn<String>(
    'speaker',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _bodyMeta = const VerificationMeta('body');
  @override
  late final GeneratedColumn<String> body = GeneratedColumn<String>(
    'body',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _originalTextMeta = const VerificationMeta(
    'originalText',
  );
  @override
  late final GeneratedColumn<String> originalText = GeneratedColumn<String>(
    'original_text',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _avgLogprobMeta = const VerificationMeta(
    'avgLogprob',
  );
  @override
  late final GeneratedColumn<double> avgLogprob = GeneratedColumn<double>(
    'avg_logprob',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _tokensJsonMeta = const VerificationMeta(
    'tokensJson',
  );
  @override
  late final GeneratedColumn<String> tokensJson = GeneratedColumn<String>(
    'tokens_json',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    transcriptId,
    seq,
    startMs,
    endMs,
    speaker,
    body,
    originalText,
    avgLogprob,
    tokensJson,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'transcript_segments';
  @override
  VerificationContext validateIntegrity(
    Insertable<TranscriptSegmentRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('transcript_id')) {
      context.handle(
        _transcriptIdMeta,
        transcriptId.isAcceptableOrUnknown(
          data['transcript_id']!,
          _transcriptIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_transcriptIdMeta);
    }
    if (data.containsKey('seq')) {
      context.handle(
        _seqMeta,
        seq.isAcceptableOrUnknown(data['seq']!, _seqMeta),
      );
    } else if (isInserting) {
      context.missing(_seqMeta);
    }
    if (data.containsKey('start_ms')) {
      context.handle(
        _startMsMeta,
        startMs.isAcceptableOrUnknown(data['start_ms']!, _startMsMeta),
      );
    } else if (isInserting) {
      context.missing(_startMsMeta);
    }
    if (data.containsKey('end_ms')) {
      context.handle(
        _endMsMeta,
        endMs.isAcceptableOrUnknown(data['end_ms']!, _endMsMeta),
      );
    } else if (isInserting) {
      context.missing(_endMsMeta);
    }
    if (data.containsKey('speaker')) {
      context.handle(
        _speakerMeta,
        speaker.isAcceptableOrUnknown(data['speaker']!, _speakerMeta),
      );
    }
    if (data.containsKey('body')) {
      context.handle(
        _bodyMeta,
        body.isAcceptableOrUnknown(data['body']!, _bodyMeta),
      );
    } else if (isInserting) {
      context.missing(_bodyMeta);
    }
    if (data.containsKey('original_text')) {
      context.handle(
        _originalTextMeta,
        originalText.isAcceptableOrUnknown(
          data['original_text']!,
          _originalTextMeta,
        ),
      );
    }
    if (data.containsKey('avg_logprob')) {
      context.handle(
        _avgLogprobMeta,
        avgLogprob.isAcceptableOrUnknown(data['avg_logprob']!, _avgLogprobMeta),
      );
    }
    if (data.containsKey('tokens_json')) {
      context.handle(
        _tokensJsonMeta,
        tokensJson.isAcceptableOrUnknown(data['tokens_json']!, _tokensJsonMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {transcriptId, seq},
  ];
  @override
  TranscriptSegmentRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return TranscriptSegmentRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      transcriptId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}transcript_id'],
      )!,
      seq: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}seq'],
      )!,
      startMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}start_ms'],
      )!,
      endMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}end_ms'],
      )!,
      speaker: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}speaker'],
      ),
      body: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}body'],
      )!,
      originalText: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}original_text'],
      ),
      avgLogprob: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}avg_logprob'],
      ),
      tokensJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}tokens_json'],
      ),
    );
  }

  @override
  $TranscriptSegmentsTable createAlias(String alias) {
    return $TranscriptSegmentsTable(attachedDatabase, alias);
  }
}

class TranscriptSegmentRow extends DataClass
    implements Insertable<TranscriptSegmentRow> {
  final int id;
  final String transcriptId;
  final int seq;
  final int startMs;
  final int endMs;
  final String? speaker;
  final String body;
  final String? originalText;
  final double? avgLogprob;

  /// `[{text,p,t0_ms,t1_ms}]` for low-confidence highlighting (STT-06).
  final String? tokensJson;
  const TranscriptSegmentRow({
    required this.id,
    required this.transcriptId,
    required this.seq,
    required this.startMs,
    required this.endMs,
    this.speaker,
    required this.body,
    this.originalText,
    this.avgLogprob,
    this.tokensJson,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['transcript_id'] = Variable<String>(transcriptId);
    map['seq'] = Variable<int>(seq);
    map['start_ms'] = Variable<int>(startMs);
    map['end_ms'] = Variable<int>(endMs);
    if (!nullToAbsent || speaker != null) {
      map['speaker'] = Variable<String>(speaker);
    }
    map['body'] = Variable<String>(body);
    if (!nullToAbsent || originalText != null) {
      map['original_text'] = Variable<String>(originalText);
    }
    if (!nullToAbsent || avgLogprob != null) {
      map['avg_logprob'] = Variable<double>(avgLogprob);
    }
    if (!nullToAbsent || tokensJson != null) {
      map['tokens_json'] = Variable<String>(tokensJson);
    }
    return map;
  }

  TranscriptSegmentsCompanion toCompanion(bool nullToAbsent) {
    return TranscriptSegmentsCompanion(
      id: Value(id),
      transcriptId: Value(transcriptId),
      seq: Value(seq),
      startMs: Value(startMs),
      endMs: Value(endMs),
      speaker: speaker == null && nullToAbsent
          ? const Value.absent()
          : Value(speaker),
      body: Value(body),
      originalText: originalText == null && nullToAbsent
          ? const Value.absent()
          : Value(originalText),
      avgLogprob: avgLogprob == null && nullToAbsent
          ? const Value.absent()
          : Value(avgLogprob),
      tokensJson: tokensJson == null && nullToAbsent
          ? const Value.absent()
          : Value(tokensJson),
    );
  }

  factory TranscriptSegmentRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return TranscriptSegmentRow(
      id: serializer.fromJson<int>(json['id']),
      transcriptId: serializer.fromJson<String>(json['transcriptId']),
      seq: serializer.fromJson<int>(json['seq']),
      startMs: serializer.fromJson<int>(json['startMs']),
      endMs: serializer.fromJson<int>(json['endMs']),
      speaker: serializer.fromJson<String?>(json['speaker']),
      body: serializer.fromJson<String>(json['body']),
      originalText: serializer.fromJson<String?>(json['originalText']),
      avgLogprob: serializer.fromJson<double?>(json['avgLogprob']),
      tokensJson: serializer.fromJson<String?>(json['tokensJson']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'transcriptId': serializer.toJson<String>(transcriptId),
      'seq': serializer.toJson<int>(seq),
      'startMs': serializer.toJson<int>(startMs),
      'endMs': serializer.toJson<int>(endMs),
      'speaker': serializer.toJson<String?>(speaker),
      'body': serializer.toJson<String>(body),
      'originalText': serializer.toJson<String?>(originalText),
      'avgLogprob': serializer.toJson<double?>(avgLogprob),
      'tokensJson': serializer.toJson<String?>(tokensJson),
    };
  }

  TranscriptSegmentRow copyWith({
    int? id,
    String? transcriptId,
    int? seq,
    int? startMs,
    int? endMs,
    Value<String?> speaker = const Value.absent(),
    String? body,
    Value<String?> originalText = const Value.absent(),
    Value<double?> avgLogprob = const Value.absent(),
    Value<String?> tokensJson = const Value.absent(),
  }) => TranscriptSegmentRow(
    id: id ?? this.id,
    transcriptId: transcriptId ?? this.transcriptId,
    seq: seq ?? this.seq,
    startMs: startMs ?? this.startMs,
    endMs: endMs ?? this.endMs,
    speaker: speaker.present ? speaker.value : this.speaker,
    body: body ?? this.body,
    originalText: originalText.present ? originalText.value : this.originalText,
    avgLogprob: avgLogprob.present ? avgLogprob.value : this.avgLogprob,
    tokensJson: tokensJson.present ? tokensJson.value : this.tokensJson,
  );
  TranscriptSegmentRow copyWithCompanion(TranscriptSegmentsCompanion data) {
    return TranscriptSegmentRow(
      id: data.id.present ? data.id.value : this.id,
      transcriptId: data.transcriptId.present
          ? data.transcriptId.value
          : this.transcriptId,
      seq: data.seq.present ? data.seq.value : this.seq,
      startMs: data.startMs.present ? data.startMs.value : this.startMs,
      endMs: data.endMs.present ? data.endMs.value : this.endMs,
      speaker: data.speaker.present ? data.speaker.value : this.speaker,
      body: data.body.present ? data.body.value : this.body,
      originalText: data.originalText.present
          ? data.originalText.value
          : this.originalText,
      avgLogprob: data.avgLogprob.present
          ? data.avgLogprob.value
          : this.avgLogprob,
      tokensJson: data.tokensJson.present
          ? data.tokensJson.value
          : this.tokensJson,
    );
  }

  @override
  String toString() {
    return (StringBuffer('TranscriptSegmentRow(')
          ..write('id: $id, ')
          ..write('transcriptId: $transcriptId, ')
          ..write('seq: $seq, ')
          ..write('startMs: $startMs, ')
          ..write('endMs: $endMs, ')
          ..write('speaker: $speaker, ')
          ..write('body: $body, ')
          ..write('originalText: $originalText, ')
          ..write('avgLogprob: $avgLogprob, ')
          ..write('tokensJson: $tokensJson')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    transcriptId,
    seq,
    startMs,
    endMs,
    speaker,
    body,
    originalText,
    avgLogprob,
    tokensJson,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TranscriptSegmentRow &&
          other.id == this.id &&
          other.transcriptId == this.transcriptId &&
          other.seq == this.seq &&
          other.startMs == this.startMs &&
          other.endMs == this.endMs &&
          other.speaker == this.speaker &&
          other.body == this.body &&
          other.originalText == this.originalText &&
          other.avgLogprob == this.avgLogprob &&
          other.tokensJson == this.tokensJson);
}

class TranscriptSegmentsCompanion
    extends UpdateCompanion<TranscriptSegmentRow> {
  final Value<int> id;
  final Value<String> transcriptId;
  final Value<int> seq;
  final Value<int> startMs;
  final Value<int> endMs;
  final Value<String?> speaker;
  final Value<String> body;
  final Value<String?> originalText;
  final Value<double?> avgLogprob;
  final Value<String?> tokensJson;
  const TranscriptSegmentsCompanion({
    this.id = const Value.absent(),
    this.transcriptId = const Value.absent(),
    this.seq = const Value.absent(),
    this.startMs = const Value.absent(),
    this.endMs = const Value.absent(),
    this.speaker = const Value.absent(),
    this.body = const Value.absent(),
    this.originalText = const Value.absent(),
    this.avgLogprob = const Value.absent(),
    this.tokensJson = const Value.absent(),
  });
  TranscriptSegmentsCompanion.insert({
    this.id = const Value.absent(),
    required String transcriptId,
    required int seq,
    required int startMs,
    required int endMs,
    this.speaker = const Value.absent(),
    required String body,
    this.originalText = const Value.absent(),
    this.avgLogprob = const Value.absent(),
    this.tokensJson = const Value.absent(),
  }) : transcriptId = Value(transcriptId),
       seq = Value(seq),
       startMs = Value(startMs),
       endMs = Value(endMs),
       body = Value(body);
  static Insertable<TranscriptSegmentRow> custom({
    Expression<int>? id,
    Expression<String>? transcriptId,
    Expression<int>? seq,
    Expression<int>? startMs,
    Expression<int>? endMs,
    Expression<String>? speaker,
    Expression<String>? body,
    Expression<String>? originalText,
    Expression<double>? avgLogprob,
    Expression<String>? tokensJson,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (transcriptId != null) 'transcript_id': transcriptId,
      if (seq != null) 'seq': seq,
      if (startMs != null) 'start_ms': startMs,
      if (endMs != null) 'end_ms': endMs,
      if (speaker != null) 'speaker': speaker,
      if (body != null) 'body': body,
      if (originalText != null) 'original_text': originalText,
      if (avgLogprob != null) 'avg_logprob': avgLogprob,
      if (tokensJson != null) 'tokens_json': tokensJson,
    });
  }

  TranscriptSegmentsCompanion copyWith({
    Value<int>? id,
    Value<String>? transcriptId,
    Value<int>? seq,
    Value<int>? startMs,
    Value<int>? endMs,
    Value<String?>? speaker,
    Value<String>? body,
    Value<String?>? originalText,
    Value<double?>? avgLogprob,
    Value<String?>? tokensJson,
  }) {
    return TranscriptSegmentsCompanion(
      id: id ?? this.id,
      transcriptId: transcriptId ?? this.transcriptId,
      seq: seq ?? this.seq,
      startMs: startMs ?? this.startMs,
      endMs: endMs ?? this.endMs,
      speaker: speaker ?? this.speaker,
      body: body ?? this.body,
      originalText: originalText ?? this.originalText,
      avgLogprob: avgLogprob ?? this.avgLogprob,
      tokensJson: tokensJson ?? this.tokensJson,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (transcriptId.present) {
      map['transcript_id'] = Variable<String>(transcriptId.value);
    }
    if (seq.present) {
      map['seq'] = Variable<int>(seq.value);
    }
    if (startMs.present) {
      map['start_ms'] = Variable<int>(startMs.value);
    }
    if (endMs.present) {
      map['end_ms'] = Variable<int>(endMs.value);
    }
    if (speaker.present) {
      map['speaker'] = Variable<String>(speaker.value);
    }
    if (body.present) {
      map['body'] = Variable<String>(body.value);
    }
    if (originalText.present) {
      map['original_text'] = Variable<String>(originalText.value);
    }
    if (avgLogprob.present) {
      map['avg_logprob'] = Variable<double>(avgLogprob.value);
    }
    if (tokensJson.present) {
      map['tokens_json'] = Variable<String>(tokensJson.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TranscriptSegmentsCompanion(')
          ..write('id: $id, ')
          ..write('transcriptId: $transcriptId, ')
          ..write('seq: $seq, ')
          ..write('startMs: $startMs, ')
          ..write('endMs: $endMs, ')
          ..write('speaker: $speaker, ')
          ..write('body: $body, ')
          ..write('originalText: $originalText, ')
          ..write('avgLogprob: $avgLogprob, ')
          ..write('tokensJson: $tokensJson')
          ..write(')'))
        .toString();
  }
}

class $JobsTable extends Jobs with TableInfo<$JobsTable, JobRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $JobsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _recordingIdMeta = const VerificationMeta(
    'recordingId',
  );
  @override
  late final GeneratedColumn<String> recordingId = GeneratedColumn<String>(
    'recording_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES recordings (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _kindMeta = const VerificationMeta('kind');
  @override
  late final GeneratedColumn<String> kind = GeneratedColumn<String>(
    'kind',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _stepMeta = const VerificationMeta('step');
  @override
  late final GeneratedColumn<String> step = GeneratedColumn<String>(
    'step',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _progressMeta = const VerificationMeta(
    'progress',
  );
  @override
  late final GeneratedColumn<double> progress = GeneratedColumn<double>(
    'progress',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _attemptsMeta = const VerificationMeta(
    'attempts',
  );
  @override
  late final GeneratedColumn<int> attempts = GeneratedColumn<int>(
    'attempts',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _priorityMeta = const VerificationMeta(
    'priority',
  );
  @override
  late final GeneratedColumn<int> priority = GeneratedColumn<int>(
    'priority',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _errorCodeMeta = const VerificationMeta(
    'errorCode',
  );
  @override
  late final GeneratedColumn<String> errorCode = GeneratedColumn<String>(
    'error_code',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _errorDetailMeta = const VerificationMeta(
    'errorDetail',
  );
  @override
  late final GeneratedColumn<String> errorDetail = GeneratedColumn<String>(
    'error_detail',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _waitingReasonMeta = const VerificationMeta(
    'waitingReason',
  );
  @override
  late final GeneratedColumn<String> waitingReason = GeneratedColumn<String>(
    'waiting_reason',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  late final GeneratedColumnWithTypeConverter<DateTime?, int> notBefore =
      GeneratedColumn<int>(
        'not_before',
        aliasedName,
        true,
        type: DriftSqlType.int,
        requiredDuringInsert: false,
      ).withConverter<DateTime?>($JobsTable.$converternotBeforen);
  @override
  late final GeneratedColumnWithTypeConverter<DateTime, int> createdAt =
      GeneratedColumn<int>(
        'created_at',
        aliasedName,
        false,
        type: DriftSqlType.int,
        requiredDuringInsert: true,
      ).withConverter<DateTime>($JobsTable.$convertercreatedAt);
  @override
  late final GeneratedColumnWithTypeConverter<DateTime, int> updatedAt =
      GeneratedColumn<int>(
        'updated_at',
        aliasedName,
        false,
        type: DriftSqlType.int,
        requiredDuringInsert: true,
      ).withConverter<DateTime>($JobsTable.$converterupdatedAt);
  @override
  late final GeneratedColumnWithTypeConverter<JsonMap, String> checkpoint =
      GeneratedColumn<String>(
        'checkpoint',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
        defaultValue: const Constant('{}'),
      ).withConverter<JsonMap>($JobsTable.$convertercheckpoint);
  @override
  List<GeneratedColumn> get $columns => [
    id,
    recordingId,
    kind,
    step,
    status,
    progress,
    attempts,
    priority,
    errorCode,
    errorDetail,
    waitingReason,
    notBefore,
    createdAt,
    updatedAt,
    checkpoint,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'jobs';
  @override
  VerificationContext validateIntegrity(
    Insertable<JobRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('recording_id')) {
      context.handle(
        _recordingIdMeta,
        recordingId.isAcceptableOrUnknown(
          data['recording_id']!,
          _recordingIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_recordingIdMeta);
    }
    if (data.containsKey('kind')) {
      context.handle(
        _kindMeta,
        kind.isAcceptableOrUnknown(data['kind']!, _kindMeta),
      );
    } else if (isInserting) {
      context.missing(_kindMeta);
    }
    if (data.containsKey('step')) {
      context.handle(
        _stepMeta,
        step.isAcceptableOrUnknown(data['step']!, _stepMeta),
      );
    } else if (isInserting) {
      context.missing(_stepMeta);
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    } else if (isInserting) {
      context.missing(_statusMeta);
    }
    if (data.containsKey('progress')) {
      context.handle(
        _progressMeta,
        progress.isAcceptableOrUnknown(data['progress']!, _progressMeta),
      );
    }
    if (data.containsKey('attempts')) {
      context.handle(
        _attemptsMeta,
        attempts.isAcceptableOrUnknown(data['attempts']!, _attemptsMeta),
      );
    }
    if (data.containsKey('priority')) {
      context.handle(
        _priorityMeta,
        priority.isAcceptableOrUnknown(data['priority']!, _priorityMeta),
      );
    }
    if (data.containsKey('error_code')) {
      context.handle(
        _errorCodeMeta,
        errorCode.isAcceptableOrUnknown(data['error_code']!, _errorCodeMeta),
      );
    }
    if (data.containsKey('error_detail')) {
      context.handle(
        _errorDetailMeta,
        errorDetail.isAcceptableOrUnknown(
          data['error_detail']!,
          _errorDetailMeta,
        ),
      );
    }
    if (data.containsKey('waiting_reason')) {
      context.handle(
        _waitingReasonMeta,
        waitingReason.isAcceptableOrUnknown(
          data['waiting_reason']!,
          _waitingReasonMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  JobRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return JobRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      recordingId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}recording_id'],
      )!,
      kind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}kind'],
      )!,
      step: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}step'],
      )!,
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      progress: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}progress'],
      )!,
      attempts: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}attempts'],
      )!,
      priority: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}priority'],
      )!,
      errorCode: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}error_code'],
      ),
      errorDetail: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}error_detail'],
      ),
      waitingReason: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}waiting_reason'],
      ),
      notBefore: $JobsTable.$converternotBeforen.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.int,
          data['${effectivePrefix}not_before'],
        ),
      ),
      createdAt: $JobsTable.$convertercreatedAt.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.int,
          data['${effectivePrefix}created_at'],
        )!,
      ),
      updatedAt: $JobsTable.$converterupdatedAt.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.int,
          data['${effectivePrefix}updated_at'],
        )!,
      ),
      checkpoint: $JobsTable.$convertercheckpoint.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}checkpoint'],
        )!,
      ),
    );
  }

  @override
  $JobsTable createAlias(String alias) {
    return $JobsTable(attachedDatabase, alias);
  }

  static TypeConverter<DateTime, int> $converternotBefore =
      const EpochMsConverter();
  static TypeConverter<DateTime?, int?> $converternotBeforen =
      NullAwareTypeConverter.wrap($converternotBefore);
  static TypeConverter<DateTime, int> $convertercreatedAt =
      const EpochMsConverter();
  static TypeConverter<DateTime, int> $converterupdatedAt =
      const EpochMsConverter();
  static TypeConverter<JsonMap, String> $convertercheckpoint =
      const JsonMapConverter();
}

class JobRow extends DataClass implements Insertable<JobRow> {
  final String id;
  final String recordingId;
  final String kind;
  final String step;
  final String status;
  final double progress;
  final int attempts;

  /// Higher runs first ("Process now" jumps the queue).
  final int priority;
  final String? errorCode;

  /// Content-free detail (failure type), never transcript text or paths.
  final String? errorDetail;

  /// Reason for a `waiting` job (model_missing, profile_choice, …).
  final String? waitingReason;

  /// Earliest time an automatic retry may run (backoff).
  final DateTime? notBefore;
  final DateTime createdAt;
  final DateTime updatedAt;
  final JsonMap checkpoint;
  const JobRow({
    required this.id,
    required this.recordingId,
    required this.kind,
    required this.step,
    required this.status,
    required this.progress,
    required this.attempts,
    required this.priority,
    this.errorCode,
    this.errorDetail,
    this.waitingReason,
    this.notBefore,
    required this.createdAt,
    required this.updatedAt,
    required this.checkpoint,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['recording_id'] = Variable<String>(recordingId);
    map['kind'] = Variable<String>(kind);
    map['step'] = Variable<String>(step);
    map['status'] = Variable<String>(status);
    map['progress'] = Variable<double>(progress);
    map['attempts'] = Variable<int>(attempts);
    map['priority'] = Variable<int>(priority);
    if (!nullToAbsent || errorCode != null) {
      map['error_code'] = Variable<String>(errorCode);
    }
    if (!nullToAbsent || errorDetail != null) {
      map['error_detail'] = Variable<String>(errorDetail);
    }
    if (!nullToAbsent || waitingReason != null) {
      map['waiting_reason'] = Variable<String>(waitingReason);
    }
    if (!nullToAbsent || notBefore != null) {
      map['not_before'] = Variable<int>(
        $JobsTable.$converternotBeforen.toSql(notBefore),
      );
    }
    {
      map['created_at'] = Variable<int>(
        $JobsTable.$convertercreatedAt.toSql(createdAt),
      );
    }
    {
      map['updated_at'] = Variable<int>(
        $JobsTable.$converterupdatedAt.toSql(updatedAt),
      );
    }
    {
      map['checkpoint'] = Variable<String>(
        $JobsTable.$convertercheckpoint.toSql(checkpoint),
      );
    }
    return map;
  }

  JobsCompanion toCompanion(bool nullToAbsent) {
    return JobsCompanion(
      id: Value(id),
      recordingId: Value(recordingId),
      kind: Value(kind),
      step: Value(step),
      status: Value(status),
      progress: Value(progress),
      attempts: Value(attempts),
      priority: Value(priority),
      errorCode: errorCode == null && nullToAbsent
          ? const Value.absent()
          : Value(errorCode),
      errorDetail: errorDetail == null && nullToAbsent
          ? const Value.absent()
          : Value(errorDetail),
      waitingReason: waitingReason == null && nullToAbsent
          ? const Value.absent()
          : Value(waitingReason),
      notBefore: notBefore == null && nullToAbsent
          ? const Value.absent()
          : Value(notBefore),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      checkpoint: Value(checkpoint),
    );
  }

  factory JobRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return JobRow(
      id: serializer.fromJson<String>(json['id']),
      recordingId: serializer.fromJson<String>(json['recordingId']),
      kind: serializer.fromJson<String>(json['kind']),
      step: serializer.fromJson<String>(json['step']),
      status: serializer.fromJson<String>(json['status']),
      progress: serializer.fromJson<double>(json['progress']),
      attempts: serializer.fromJson<int>(json['attempts']),
      priority: serializer.fromJson<int>(json['priority']),
      errorCode: serializer.fromJson<String?>(json['errorCode']),
      errorDetail: serializer.fromJson<String?>(json['errorDetail']),
      waitingReason: serializer.fromJson<String?>(json['waitingReason']),
      notBefore: serializer.fromJson<DateTime?>(json['notBefore']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      checkpoint: serializer.fromJson<JsonMap>(json['checkpoint']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'recordingId': serializer.toJson<String>(recordingId),
      'kind': serializer.toJson<String>(kind),
      'step': serializer.toJson<String>(step),
      'status': serializer.toJson<String>(status),
      'progress': serializer.toJson<double>(progress),
      'attempts': serializer.toJson<int>(attempts),
      'priority': serializer.toJson<int>(priority),
      'errorCode': serializer.toJson<String?>(errorCode),
      'errorDetail': serializer.toJson<String?>(errorDetail),
      'waitingReason': serializer.toJson<String?>(waitingReason),
      'notBefore': serializer.toJson<DateTime?>(notBefore),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'checkpoint': serializer.toJson<JsonMap>(checkpoint),
    };
  }

  JobRow copyWith({
    String? id,
    String? recordingId,
    String? kind,
    String? step,
    String? status,
    double? progress,
    int? attempts,
    int? priority,
    Value<String?> errorCode = const Value.absent(),
    Value<String?> errorDetail = const Value.absent(),
    Value<String?> waitingReason = const Value.absent(),
    Value<DateTime?> notBefore = const Value.absent(),
    DateTime? createdAt,
    DateTime? updatedAt,
    JsonMap? checkpoint,
  }) => JobRow(
    id: id ?? this.id,
    recordingId: recordingId ?? this.recordingId,
    kind: kind ?? this.kind,
    step: step ?? this.step,
    status: status ?? this.status,
    progress: progress ?? this.progress,
    attempts: attempts ?? this.attempts,
    priority: priority ?? this.priority,
    errorCode: errorCode.present ? errorCode.value : this.errorCode,
    errorDetail: errorDetail.present ? errorDetail.value : this.errorDetail,
    waitingReason: waitingReason.present
        ? waitingReason.value
        : this.waitingReason,
    notBefore: notBefore.present ? notBefore.value : this.notBefore,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    checkpoint: checkpoint ?? this.checkpoint,
  );
  JobRow copyWithCompanion(JobsCompanion data) {
    return JobRow(
      id: data.id.present ? data.id.value : this.id,
      recordingId: data.recordingId.present
          ? data.recordingId.value
          : this.recordingId,
      kind: data.kind.present ? data.kind.value : this.kind,
      step: data.step.present ? data.step.value : this.step,
      status: data.status.present ? data.status.value : this.status,
      progress: data.progress.present ? data.progress.value : this.progress,
      attempts: data.attempts.present ? data.attempts.value : this.attempts,
      priority: data.priority.present ? data.priority.value : this.priority,
      errorCode: data.errorCode.present ? data.errorCode.value : this.errorCode,
      errorDetail: data.errorDetail.present
          ? data.errorDetail.value
          : this.errorDetail,
      waitingReason: data.waitingReason.present
          ? data.waitingReason.value
          : this.waitingReason,
      notBefore: data.notBefore.present ? data.notBefore.value : this.notBefore,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      checkpoint: data.checkpoint.present
          ? data.checkpoint.value
          : this.checkpoint,
    );
  }

  @override
  String toString() {
    return (StringBuffer('JobRow(')
          ..write('id: $id, ')
          ..write('recordingId: $recordingId, ')
          ..write('kind: $kind, ')
          ..write('step: $step, ')
          ..write('status: $status, ')
          ..write('progress: $progress, ')
          ..write('attempts: $attempts, ')
          ..write('priority: $priority, ')
          ..write('errorCode: $errorCode, ')
          ..write('errorDetail: $errorDetail, ')
          ..write('waitingReason: $waitingReason, ')
          ..write('notBefore: $notBefore, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('checkpoint: $checkpoint')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    recordingId,
    kind,
    step,
    status,
    progress,
    attempts,
    priority,
    errorCode,
    errorDetail,
    waitingReason,
    notBefore,
    createdAt,
    updatedAt,
    checkpoint,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is JobRow &&
          other.id == this.id &&
          other.recordingId == this.recordingId &&
          other.kind == this.kind &&
          other.step == this.step &&
          other.status == this.status &&
          other.progress == this.progress &&
          other.attempts == this.attempts &&
          other.priority == this.priority &&
          other.errorCode == this.errorCode &&
          other.errorDetail == this.errorDetail &&
          other.waitingReason == this.waitingReason &&
          other.notBefore == this.notBefore &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.checkpoint == this.checkpoint);
}

class JobsCompanion extends UpdateCompanion<JobRow> {
  final Value<String> id;
  final Value<String> recordingId;
  final Value<String> kind;
  final Value<String> step;
  final Value<String> status;
  final Value<double> progress;
  final Value<int> attempts;
  final Value<int> priority;
  final Value<String?> errorCode;
  final Value<String?> errorDetail;
  final Value<String?> waitingReason;
  final Value<DateTime?> notBefore;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<JsonMap> checkpoint;
  final Value<int> rowid;
  const JobsCompanion({
    this.id = const Value.absent(),
    this.recordingId = const Value.absent(),
    this.kind = const Value.absent(),
    this.step = const Value.absent(),
    this.status = const Value.absent(),
    this.progress = const Value.absent(),
    this.attempts = const Value.absent(),
    this.priority = const Value.absent(),
    this.errorCode = const Value.absent(),
    this.errorDetail = const Value.absent(),
    this.waitingReason = const Value.absent(),
    this.notBefore = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.checkpoint = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  JobsCompanion.insert({
    required String id,
    required String recordingId,
    required String kind,
    required String step,
    required String status,
    this.progress = const Value.absent(),
    this.attempts = const Value.absent(),
    this.priority = const Value.absent(),
    this.errorCode = const Value.absent(),
    this.errorDetail = const Value.absent(),
    this.waitingReason = const Value.absent(),
    this.notBefore = const Value.absent(),
    required DateTime createdAt,
    required DateTime updatedAt,
    this.checkpoint = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       recordingId = Value(recordingId),
       kind = Value(kind),
       step = Value(step),
       status = Value(status),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<JobRow> custom({
    Expression<String>? id,
    Expression<String>? recordingId,
    Expression<String>? kind,
    Expression<String>? step,
    Expression<String>? status,
    Expression<double>? progress,
    Expression<int>? attempts,
    Expression<int>? priority,
    Expression<String>? errorCode,
    Expression<String>? errorDetail,
    Expression<String>? waitingReason,
    Expression<int>? notBefore,
    Expression<int>? createdAt,
    Expression<int>? updatedAt,
    Expression<String>? checkpoint,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (recordingId != null) 'recording_id': recordingId,
      if (kind != null) 'kind': kind,
      if (step != null) 'step': step,
      if (status != null) 'status': status,
      if (progress != null) 'progress': progress,
      if (attempts != null) 'attempts': attempts,
      if (priority != null) 'priority': priority,
      if (errorCode != null) 'error_code': errorCode,
      if (errorDetail != null) 'error_detail': errorDetail,
      if (waitingReason != null) 'waiting_reason': waitingReason,
      if (notBefore != null) 'not_before': notBefore,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (checkpoint != null) 'checkpoint': checkpoint,
      if (rowid != null) 'rowid': rowid,
    });
  }

  JobsCompanion copyWith({
    Value<String>? id,
    Value<String>? recordingId,
    Value<String>? kind,
    Value<String>? step,
    Value<String>? status,
    Value<double>? progress,
    Value<int>? attempts,
    Value<int>? priority,
    Value<String?>? errorCode,
    Value<String?>? errorDetail,
    Value<String?>? waitingReason,
    Value<DateTime?>? notBefore,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<JsonMap>? checkpoint,
    Value<int>? rowid,
  }) {
    return JobsCompanion(
      id: id ?? this.id,
      recordingId: recordingId ?? this.recordingId,
      kind: kind ?? this.kind,
      step: step ?? this.step,
      status: status ?? this.status,
      progress: progress ?? this.progress,
      attempts: attempts ?? this.attempts,
      priority: priority ?? this.priority,
      errorCode: errorCode ?? this.errorCode,
      errorDetail: errorDetail ?? this.errorDetail,
      waitingReason: waitingReason ?? this.waitingReason,
      notBefore: notBefore ?? this.notBefore,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      checkpoint: checkpoint ?? this.checkpoint,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (recordingId.present) {
      map['recording_id'] = Variable<String>(recordingId.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(kind.value);
    }
    if (step.present) {
      map['step'] = Variable<String>(step.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (progress.present) {
      map['progress'] = Variable<double>(progress.value);
    }
    if (attempts.present) {
      map['attempts'] = Variable<int>(attempts.value);
    }
    if (priority.present) {
      map['priority'] = Variable<int>(priority.value);
    }
    if (errorCode.present) {
      map['error_code'] = Variable<String>(errorCode.value);
    }
    if (errorDetail.present) {
      map['error_detail'] = Variable<String>(errorDetail.value);
    }
    if (waitingReason.present) {
      map['waiting_reason'] = Variable<String>(waitingReason.value);
    }
    if (notBefore.present) {
      map['not_before'] = Variable<int>(
        $JobsTable.$converternotBeforen.toSql(notBefore.value),
      );
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(
        $JobsTable.$convertercreatedAt.toSql(createdAt.value),
      );
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(
        $JobsTable.$converterupdatedAt.toSql(updatedAt.value),
      );
    }
    if (checkpoint.present) {
      map['checkpoint'] = Variable<String>(
        $JobsTable.$convertercheckpoint.toSql(checkpoint.value),
      );
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('JobsCompanion(')
          ..write('id: $id, ')
          ..write('recordingId: $recordingId, ')
          ..write('kind: $kind, ')
          ..write('step: $step, ')
          ..write('status: $status, ')
          ..write('progress: $progress, ')
          ..write('attempts: $attempts, ')
          ..write('priority: $priority, ')
          ..write('errorCode: $errorCode, ')
          ..write('errorDetail: $errorDetail, ')
          ..write('waitingReason: $waitingReason, ')
          ..write('notBefore: $notBefore, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('checkpoint: $checkpoint, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ProfilesTable extends Profiles
    with TableInfo<$ProfilesTable, ProfileRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ProfilesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _versionMeta = const VerificationMeta(
    'version',
  );
  @override
  late final GeneratedColumn<int> version = GeneratedColumn<int>(
    'version',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  late final GeneratedColumnWithTypeConverter<ProfileSource, String> source =
      GeneratedColumn<String>(
        'source',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<ProfileSource>($ProfilesTable.$convertersource);
  @override
  late final GeneratedColumnWithTypeConverter<JsonMap, String> definition =
      GeneratedColumn<String>(
        'definition',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<JsonMap>($ProfilesTable.$converterdefinition);
  @override
  late final GeneratedColumnWithTypeConverter<DateTime, int> updatedAt =
      GeneratedColumn<int>(
        'updated_at',
        aliasedName,
        false,
        type: DriftSqlType.int,
        requiredDuringInsert: true,
      ).withConverter<DateTime>($ProfilesTable.$converterupdatedAt);
  @override
  List<GeneratedColumn> get $columns => [
    id,
    version,
    source,
    definition,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'profiles';
  @override
  VerificationContext validateIntegrity(
    Insertable<ProfileRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('version')) {
      context.handle(
        _versionMeta,
        version.isAcceptableOrUnknown(data['version']!, _versionMeta),
      );
    } else if (isInserting) {
      context.missing(_versionMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ProfileRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ProfileRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      version: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}version'],
      )!,
      source: $ProfilesTable.$convertersource.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}source'],
        )!,
      ),
      definition: $ProfilesTable.$converterdefinition.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}definition'],
        )!,
      ),
      updatedAt: $ProfilesTable.$converterupdatedAt.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.int,
          data['${effectivePrefix}updated_at'],
        )!,
      ),
    );
  }

  @override
  $ProfilesTable createAlias(String alias) {
    return $ProfilesTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<ProfileSource, String, String> $convertersource =
      const EnumNameConverter<ProfileSource>(ProfileSource.values);
  static TypeConverter<JsonMap, String> $converterdefinition =
      const JsonMapConverter();
  static TypeConverter<DateTime, int> $converterupdatedAt =
      const EpochMsConverter();
}

class ProfileRow extends DataClass implements Insertable<ProfileRow> {
  final String id;
  final int version;
  final ProfileSource source;
  final JsonMap definition;
  final DateTime updatedAt;
  const ProfileRow({
    required this.id,
    required this.version,
    required this.source,
    required this.definition,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['version'] = Variable<int>(version);
    {
      map['source'] = Variable<String>(
        $ProfilesTable.$convertersource.toSql(source),
      );
    }
    {
      map['definition'] = Variable<String>(
        $ProfilesTable.$converterdefinition.toSql(definition),
      );
    }
    {
      map['updated_at'] = Variable<int>(
        $ProfilesTable.$converterupdatedAt.toSql(updatedAt),
      );
    }
    return map;
  }

  ProfilesCompanion toCompanion(bool nullToAbsent) {
    return ProfilesCompanion(
      id: Value(id),
      version: Value(version),
      source: Value(source),
      definition: Value(definition),
      updatedAt: Value(updatedAt),
    );
  }

  factory ProfileRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ProfileRow(
      id: serializer.fromJson<String>(json['id']),
      version: serializer.fromJson<int>(json['version']),
      source: $ProfilesTable.$convertersource.fromJson(
        serializer.fromJson<String>(json['source']),
      ),
      definition: serializer.fromJson<JsonMap>(json['definition']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'version': serializer.toJson<int>(version),
      'source': serializer.toJson<String>(
        $ProfilesTable.$convertersource.toJson(source),
      ),
      'definition': serializer.toJson<JsonMap>(definition),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  ProfileRow copyWith({
    String? id,
    int? version,
    ProfileSource? source,
    JsonMap? definition,
    DateTime? updatedAt,
  }) => ProfileRow(
    id: id ?? this.id,
    version: version ?? this.version,
    source: source ?? this.source,
    definition: definition ?? this.definition,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  ProfileRow copyWithCompanion(ProfilesCompanion data) {
    return ProfileRow(
      id: data.id.present ? data.id.value : this.id,
      version: data.version.present ? data.version.value : this.version,
      source: data.source.present ? data.source.value : this.source,
      definition: data.definition.present
          ? data.definition.value
          : this.definition,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ProfileRow(')
          ..write('id: $id, ')
          ..write('version: $version, ')
          ..write('source: $source, ')
          ..write('definition: $definition, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, version, source, definition, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ProfileRow &&
          other.id == this.id &&
          other.version == this.version &&
          other.source == this.source &&
          other.definition == this.definition &&
          other.updatedAt == this.updatedAt);
}

class ProfilesCompanion extends UpdateCompanion<ProfileRow> {
  final Value<String> id;
  final Value<int> version;
  final Value<ProfileSource> source;
  final Value<JsonMap> definition;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const ProfilesCompanion({
    this.id = const Value.absent(),
    this.version = const Value.absent(),
    this.source = const Value.absent(),
    this.definition = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ProfilesCompanion.insert({
    required String id,
    required int version,
    required ProfileSource source,
    required JsonMap definition,
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       version = Value(version),
       source = Value(source),
       definition = Value(definition),
       updatedAt = Value(updatedAt);
  static Insertable<ProfileRow> custom({
    Expression<String>? id,
    Expression<int>? version,
    Expression<String>? source,
    Expression<String>? definition,
    Expression<int>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (version != null) 'version': version,
      if (source != null) 'source': source,
      if (definition != null) 'definition': definition,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ProfilesCompanion copyWith({
    Value<String>? id,
    Value<int>? version,
    Value<ProfileSource>? source,
    Value<JsonMap>? definition,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return ProfilesCompanion(
      id: id ?? this.id,
      version: version ?? this.version,
      source: source ?? this.source,
      definition: definition ?? this.definition,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (version.present) {
      map['version'] = Variable<int>(version.value);
    }
    if (source.present) {
      map['source'] = Variable<String>(
        $ProfilesTable.$convertersource.toSql(source.value),
      );
    }
    if (definition.present) {
      map['definition'] = Variable<String>(
        $ProfilesTable.$converterdefinition.toSql(definition.value),
      );
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(
        $ProfilesTable.$converterupdatedAt.toSql(updatedAt.value),
      );
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ProfilesCompanion(')
          ..write('id: $id, ')
          ..write('version: $version, ')
          ..write('source: $source, ')
          ..write('definition: $definition, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $TemplatesTable extends Templates
    with TableInfo<$TemplatesTable, TemplateRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TemplatesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _profileIdMeta = const VerificationMeta(
    'profileId',
  );
  @override
  late final GeneratedColumn<String> profileId = GeneratedColumn<String>(
    'profile_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES profiles (id) ON DELETE SET NULL',
    ),
  );
  static const VerificationMeta _bodyMeta = const VerificationMeta('body');
  @override
  late final GeneratedColumn<String> body = GeneratedColumn<String>(
    'body',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _filenamePatternMeta = const VerificationMeta(
    'filenamePattern',
  );
  @override
  late final GeneratedColumn<String> filenamePattern = GeneratedColumn<String>(
    'filename_pattern',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  late final GeneratedColumnWithTypeConverter<DateTime, int> updatedAt =
      GeneratedColumn<int>(
        'updated_at',
        aliasedName,
        false,
        type: DriftSqlType.int,
        requiredDuringInsert: true,
      ).withConverter<DateTime>($TemplatesTable.$converterupdatedAt);
  @override
  List<GeneratedColumn> get $columns => [
    id,
    profileId,
    body,
    filenamePattern,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'templates';
  @override
  VerificationContext validateIntegrity(
    Insertable<TemplateRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('profile_id')) {
      context.handle(
        _profileIdMeta,
        profileId.isAcceptableOrUnknown(data['profile_id']!, _profileIdMeta),
      );
    }
    if (data.containsKey('body')) {
      context.handle(
        _bodyMeta,
        body.isAcceptableOrUnknown(data['body']!, _bodyMeta),
      );
    } else if (isInserting) {
      context.missing(_bodyMeta);
    }
    if (data.containsKey('filename_pattern')) {
      context.handle(
        _filenamePatternMeta,
        filenamePattern.isAcceptableOrUnknown(
          data['filename_pattern']!,
          _filenamePatternMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_filenamePatternMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  TemplateRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return TemplateRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      profileId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}profile_id'],
      ),
      body: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}body'],
      )!,
      filenamePattern: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}filename_pattern'],
      )!,
      updatedAt: $TemplatesTable.$converterupdatedAt.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.int,
          data['${effectivePrefix}updated_at'],
        )!,
      ),
    );
  }

  @override
  $TemplatesTable createAlias(String alias) {
    return $TemplatesTable(attachedDatabase, alias);
  }

  static TypeConverter<DateTime, int> $converterupdatedAt =
      const EpochMsConverter();
}

class TemplateRow extends DataClass implements Insertable<TemplateRow> {
  final String id;
  final String? profileId;
  final String body;
  final String filenamePattern;
  final DateTime updatedAt;
  const TemplateRow({
    required this.id,
    this.profileId,
    required this.body,
    required this.filenamePattern,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    if (!nullToAbsent || profileId != null) {
      map['profile_id'] = Variable<String>(profileId);
    }
    map['body'] = Variable<String>(body);
    map['filename_pattern'] = Variable<String>(filenamePattern);
    {
      map['updated_at'] = Variable<int>(
        $TemplatesTable.$converterupdatedAt.toSql(updatedAt),
      );
    }
    return map;
  }

  TemplatesCompanion toCompanion(bool nullToAbsent) {
    return TemplatesCompanion(
      id: Value(id),
      profileId: profileId == null && nullToAbsent
          ? const Value.absent()
          : Value(profileId),
      body: Value(body),
      filenamePattern: Value(filenamePattern),
      updatedAt: Value(updatedAt),
    );
  }

  factory TemplateRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return TemplateRow(
      id: serializer.fromJson<String>(json['id']),
      profileId: serializer.fromJson<String?>(json['profileId']),
      body: serializer.fromJson<String>(json['body']),
      filenamePattern: serializer.fromJson<String>(json['filenamePattern']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'profileId': serializer.toJson<String?>(profileId),
      'body': serializer.toJson<String>(body),
      'filenamePattern': serializer.toJson<String>(filenamePattern),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  TemplateRow copyWith({
    String? id,
    Value<String?> profileId = const Value.absent(),
    String? body,
    String? filenamePattern,
    DateTime? updatedAt,
  }) => TemplateRow(
    id: id ?? this.id,
    profileId: profileId.present ? profileId.value : this.profileId,
    body: body ?? this.body,
    filenamePattern: filenamePattern ?? this.filenamePattern,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  TemplateRow copyWithCompanion(TemplatesCompanion data) {
    return TemplateRow(
      id: data.id.present ? data.id.value : this.id,
      profileId: data.profileId.present ? data.profileId.value : this.profileId,
      body: data.body.present ? data.body.value : this.body,
      filenamePattern: data.filenamePattern.present
          ? data.filenamePattern.value
          : this.filenamePattern,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('TemplateRow(')
          ..write('id: $id, ')
          ..write('profileId: $profileId, ')
          ..write('body: $body, ')
          ..write('filenamePattern: $filenamePattern, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, profileId, body, filenamePattern, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TemplateRow &&
          other.id == this.id &&
          other.profileId == this.profileId &&
          other.body == this.body &&
          other.filenamePattern == this.filenamePattern &&
          other.updatedAt == this.updatedAt);
}

class TemplatesCompanion extends UpdateCompanion<TemplateRow> {
  final Value<String> id;
  final Value<String?> profileId;
  final Value<String> body;
  final Value<String> filenamePattern;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const TemplatesCompanion({
    this.id = const Value.absent(),
    this.profileId = const Value.absent(),
    this.body = const Value.absent(),
    this.filenamePattern = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  TemplatesCompanion.insert({
    required String id,
    this.profileId = const Value.absent(),
    required String body,
    required String filenamePattern,
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       body = Value(body),
       filenamePattern = Value(filenamePattern),
       updatedAt = Value(updatedAt);
  static Insertable<TemplateRow> custom({
    Expression<String>? id,
    Expression<String>? profileId,
    Expression<String>? body,
    Expression<String>? filenamePattern,
    Expression<int>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (profileId != null) 'profile_id': profileId,
      if (body != null) 'body': body,
      if (filenamePattern != null) 'filename_pattern': filenamePattern,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  TemplatesCompanion copyWith({
    Value<String>? id,
    Value<String?>? profileId,
    Value<String>? body,
    Value<String>? filenamePattern,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return TemplatesCompanion(
      id: id ?? this.id,
      profileId: profileId ?? this.profileId,
      body: body ?? this.body,
      filenamePattern: filenamePattern ?? this.filenamePattern,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (profileId.present) {
      map['profile_id'] = Variable<String>(profileId.value);
    }
    if (body.present) {
      map['body'] = Variable<String>(body.value);
    }
    if (filenamePattern.present) {
      map['filename_pattern'] = Variable<String>(filenamePattern.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(
        $TemplatesTable.$converterupdatedAt.toSql(updatedAt.value),
      );
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TemplatesCompanion(')
          ..write('id: $id, ')
          ..write('profileId: $profileId, ')
          ..write('body: $body, ')
          ..write('filenamePattern: $filenamePattern, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ExtractionsTable extends Extractions
    with TableInfo<$ExtractionsTable, ExtractionRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ExtractionsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _recordingIdMeta = const VerificationMeta(
    'recordingId',
  );
  @override
  late final GeneratedColumn<String> recordingId = GeneratedColumn<String>(
    'recording_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES recordings (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _profileIdMeta = const VerificationMeta(
    'profileId',
  );
  @override
  late final GeneratedColumn<String> profileId = GeneratedColumn<String>(
    'profile_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _profileVersionMeta = const VerificationMeta(
    'profileVersion',
  );
  @override
  late final GeneratedColumn<int> profileVersion = GeneratedColumn<int>(
    'profile_version',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _modelIdMeta = const VerificationMeta(
    'modelId',
  );
  @override
  late final GeneratedColumn<String> modelId = GeneratedColumn<String>(
    'model_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  late final GeneratedColumnWithTypeConverter<JsonMap, String> json =
      GeneratedColumn<String>(
        'json',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<JsonMap>($ExtractionsTable.$converterjson);
  static const VerificationMeta _validMeta = const VerificationMeta('valid');
  @override
  late final GeneratedColumn<bool> valid = GeneratedColumn<bool>(
    'valid',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("valid" IN (0, 1))',
    ),
  );
  @override
  late final GeneratedColumnWithTypeConverter<DateTime, int> createdAt =
      GeneratedColumn<int>(
        'created_at',
        aliasedName,
        false,
        type: DriftSqlType.int,
        requiredDuringInsert: true,
      ).withConverter<DateTime>($ExtractionsTable.$convertercreatedAt);
  @override
  List<GeneratedColumn> get $columns => [
    id,
    recordingId,
    profileId,
    profileVersion,
    modelId,
    json,
    valid,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'extractions';
  @override
  VerificationContext validateIntegrity(
    Insertable<ExtractionRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('recording_id')) {
      context.handle(
        _recordingIdMeta,
        recordingId.isAcceptableOrUnknown(
          data['recording_id']!,
          _recordingIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_recordingIdMeta);
    }
    if (data.containsKey('profile_id')) {
      context.handle(
        _profileIdMeta,
        profileId.isAcceptableOrUnknown(data['profile_id']!, _profileIdMeta),
      );
    } else if (isInserting) {
      context.missing(_profileIdMeta);
    }
    if (data.containsKey('profile_version')) {
      context.handle(
        _profileVersionMeta,
        profileVersion.isAcceptableOrUnknown(
          data['profile_version']!,
          _profileVersionMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_profileVersionMeta);
    }
    if (data.containsKey('model_id')) {
      context.handle(
        _modelIdMeta,
        modelId.isAcceptableOrUnknown(data['model_id']!, _modelIdMeta),
      );
    } else if (isInserting) {
      context.missing(_modelIdMeta);
    }
    if (data.containsKey('valid')) {
      context.handle(
        _validMeta,
        valid.isAcceptableOrUnknown(data['valid']!, _validMeta),
      );
    } else if (isInserting) {
      context.missing(_validMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ExtractionRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ExtractionRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      recordingId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}recording_id'],
      )!,
      profileId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}profile_id'],
      )!,
      profileVersion: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}profile_version'],
      )!,
      modelId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}model_id'],
      )!,
      json: $ExtractionsTable.$converterjson.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}json'],
        )!,
      ),
      valid: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}valid'],
      )!,
      createdAt: $ExtractionsTable.$convertercreatedAt.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.int,
          data['${effectivePrefix}created_at'],
        )!,
      ),
    );
  }

  @override
  $ExtractionsTable createAlias(String alias) {
    return $ExtractionsTable(attachedDatabase, alias);
  }

  static TypeConverter<JsonMap, String> $converterjson =
      const JsonMapConverter();
  static TypeConverter<DateTime, int> $convertercreatedAt =
      const EpochMsConverter();
}

class ExtractionRow extends DataClass implements Insertable<ExtractionRow> {
  final String id;
  final String recordingId;
  final String profileId;
  final int profileVersion;
  final String modelId;
  final JsonMap json;
  final bool valid;
  final DateTime createdAt;
  const ExtractionRow({
    required this.id,
    required this.recordingId,
    required this.profileId,
    required this.profileVersion,
    required this.modelId,
    required this.json,
    required this.valid,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['recording_id'] = Variable<String>(recordingId);
    map['profile_id'] = Variable<String>(profileId);
    map['profile_version'] = Variable<int>(profileVersion);
    map['model_id'] = Variable<String>(modelId);
    {
      map['json'] = Variable<String>(
        $ExtractionsTable.$converterjson.toSql(json),
      );
    }
    map['valid'] = Variable<bool>(valid);
    {
      map['created_at'] = Variable<int>(
        $ExtractionsTable.$convertercreatedAt.toSql(createdAt),
      );
    }
    return map;
  }

  ExtractionsCompanion toCompanion(bool nullToAbsent) {
    return ExtractionsCompanion(
      id: Value(id),
      recordingId: Value(recordingId),
      profileId: Value(profileId),
      profileVersion: Value(profileVersion),
      modelId: Value(modelId),
      json: Value(json),
      valid: Value(valid),
      createdAt: Value(createdAt),
    );
  }

  factory ExtractionRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ExtractionRow(
      id: serializer.fromJson<String>(json['id']),
      recordingId: serializer.fromJson<String>(json['recordingId']),
      profileId: serializer.fromJson<String>(json['profileId']),
      profileVersion: serializer.fromJson<int>(json['profileVersion']),
      modelId: serializer.fromJson<String>(json['modelId']),
      json: serializer.fromJson<JsonMap>(json['json']),
      valid: serializer.fromJson<bool>(json['valid']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'recordingId': serializer.toJson<String>(recordingId),
      'profileId': serializer.toJson<String>(profileId),
      'profileVersion': serializer.toJson<int>(profileVersion),
      'modelId': serializer.toJson<String>(modelId),
      'json': serializer.toJson<JsonMap>(json),
      'valid': serializer.toJson<bool>(valid),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  ExtractionRow copyWith({
    String? id,
    String? recordingId,
    String? profileId,
    int? profileVersion,
    String? modelId,
    JsonMap? json,
    bool? valid,
    DateTime? createdAt,
  }) => ExtractionRow(
    id: id ?? this.id,
    recordingId: recordingId ?? this.recordingId,
    profileId: profileId ?? this.profileId,
    profileVersion: profileVersion ?? this.profileVersion,
    modelId: modelId ?? this.modelId,
    json: json ?? this.json,
    valid: valid ?? this.valid,
    createdAt: createdAt ?? this.createdAt,
  );
  ExtractionRow copyWithCompanion(ExtractionsCompanion data) {
    return ExtractionRow(
      id: data.id.present ? data.id.value : this.id,
      recordingId: data.recordingId.present
          ? data.recordingId.value
          : this.recordingId,
      profileId: data.profileId.present ? data.profileId.value : this.profileId,
      profileVersion: data.profileVersion.present
          ? data.profileVersion.value
          : this.profileVersion,
      modelId: data.modelId.present ? data.modelId.value : this.modelId,
      json: data.json.present ? data.json.value : this.json,
      valid: data.valid.present ? data.valid.value : this.valid,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ExtractionRow(')
          ..write('id: $id, ')
          ..write('recordingId: $recordingId, ')
          ..write('profileId: $profileId, ')
          ..write('profileVersion: $profileVersion, ')
          ..write('modelId: $modelId, ')
          ..write('json: $json, ')
          ..write('valid: $valid, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    recordingId,
    profileId,
    profileVersion,
    modelId,
    json,
    valid,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ExtractionRow &&
          other.id == this.id &&
          other.recordingId == this.recordingId &&
          other.profileId == this.profileId &&
          other.profileVersion == this.profileVersion &&
          other.modelId == this.modelId &&
          other.json == this.json &&
          other.valid == this.valid &&
          other.createdAt == this.createdAt);
}

class ExtractionsCompanion extends UpdateCompanion<ExtractionRow> {
  final Value<String> id;
  final Value<String> recordingId;
  final Value<String> profileId;
  final Value<int> profileVersion;
  final Value<String> modelId;
  final Value<JsonMap> json;
  final Value<bool> valid;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const ExtractionsCompanion({
    this.id = const Value.absent(),
    this.recordingId = const Value.absent(),
    this.profileId = const Value.absent(),
    this.profileVersion = const Value.absent(),
    this.modelId = const Value.absent(),
    this.json = const Value.absent(),
    this.valid = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ExtractionsCompanion.insert({
    required String id,
    required String recordingId,
    required String profileId,
    required int profileVersion,
    required String modelId,
    required JsonMap json,
    required bool valid,
    required DateTime createdAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       recordingId = Value(recordingId),
       profileId = Value(profileId),
       profileVersion = Value(profileVersion),
       modelId = Value(modelId),
       json = Value(json),
       valid = Value(valid),
       createdAt = Value(createdAt);
  static Insertable<ExtractionRow> custom({
    Expression<String>? id,
    Expression<String>? recordingId,
    Expression<String>? profileId,
    Expression<int>? profileVersion,
    Expression<String>? modelId,
    Expression<String>? json,
    Expression<bool>? valid,
    Expression<int>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (recordingId != null) 'recording_id': recordingId,
      if (profileId != null) 'profile_id': profileId,
      if (profileVersion != null) 'profile_version': profileVersion,
      if (modelId != null) 'model_id': modelId,
      if (json != null) 'json': json,
      if (valid != null) 'valid': valid,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ExtractionsCompanion copyWith({
    Value<String>? id,
    Value<String>? recordingId,
    Value<String>? profileId,
    Value<int>? profileVersion,
    Value<String>? modelId,
    Value<JsonMap>? json,
    Value<bool>? valid,
    Value<DateTime>? createdAt,
    Value<int>? rowid,
  }) {
    return ExtractionsCompanion(
      id: id ?? this.id,
      recordingId: recordingId ?? this.recordingId,
      profileId: profileId ?? this.profileId,
      profileVersion: profileVersion ?? this.profileVersion,
      modelId: modelId ?? this.modelId,
      json: json ?? this.json,
      valid: valid ?? this.valid,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (recordingId.present) {
      map['recording_id'] = Variable<String>(recordingId.value);
    }
    if (profileId.present) {
      map['profile_id'] = Variable<String>(profileId.value);
    }
    if (profileVersion.present) {
      map['profile_version'] = Variable<int>(profileVersion.value);
    }
    if (modelId.present) {
      map['model_id'] = Variable<String>(modelId.value);
    }
    if (json.present) {
      map['json'] = Variable<String>(
        $ExtractionsTable.$converterjson.toSql(json.value),
      );
    }
    if (valid.present) {
      map['valid'] = Variable<bool>(valid.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(
        $ExtractionsTable.$convertercreatedAt.toSql(createdAt.value),
      );
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ExtractionsCompanion(')
          ..write('id: $id, ')
          ..write('recordingId: $recordingId, ')
          ..write('profileId: $profileId, ')
          ..write('profileVersion: $profileVersion, ')
          ..write('modelId: $modelId, ')
          ..write('json: $json, ')
          ..write('valid: $valid, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ActionItemsTable extends ActionItems
    with TableInfo<$ActionItemsTable, ActionItemRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ActionItemsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _recordingIdMeta = const VerificationMeta(
    'recordingId',
  );
  @override
  late final GeneratedColumn<String> recordingId = GeneratedColumn<String>(
    'recording_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES recordings (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _extractionIdMeta = const VerificationMeta(
    'extractionId',
  );
  @override
  late final GeneratedColumn<String> extractionId = GeneratedColumn<String>(
    'extraction_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES extractions (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _bodyMeta = const VerificationMeta('body');
  @override
  late final GeneratedColumn<String> body = GeneratedColumn<String>(
    'body',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _ownerMeta = const VerificationMeta('owner');
  @override
  late final GeneratedColumn<String> owner = GeneratedColumn<String>(
    'owner',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _dueIsoMeta = const VerificationMeta('dueIso');
  @override
  late final GeneratedColumn<String> dueIso = GeneratedColumn<String>(
    'due_iso',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _tMsMeta = const VerificationMeta('tMs');
  @override
  late final GeneratedColumn<int> tMs = GeneratedColumn<int>(
    't_ms',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _doneMeta = const VerificationMeta('done');
  @override
  late final GeneratedColumn<bool> done = GeneratedColumn<bool>(
    'done',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("done" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  @override
  late final GeneratedColumnWithTypeConverter<DateTime?, int> doneAt =
      GeneratedColumn<int>(
        'done_at',
        aliasedName,
        true,
        type: DriftSqlType.int,
        requiredDuringInsert: false,
      ).withConverter<DateTime?>($ActionItemsTable.$converterdoneAtn);
  @override
  List<GeneratedColumn> get $columns => [
    id,
    recordingId,
    extractionId,
    body,
    owner,
    dueIso,
    tMs,
    done,
    doneAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'action_items';
  @override
  VerificationContext validateIntegrity(
    Insertable<ActionItemRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('recording_id')) {
      context.handle(
        _recordingIdMeta,
        recordingId.isAcceptableOrUnknown(
          data['recording_id']!,
          _recordingIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_recordingIdMeta);
    }
    if (data.containsKey('extraction_id')) {
      context.handle(
        _extractionIdMeta,
        extractionId.isAcceptableOrUnknown(
          data['extraction_id']!,
          _extractionIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_extractionIdMeta);
    }
    if (data.containsKey('body')) {
      context.handle(
        _bodyMeta,
        body.isAcceptableOrUnknown(data['body']!, _bodyMeta),
      );
    } else if (isInserting) {
      context.missing(_bodyMeta);
    }
    if (data.containsKey('owner')) {
      context.handle(
        _ownerMeta,
        owner.isAcceptableOrUnknown(data['owner']!, _ownerMeta),
      );
    }
    if (data.containsKey('due_iso')) {
      context.handle(
        _dueIsoMeta,
        dueIso.isAcceptableOrUnknown(data['due_iso']!, _dueIsoMeta),
      );
    }
    if (data.containsKey('t_ms')) {
      context.handle(
        _tMsMeta,
        tMs.isAcceptableOrUnknown(data['t_ms']!, _tMsMeta),
      );
    }
    if (data.containsKey('done')) {
      context.handle(
        _doneMeta,
        done.isAcceptableOrUnknown(data['done']!, _doneMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ActionItemRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ActionItemRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      recordingId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}recording_id'],
      )!,
      extractionId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}extraction_id'],
      )!,
      body: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}body'],
      )!,
      owner: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}owner'],
      ),
      dueIso: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}due_iso'],
      ),
      tMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}t_ms'],
      ),
      done: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}done'],
      )!,
      doneAt: $ActionItemsTable.$converterdoneAtn.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.int,
          data['${effectivePrefix}done_at'],
        ),
      ),
    );
  }

  @override
  $ActionItemsTable createAlias(String alias) {
    return $ActionItemsTable(attachedDatabase, alias);
  }

  static TypeConverter<DateTime, int> $converterdoneAt =
      const EpochMsConverter();
  static TypeConverter<DateTime?, int?> $converterdoneAtn =
      NullAwareTypeConverter.wrap($converterdoneAt);
}

class ActionItemRow extends DataClass implements Insertable<ActionItemRow> {
  final int id;
  final String recordingId;
  final String extractionId;
  final String body;
  final String? owner;
  final String? dueIso;
  final int? tMs;
  final bool done;
  final DateTime? doneAt;
  const ActionItemRow({
    required this.id,
    required this.recordingId,
    required this.extractionId,
    required this.body,
    this.owner,
    this.dueIso,
    this.tMs,
    required this.done,
    this.doneAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['recording_id'] = Variable<String>(recordingId);
    map['extraction_id'] = Variable<String>(extractionId);
    map['body'] = Variable<String>(body);
    if (!nullToAbsent || owner != null) {
      map['owner'] = Variable<String>(owner);
    }
    if (!nullToAbsent || dueIso != null) {
      map['due_iso'] = Variable<String>(dueIso);
    }
    if (!nullToAbsent || tMs != null) {
      map['t_ms'] = Variable<int>(tMs);
    }
    map['done'] = Variable<bool>(done);
    if (!nullToAbsent || doneAt != null) {
      map['done_at'] = Variable<int>(
        $ActionItemsTable.$converterdoneAtn.toSql(doneAt),
      );
    }
    return map;
  }

  ActionItemsCompanion toCompanion(bool nullToAbsent) {
    return ActionItemsCompanion(
      id: Value(id),
      recordingId: Value(recordingId),
      extractionId: Value(extractionId),
      body: Value(body),
      owner: owner == null && nullToAbsent
          ? const Value.absent()
          : Value(owner),
      dueIso: dueIso == null && nullToAbsent
          ? const Value.absent()
          : Value(dueIso),
      tMs: tMs == null && nullToAbsent ? const Value.absent() : Value(tMs),
      done: Value(done),
      doneAt: doneAt == null && nullToAbsent
          ? const Value.absent()
          : Value(doneAt),
    );
  }

  factory ActionItemRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ActionItemRow(
      id: serializer.fromJson<int>(json['id']),
      recordingId: serializer.fromJson<String>(json['recordingId']),
      extractionId: serializer.fromJson<String>(json['extractionId']),
      body: serializer.fromJson<String>(json['body']),
      owner: serializer.fromJson<String?>(json['owner']),
      dueIso: serializer.fromJson<String?>(json['dueIso']),
      tMs: serializer.fromJson<int?>(json['tMs']),
      done: serializer.fromJson<bool>(json['done']),
      doneAt: serializer.fromJson<DateTime?>(json['doneAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'recordingId': serializer.toJson<String>(recordingId),
      'extractionId': serializer.toJson<String>(extractionId),
      'body': serializer.toJson<String>(body),
      'owner': serializer.toJson<String?>(owner),
      'dueIso': serializer.toJson<String?>(dueIso),
      'tMs': serializer.toJson<int?>(tMs),
      'done': serializer.toJson<bool>(done),
      'doneAt': serializer.toJson<DateTime?>(doneAt),
    };
  }

  ActionItemRow copyWith({
    int? id,
    String? recordingId,
    String? extractionId,
    String? body,
    Value<String?> owner = const Value.absent(),
    Value<String?> dueIso = const Value.absent(),
    Value<int?> tMs = const Value.absent(),
    bool? done,
    Value<DateTime?> doneAt = const Value.absent(),
  }) => ActionItemRow(
    id: id ?? this.id,
    recordingId: recordingId ?? this.recordingId,
    extractionId: extractionId ?? this.extractionId,
    body: body ?? this.body,
    owner: owner.present ? owner.value : this.owner,
    dueIso: dueIso.present ? dueIso.value : this.dueIso,
    tMs: tMs.present ? tMs.value : this.tMs,
    done: done ?? this.done,
    doneAt: doneAt.present ? doneAt.value : this.doneAt,
  );
  ActionItemRow copyWithCompanion(ActionItemsCompanion data) {
    return ActionItemRow(
      id: data.id.present ? data.id.value : this.id,
      recordingId: data.recordingId.present
          ? data.recordingId.value
          : this.recordingId,
      extractionId: data.extractionId.present
          ? data.extractionId.value
          : this.extractionId,
      body: data.body.present ? data.body.value : this.body,
      owner: data.owner.present ? data.owner.value : this.owner,
      dueIso: data.dueIso.present ? data.dueIso.value : this.dueIso,
      tMs: data.tMs.present ? data.tMs.value : this.tMs,
      done: data.done.present ? data.done.value : this.done,
      doneAt: data.doneAt.present ? data.doneAt.value : this.doneAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ActionItemRow(')
          ..write('id: $id, ')
          ..write('recordingId: $recordingId, ')
          ..write('extractionId: $extractionId, ')
          ..write('body: $body, ')
          ..write('owner: $owner, ')
          ..write('dueIso: $dueIso, ')
          ..write('tMs: $tMs, ')
          ..write('done: $done, ')
          ..write('doneAt: $doneAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    recordingId,
    extractionId,
    body,
    owner,
    dueIso,
    tMs,
    done,
    doneAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ActionItemRow &&
          other.id == this.id &&
          other.recordingId == this.recordingId &&
          other.extractionId == this.extractionId &&
          other.body == this.body &&
          other.owner == this.owner &&
          other.dueIso == this.dueIso &&
          other.tMs == this.tMs &&
          other.done == this.done &&
          other.doneAt == this.doneAt);
}

class ActionItemsCompanion extends UpdateCompanion<ActionItemRow> {
  final Value<int> id;
  final Value<String> recordingId;
  final Value<String> extractionId;
  final Value<String> body;
  final Value<String?> owner;
  final Value<String?> dueIso;
  final Value<int?> tMs;
  final Value<bool> done;
  final Value<DateTime?> doneAt;
  const ActionItemsCompanion({
    this.id = const Value.absent(),
    this.recordingId = const Value.absent(),
    this.extractionId = const Value.absent(),
    this.body = const Value.absent(),
    this.owner = const Value.absent(),
    this.dueIso = const Value.absent(),
    this.tMs = const Value.absent(),
    this.done = const Value.absent(),
    this.doneAt = const Value.absent(),
  });
  ActionItemsCompanion.insert({
    this.id = const Value.absent(),
    required String recordingId,
    required String extractionId,
    required String body,
    this.owner = const Value.absent(),
    this.dueIso = const Value.absent(),
    this.tMs = const Value.absent(),
    this.done = const Value.absent(),
    this.doneAt = const Value.absent(),
  }) : recordingId = Value(recordingId),
       extractionId = Value(extractionId),
       body = Value(body);
  static Insertable<ActionItemRow> custom({
    Expression<int>? id,
    Expression<String>? recordingId,
    Expression<String>? extractionId,
    Expression<String>? body,
    Expression<String>? owner,
    Expression<String>? dueIso,
    Expression<int>? tMs,
    Expression<bool>? done,
    Expression<int>? doneAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (recordingId != null) 'recording_id': recordingId,
      if (extractionId != null) 'extraction_id': extractionId,
      if (body != null) 'body': body,
      if (owner != null) 'owner': owner,
      if (dueIso != null) 'due_iso': dueIso,
      if (tMs != null) 't_ms': tMs,
      if (done != null) 'done': done,
      if (doneAt != null) 'done_at': doneAt,
    });
  }

  ActionItemsCompanion copyWith({
    Value<int>? id,
    Value<String>? recordingId,
    Value<String>? extractionId,
    Value<String>? body,
    Value<String?>? owner,
    Value<String?>? dueIso,
    Value<int?>? tMs,
    Value<bool>? done,
    Value<DateTime?>? doneAt,
  }) {
    return ActionItemsCompanion(
      id: id ?? this.id,
      recordingId: recordingId ?? this.recordingId,
      extractionId: extractionId ?? this.extractionId,
      body: body ?? this.body,
      owner: owner ?? this.owner,
      dueIso: dueIso ?? this.dueIso,
      tMs: tMs ?? this.tMs,
      done: done ?? this.done,
      doneAt: doneAt ?? this.doneAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (recordingId.present) {
      map['recording_id'] = Variable<String>(recordingId.value);
    }
    if (extractionId.present) {
      map['extraction_id'] = Variable<String>(extractionId.value);
    }
    if (body.present) {
      map['body'] = Variable<String>(body.value);
    }
    if (owner.present) {
      map['owner'] = Variable<String>(owner.value);
    }
    if (dueIso.present) {
      map['due_iso'] = Variable<String>(dueIso.value);
    }
    if (tMs.present) {
      map['t_ms'] = Variable<int>(tMs.value);
    }
    if (done.present) {
      map['done'] = Variable<bool>(done.value);
    }
    if (doneAt.present) {
      map['done_at'] = Variable<int>(
        $ActionItemsTable.$converterdoneAtn.toSql(doneAt.value),
      );
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ActionItemsCompanion(')
          ..write('id: $id, ')
          ..write('recordingId: $recordingId, ')
          ..write('extractionId: $extractionId, ')
          ..write('body: $body, ')
          ..write('owner: $owner, ')
          ..write('dueIso: $dueIso, ')
          ..write('tMs: $tMs, ')
          ..write('done: $done, ')
          ..write('doneAt: $doneAt')
          ..write(')'))
        .toString();
  }
}

class $VaultTargetsTable extends VaultTargets
    with TableInfo<$VaultTargetsTable, VaultTargetRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $VaultTargetsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  late final GeneratedColumnWithTypeConverter<VaultPlatform, String> platform =
      GeneratedColumn<String>(
        'platform',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<VaultPlatform>($VaultTargetsTable.$converterplatform);
  static const VerificationMeta _displayNameMeta = const VerificationMeta(
    'displayName',
  );
  @override
  late final GeneratedColumn<String> displayName = GeneratedColumn<String>(
    'display_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _handleMeta = const VerificationMeta('handle');
  @override
  late final GeneratedColumn<String> handle = GeneratedColumn<String>(
    'handle',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  late final GeneratedColumnWithTypeConverter<DateTime, int> createdAt =
      GeneratedColumn<int>(
        'created_at',
        aliasedName,
        false,
        type: DriftSqlType.int,
        requiredDuringInsert: true,
      ).withConverter<DateTime>($VaultTargetsTable.$convertercreatedAt);
  @override
  List<GeneratedColumn> get $columns => [
    id,
    platform,
    displayName,
    handle,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'vault_targets';
  @override
  VerificationContext validateIntegrity(
    Insertable<VaultTargetRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('display_name')) {
      context.handle(
        _displayNameMeta,
        displayName.isAcceptableOrUnknown(
          data['display_name']!,
          _displayNameMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_displayNameMeta);
    }
    if (data.containsKey('handle')) {
      context.handle(
        _handleMeta,
        handle.isAcceptableOrUnknown(data['handle']!, _handleMeta),
      );
    } else if (isInserting) {
      context.missing(_handleMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  VaultTargetRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return VaultTargetRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      platform: $VaultTargetsTable.$converterplatform.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}platform'],
        )!,
      ),
      displayName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}display_name'],
      )!,
      handle: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}handle'],
      )!,
      createdAt: $VaultTargetsTable.$convertercreatedAt.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.int,
          data['${effectivePrefix}created_at'],
        )!,
      ),
    );
  }

  @override
  $VaultTargetsTable createAlias(String alias) {
    return $VaultTargetsTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<VaultPlatform, String, String> $converterplatform =
      const EnumNameConverter<VaultPlatform>(VaultPlatform.values);
  static TypeConverter<DateTime, int> $convertercreatedAt =
      const EpochMsConverter();
}

class VaultTargetRow extends DataClass implements Insertable<VaultTargetRow> {
  final String id;
  final VaultPlatform platform;
  final String displayName;
  final String handle;
  final DateTime createdAt;
  const VaultTargetRow({
    required this.id,
    required this.platform,
    required this.displayName,
    required this.handle,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    {
      map['platform'] = Variable<String>(
        $VaultTargetsTable.$converterplatform.toSql(platform),
      );
    }
    map['display_name'] = Variable<String>(displayName);
    map['handle'] = Variable<String>(handle);
    {
      map['created_at'] = Variable<int>(
        $VaultTargetsTable.$convertercreatedAt.toSql(createdAt),
      );
    }
    return map;
  }

  VaultTargetsCompanion toCompanion(bool nullToAbsent) {
    return VaultTargetsCompanion(
      id: Value(id),
      platform: Value(platform),
      displayName: Value(displayName),
      handle: Value(handle),
      createdAt: Value(createdAt),
    );
  }

  factory VaultTargetRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return VaultTargetRow(
      id: serializer.fromJson<String>(json['id']),
      platform: $VaultTargetsTable.$converterplatform.fromJson(
        serializer.fromJson<String>(json['platform']),
      ),
      displayName: serializer.fromJson<String>(json['displayName']),
      handle: serializer.fromJson<String>(json['handle']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'platform': serializer.toJson<String>(
        $VaultTargetsTable.$converterplatform.toJson(platform),
      ),
      'displayName': serializer.toJson<String>(displayName),
      'handle': serializer.toJson<String>(handle),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  VaultTargetRow copyWith({
    String? id,
    VaultPlatform? platform,
    String? displayName,
    String? handle,
    DateTime? createdAt,
  }) => VaultTargetRow(
    id: id ?? this.id,
    platform: platform ?? this.platform,
    displayName: displayName ?? this.displayName,
    handle: handle ?? this.handle,
    createdAt: createdAt ?? this.createdAt,
  );
  VaultTargetRow copyWithCompanion(VaultTargetsCompanion data) {
    return VaultTargetRow(
      id: data.id.present ? data.id.value : this.id,
      platform: data.platform.present ? data.platform.value : this.platform,
      displayName: data.displayName.present
          ? data.displayName.value
          : this.displayName,
      handle: data.handle.present ? data.handle.value : this.handle,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('VaultTargetRow(')
          ..write('id: $id, ')
          ..write('platform: $platform, ')
          ..write('displayName: $displayName, ')
          ..write('handle: $handle, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, platform, displayName, handle, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is VaultTargetRow &&
          other.id == this.id &&
          other.platform == this.platform &&
          other.displayName == this.displayName &&
          other.handle == this.handle &&
          other.createdAt == this.createdAt);
}

class VaultTargetsCompanion extends UpdateCompanion<VaultTargetRow> {
  final Value<String> id;
  final Value<VaultPlatform> platform;
  final Value<String> displayName;
  final Value<String> handle;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const VaultTargetsCompanion({
    this.id = const Value.absent(),
    this.platform = const Value.absent(),
    this.displayName = const Value.absent(),
    this.handle = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  VaultTargetsCompanion.insert({
    required String id,
    required VaultPlatform platform,
    required String displayName,
    required String handle,
    required DateTime createdAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       platform = Value(platform),
       displayName = Value(displayName),
       handle = Value(handle),
       createdAt = Value(createdAt);
  static Insertable<VaultTargetRow> custom({
    Expression<String>? id,
    Expression<String>? platform,
    Expression<String>? displayName,
    Expression<String>? handle,
    Expression<int>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (platform != null) 'platform': platform,
      if (displayName != null) 'display_name': displayName,
      if (handle != null) 'handle': handle,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  VaultTargetsCompanion copyWith({
    Value<String>? id,
    Value<VaultPlatform>? platform,
    Value<String>? displayName,
    Value<String>? handle,
    Value<DateTime>? createdAt,
    Value<int>? rowid,
  }) {
    return VaultTargetsCompanion(
      id: id ?? this.id,
      platform: platform ?? this.platform,
      displayName: displayName ?? this.displayName,
      handle: handle ?? this.handle,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (platform.present) {
      map['platform'] = Variable<String>(
        $VaultTargetsTable.$converterplatform.toSql(platform.value),
      );
    }
    if (displayName.present) {
      map['display_name'] = Variable<String>(displayName.value);
    }
    if (handle.present) {
      map['handle'] = Variable<String>(handle.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(
        $VaultTargetsTable.$convertercreatedAt.toSql(createdAt.value),
      );
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('VaultTargetsCompanion(')
          ..write('id: $id, ')
          ..write('platform: $platform, ')
          ..write('displayName: $displayName, ')
          ..write('handle: $handle, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $RoutingRulesTable extends RoutingRules
    with TableInfo<$RoutingRulesTable, RoutingRuleRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $RoutingRulesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _priorityMeta = const VerificationMeta(
    'priority',
  );
  @override
  late final GeneratedColumn<int> priority = GeneratedColumn<int>(
    'priority',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  late final GeneratedColumnWithTypeConverter<JsonMap, String> match =
      GeneratedColumn<String>(
        'match',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<JsonMap>($RoutingRulesTable.$convertermatch);
  static const VerificationMeta _targetIdMeta = const VerificationMeta(
    'targetId',
  );
  @override
  late final GeneratedColumn<String> targetId = GeneratedColumn<String>(
    'target_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES vault_targets (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _subPathMeta = const VerificationMeta(
    'subPath',
  );
  @override
  late final GeneratedColumn<String> subPath = GeneratedColumn<String>(
    'sub_path',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _filenamePatternMeta = const VerificationMeta(
    'filenamePattern',
  );
  @override
  late final GeneratedColumn<String> filenamePattern = GeneratedColumn<String>(
    'filename_pattern',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    priority,
    match,
    targetId,
    subPath,
    filenamePattern,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'routing_rules';
  @override
  VerificationContext validateIntegrity(
    Insertable<RoutingRuleRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('priority')) {
      context.handle(
        _priorityMeta,
        priority.isAcceptableOrUnknown(data['priority']!, _priorityMeta),
      );
    } else if (isInserting) {
      context.missing(_priorityMeta);
    }
    if (data.containsKey('target_id')) {
      context.handle(
        _targetIdMeta,
        targetId.isAcceptableOrUnknown(data['target_id']!, _targetIdMeta),
      );
    } else if (isInserting) {
      context.missing(_targetIdMeta);
    }
    if (data.containsKey('sub_path')) {
      context.handle(
        _subPathMeta,
        subPath.isAcceptableOrUnknown(data['sub_path']!, _subPathMeta),
      );
    }
    if (data.containsKey('filename_pattern')) {
      context.handle(
        _filenamePatternMeta,
        filenamePattern.isAcceptableOrUnknown(
          data['filename_pattern']!,
          _filenamePatternMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  RoutingRuleRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return RoutingRuleRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      priority: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}priority'],
      )!,
      match: $RoutingRulesTable.$convertermatch.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}match'],
        )!,
      ),
      targetId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}target_id'],
      )!,
      subPath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sub_path'],
      )!,
      filenamePattern: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}filename_pattern'],
      ),
    );
  }

  @override
  $RoutingRulesTable createAlias(String alias) {
    return $RoutingRulesTable(attachedDatabase, alias);
  }

  static TypeConverter<JsonMap, String> $convertermatch =
      const JsonMapConverter();
}

class RoutingRuleRow extends DataClass implements Insertable<RoutingRuleRow> {
  final String id;
  final int priority;
  final JsonMap match;
  final String targetId;
  final String subPath;
  final String? filenamePattern;
  const RoutingRuleRow({
    required this.id,
    required this.priority,
    required this.match,
    required this.targetId,
    required this.subPath,
    this.filenamePattern,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['priority'] = Variable<int>(priority);
    {
      map['match'] = Variable<String>(
        $RoutingRulesTable.$convertermatch.toSql(match),
      );
    }
    map['target_id'] = Variable<String>(targetId);
    map['sub_path'] = Variable<String>(subPath);
    if (!nullToAbsent || filenamePattern != null) {
      map['filename_pattern'] = Variable<String>(filenamePattern);
    }
    return map;
  }

  RoutingRulesCompanion toCompanion(bool nullToAbsent) {
    return RoutingRulesCompanion(
      id: Value(id),
      priority: Value(priority),
      match: Value(match),
      targetId: Value(targetId),
      subPath: Value(subPath),
      filenamePattern: filenamePattern == null && nullToAbsent
          ? const Value.absent()
          : Value(filenamePattern),
    );
  }

  factory RoutingRuleRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return RoutingRuleRow(
      id: serializer.fromJson<String>(json['id']),
      priority: serializer.fromJson<int>(json['priority']),
      match: serializer.fromJson<JsonMap>(json['match']),
      targetId: serializer.fromJson<String>(json['targetId']),
      subPath: serializer.fromJson<String>(json['subPath']),
      filenamePattern: serializer.fromJson<String?>(json['filenamePattern']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'priority': serializer.toJson<int>(priority),
      'match': serializer.toJson<JsonMap>(match),
      'targetId': serializer.toJson<String>(targetId),
      'subPath': serializer.toJson<String>(subPath),
      'filenamePattern': serializer.toJson<String?>(filenamePattern),
    };
  }

  RoutingRuleRow copyWith({
    String? id,
    int? priority,
    JsonMap? match,
    String? targetId,
    String? subPath,
    Value<String?> filenamePattern = const Value.absent(),
  }) => RoutingRuleRow(
    id: id ?? this.id,
    priority: priority ?? this.priority,
    match: match ?? this.match,
    targetId: targetId ?? this.targetId,
    subPath: subPath ?? this.subPath,
    filenamePattern: filenamePattern.present
        ? filenamePattern.value
        : this.filenamePattern,
  );
  RoutingRuleRow copyWithCompanion(RoutingRulesCompanion data) {
    return RoutingRuleRow(
      id: data.id.present ? data.id.value : this.id,
      priority: data.priority.present ? data.priority.value : this.priority,
      match: data.match.present ? data.match.value : this.match,
      targetId: data.targetId.present ? data.targetId.value : this.targetId,
      subPath: data.subPath.present ? data.subPath.value : this.subPath,
      filenamePattern: data.filenamePattern.present
          ? data.filenamePattern.value
          : this.filenamePattern,
    );
  }

  @override
  String toString() {
    return (StringBuffer('RoutingRuleRow(')
          ..write('id: $id, ')
          ..write('priority: $priority, ')
          ..write('match: $match, ')
          ..write('targetId: $targetId, ')
          ..write('subPath: $subPath, ')
          ..write('filenamePattern: $filenamePattern')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, priority, match, targetId, subPath, filenamePattern);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is RoutingRuleRow &&
          other.id == this.id &&
          other.priority == this.priority &&
          other.match == this.match &&
          other.targetId == this.targetId &&
          other.subPath == this.subPath &&
          other.filenamePattern == this.filenamePattern);
}

class RoutingRulesCompanion extends UpdateCompanion<RoutingRuleRow> {
  final Value<String> id;
  final Value<int> priority;
  final Value<JsonMap> match;
  final Value<String> targetId;
  final Value<String> subPath;
  final Value<String?> filenamePattern;
  final Value<int> rowid;
  const RoutingRulesCompanion({
    this.id = const Value.absent(),
    this.priority = const Value.absent(),
    this.match = const Value.absent(),
    this.targetId = const Value.absent(),
    this.subPath = const Value.absent(),
    this.filenamePattern = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  RoutingRulesCompanion.insert({
    required String id,
    required int priority,
    required JsonMap match,
    required String targetId,
    this.subPath = const Value.absent(),
    this.filenamePattern = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       priority = Value(priority),
       match = Value(match),
       targetId = Value(targetId);
  static Insertable<RoutingRuleRow> custom({
    Expression<String>? id,
    Expression<int>? priority,
    Expression<String>? match,
    Expression<String>? targetId,
    Expression<String>? subPath,
    Expression<String>? filenamePattern,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (priority != null) 'priority': priority,
      if (match != null) 'match': match,
      if (targetId != null) 'target_id': targetId,
      if (subPath != null) 'sub_path': subPath,
      if (filenamePattern != null) 'filename_pattern': filenamePattern,
      if (rowid != null) 'rowid': rowid,
    });
  }

  RoutingRulesCompanion copyWith({
    Value<String>? id,
    Value<int>? priority,
    Value<JsonMap>? match,
    Value<String>? targetId,
    Value<String>? subPath,
    Value<String?>? filenamePattern,
    Value<int>? rowid,
  }) {
    return RoutingRulesCompanion(
      id: id ?? this.id,
      priority: priority ?? this.priority,
      match: match ?? this.match,
      targetId: targetId ?? this.targetId,
      subPath: subPath ?? this.subPath,
      filenamePattern: filenamePattern ?? this.filenamePattern,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (priority.present) {
      map['priority'] = Variable<int>(priority.value);
    }
    if (match.present) {
      map['match'] = Variable<String>(
        $RoutingRulesTable.$convertermatch.toSql(match.value),
      );
    }
    if (targetId.present) {
      map['target_id'] = Variable<String>(targetId.value);
    }
    if (subPath.present) {
      map['sub_path'] = Variable<String>(subPath.value);
    }
    if (filenamePattern.present) {
      map['filename_pattern'] = Variable<String>(filenamePattern.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('RoutingRulesCompanion(')
          ..write('id: $id, ')
          ..write('priority: $priority, ')
          ..write('match: $match, ')
          ..write('targetId: $targetId, ')
          ..write('subPath: $subPath, ')
          ..write('filenamePattern: $filenamePattern, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ExportsTable extends Exports with TableInfo<$ExportsTable, ExportRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ExportsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _recordingIdMeta = const VerificationMeta(
    'recordingId',
  );
  @override
  late final GeneratedColumn<String> recordingId = GeneratedColumn<String>(
    'recording_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES recordings (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _targetIdMeta = const VerificationMeta(
    'targetId',
  );
  @override
  late final GeneratedColumn<String> targetId = GeneratedColumn<String>(
    'target_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES vault_targets (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _relPathMeta = const VerificationMeta(
    'relPath',
  );
  @override
  late final GeneratedColumn<String> relPath = GeneratedColumn<String>(
    'rel_path',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _contentHashMeta = const VerificationMeta(
    'contentHash',
  );
  @override
  late final GeneratedColumn<String> contentHash = GeneratedColumn<String>(
    'content_hash',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  late final GeneratedColumnWithTypeConverter<ExportStatus, String> status =
      GeneratedColumn<String>(
        'status',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<ExportStatus>($ExportsTable.$converterstatus);
  static const VerificationMeta _attemptsMeta = const VerificationMeta(
    'attempts',
  );
  @override
  late final GeneratedColumn<int> attempts = GeneratedColumn<int>(
    'attempts',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  @override
  late final GeneratedColumnWithTypeConverter<DateTime, int> updatedAt =
      GeneratedColumn<int>(
        'updated_at',
        aliasedName,
        false,
        type: DriftSqlType.int,
        requiredDuringInsert: true,
      ).withConverter<DateTime>($ExportsTable.$converterupdatedAt);
  @override
  List<GeneratedColumn> get $columns => [
    id,
    recordingId,
    targetId,
    relPath,
    contentHash,
    status,
    attempts,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'exports';
  @override
  VerificationContext validateIntegrity(
    Insertable<ExportRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('recording_id')) {
      context.handle(
        _recordingIdMeta,
        recordingId.isAcceptableOrUnknown(
          data['recording_id']!,
          _recordingIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_recordingIdMeta);
    }
    if (data.containsKey('target_id')) {
      context.handle(
        _targetIdMeta,
        targetId.isAcceptableOrUnknown(data['target_id']!, _targetIdMeta),
      );
    } else if (isInserting) {
      context.missing(_targetIdMeta);
    }
    if (data.containsKey('rel_path')) {
      context.handle(
        _relPathMeta,
        relPath.isAcceptableOrUnknown(data['rel_path']!, _relPathMeta),
      );
    } else if (isInserting) {
      context.missing(_relPathMeta);
    }
    if (data.containsKey('content_hash')) {
      context.handle(
        _contentHashMeta,
        contentHash.isAcceptableOrUnknown(
          data['content_hash']!,
          _contentHashMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_contentHashMeta);
    }
    if (data.containsKey('attempts')) {
      context.handle(
        _attemptsMeta,
        attempts.isAcceptableOrUnknown(data['attempts']!, _attemptsMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {recordingId, targetId},
  ];
  @override
  ExportRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ExportRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      recordingId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}recording_id'],
      )!,
      targetId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}target_id'],
      )!,
      relPath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}rel_path'],
      )!,
      contentHash: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}content_hash'],
      )!,
      status: $ExportsTable.$converterstatus.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}status'],
        )!,
      ),
      attempts: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}attempts'],
      )!,
      updatedAt: $ExportsTable.$converterupdatedAt.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.int,
          data['${effectivePrefix}updated_at'],
        )!,
      ),
    );
  }

  @override
  $ExportsTable createAlias(String alias) {
    return $ExportsTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<ExportStatus, String, String> $converterstatus =
      const EnumNameConverter<ExportStatus>(ExportStatus.values);
  static TypeConverter<DateTime, int> $converterupdatedAt =
      const EpochMsConverter();
}

class ExportRow extends DataClass implements Insertable<ExportRow> {
  final String id;
  final String recordingId;
  final String targetId;
  final String relPath;
  final String contentHash;
  final ExportStatus status;
  final int attempts;
  final DateTime updatedAt;
  const ExportRow({
    required this.id,
    required this.recordingId,
    required this.targetId,
    required this.relPath,
    required this.contentHash,
    required this.status,
    required this.attempts,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['recording_id'] = Variable<String>(recordingId);
    map['target_id'] = Variable<String>(targetId);
    map['rel_path'] = Variable<String>(relPath);
    map['content_hash'] = Variable<String>(contentHash);
    {
      map['status'] = Variable<String>(
        $ExportsTable.$converterstatus.toSql(status),
      );
    }
    map['attempts'] = Variable<int>(attempts);
    {
      map['updated_at'] = Variable<int>(
        $ExportsTable.$converterupdatedAt.toSql(updatedAt),
      );
    }
    return map;
  }

  ExportsCompanion toCompanion(bool nullToAbsent) {
    return ExportsCompanion(
      id: Value(id),
      recordingId: Value(recordingId),
      targetId: Value(targetId),
      relPath: Value(relPath),
      contentHash: Value(contentHash),
      status: Value(status),
      attempts: Value(attempts),
      updatedAt: Value(updatedAt),
    );
  }

  factory ExportRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ExportRow(
      id: serializer.fromJson<String>(json['id']),
      recordingId: serializer.fromJson<String>(json['recordingId']),
      targetId: serializer.fromJson<String>(json['targetId']),
      relPath: serializer.fromJson<String>(json['relPath']),
      contentHash: serializer.fromJson<String>(json['contentHash']),
      status: $ExportsTable.$converterstatus.fromJson(
        serializer.fromJson<String>(json['status']),
      ),
      attempts: serializer.fromJson<int>(json['attempts']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'recordingId': serializer.toJson<String>(recordingId),
      'targetId': serializer.toJson<String>(targetId),
      'relPath': serializer.toJson<String>(relPath),
      'contentHash': serializer.toJson<String>(contentHash),
      'status': serializer.toJson<String>(
        $ExportsTable.$converterstatus.toJson(status),
      ),
      'attempts': serializer.toJson<int>(attempts),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  ExportRow copyWith({
    String? id,
    String? recordingId,
    String? targetId,
    String? relPath,
    String? contentHash,
    ExportStatus? status,
    int? attempts,
    DateTime? updatedAt,
  }) => ExportRow(
    id: id ?? this.id,
    recordingId: recordingId ?? this.recordingId,
    targetId: targetId ?? this.targetId,
    relPath: relPath ?? this.relPath,
    contentHash: contentHash ?? this.contentHash,
    status: status ?? this.status,
    attempts: attempts ?? this.attempts,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  ExportRow copyWithCompanion(ExportsCompanion data) {
    return ExportRow(
      id: data.id.present ? data.id.value : this.id,
      recordingId: data.recordingId.present
          ? data.recordingId.value
          : this.recordingId,
      targetId: data.targetId.present ? data.targetId.value : this.targetId,
      relPath: data.relPath.present ? data.relPath.value : this.relPath,
      contentHash: data.contentHash.present
          ? data.contentHash.value
          : this.contentHash,
      status: data.status.present ? data.status.value : this.status,
      attempts: data.attempts.present ? data.attempts.value : this.attempts,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ExportRow(')
          ..write('id: $id, ')
          ..write('recordingId: $recordingId, ')
          ..write('targetId: $targetId, ')
          ..write('relPath: $relPath, ')
          ..write('contentHash: $contentHash, ')
          ..write('status: $status, ')
          ..write('attempts: $attempts, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    recordingId,
    targetId,
    relPath,
    contentHash,
    status,
    attempts,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ExportRow &&
          other.id == this.id &&
          other.recordingId == this.recordingId &&
          other.targetId == this.targetId &&
          other.relPath == this.relPath &&
          other.contentHash == this.contentHash &&
          other.status == this.status &&
          other.attempts == this.attempts &&
          other.updatedAt == this.updatedAt);
}

class ExportsCompanion extends UpdateCompanion<ExportRow> {
  final Value<String> id;
  final Value<String> recordingId;
  final Value<String> targetId;
  final Value<String> relPath;
  final Value<String> contentHash;
  final Value<ExportStatus> status;
  final Value<int> attempts;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const ExportsCompanion({
    this.id = const Value.absent(),
    this.recordingId = const Value.absent(),
    this.targetId = const Value.absent(),
    this.relPath = const Value.absent(),
    this.contentHash = const Value.absent(),
    this.status = const Value.absent(),
    this.attempts = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ExportsCompanion.insert({
    required String id,
    required String recordingId,
    required String targetId,
    required String relPath,
    required String contentHash,
    required ExportStatus status,
    this.attempts = const Value.absent(),
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       recordingId = Value(recordingId),
       targetId = Value(targetId),
       relPath = Value(relPath),
       contentHash = Value(contentHash),
       status = Value(status),
       updatedAt = Value(updatedAt);
  static Insertable<ExportRow> custom({
    Expression<String>? id,
    Expression<String>? recordingId,
    Expression<String>? targetId,
    Expression<String>? relPath,
    Expression<String>? contentHash,
    Expression<String>? status,
    Expression<int>? attempts,
    Expression<int>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (recordingId != null) 'recording_id': recordingId,
      if (targetId != null) 'target_id': targetId,
      if (relPath != null) 'rel_path': relPath,
      if (contentHash != null) 'content_hash': contentHash,
      if (status != null) 'status': status,
      if (attempts != null) 'attempts': attempts,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ExportsCompanion copyWith({
    Value<String>? id,
    Value<String>? recordingId,
    Value<String>? targetId,
    Value<String>? relPath,
    Value<String>? contentHash,
    Value<ExportStatus>? status,
    Value<int>? attempts,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return ExportsCompanion(
      id: id ?? this.id,
      recordingId: recordingId ?? this.recordingId,
      targetId: targetId ?? this.targetId,
      relPath: relPath ?? this.relPath,
      contentHash: contentHash ?? this.contentHash,
      status: status ?? this.status,
      attempts: attempts ?? this.attempts,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (recordingId.present) {
      map['recording_id'] = Variable<String>(recordingId.value);
    }
    if (targetId.present) {
      map['target_id'] = Variable<String>(targetId.value);
    }
    if (relPath.present) {
      map['rel_path'] = Variable<String>(relPath.value);
    }
    if (contentHash.present) {
      map['content_hash'] = Variable<String>(contentHash.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(
        $ExportsTable.$converterstatus.toSql(status.value),
      );
    }
    if (attempts.present) {
      map['attempts'] = Variable<int>(attempts.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(
        $ExportsTable.$converterupdatedAt.toSql(updatedAt.value),
      );
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ExportsCompanion(')
          ..write('id: $id, ')
          ..write('recordingId: $recordingId, ')
          ..write('targetId: $targetId, ')
          ..write('relPath: $relPath, ')
          ..write('contentHash: $contentHash, ')
          ..write('status: $status, ')
          ..write('attempts: $attempts, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ModelsInstalledTable extends ModelsInstalled
    with TableInfo<$ModelsInstalledTable, InstalledModelRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ModelsInstalledTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  late final GeneratedColumnWithTypeConverter<ModelType, String> type =
      GeneratedColumn<String>(
        'type',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<ModelType>($ModelsInstalledTable.$convertertype);
  static const VerificationMeta _versionMeta = const VerificationMeta(
    'version',
  );
  @override
  late final GeneratedColumn<String> version = GeneratedColumn<String>(
    'version',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _pathMeta = const VerificationMeta('path');
  @override
  late final GeneratedColumn<String> path = GeneratedColumn<String>(
    'path',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sha256Meta = const VerificationMeta('sha256');
  @override
  late final GeneratedColumn<String> sha256 = GeneratedColumn<String>(
    'sha256',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sizeMeta = const VerificationMeta('size');
  @override
  late final GeneratedColumn<int> size = GeneratedColumn<int>(
    'size',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  late final GeneratedColumnWithTypeConverter<DateTime, int> installedAt =
      GeneratedColumn<int>(
        'installed_at',
        aliasedName,
        false,
        type: DriftSqlType.int,
        requiredDuringInsert: true,
      ).withConverter<DateTime>($ModelsInstalledTable.$converterinstalledAt);
  @override
  List<GeneratedColumn> get $columns => [
    id,
    type,
    version,
    path,
    sha256,
    size,
    installedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'models_installed';
  @override
  VerificationContext validateIntegrity(
    Insertable<InstalledModelRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('version')) {
      context.handle(
        _versionMeta,
        version.isAcceptableOrUnknown(data['version']!, _versionMeta),
      );
    } else if (isInserting) {
      context.missing(_versionMeta);
    }
    if (data.containsKey('path')) {
      context.handle(
        _pathMeta,
        path.isAcceptableOrUnknown(data['path']!, _pathMeta),
      );
    } else if (isInserting) {
      context.missing(_pathMeta);
    }
    if (data.containsKey('sha256')) {
      context.handle(
        _sha256Meta,
        sha256.isAcceptableOrUnknown(data['sha256']!, _sha256Meta),
      );
    } else if (isInserting) {
      context.missing(_sha256Meta);
    }
    if (data.containsKey('size')) {
      context.handle(
        _sizeMeta,
        size.isAcceptableOrUnknown(data['size']!, _sizeMeta),
      );
    } else if (isInserting) {
      context.missing(_sizeMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  InstalledModelRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return InstalledModelRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      type: $ModelsInstalledTable.$convertertype.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}type'],
        )!,
      ),
      version: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}version'],
      )!,
      path: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}path'],
      )!,
      sha256: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sha256'],
      )!,
      size: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}size'],
      )!,
      installedAt: $ModelsInstalledTable.$converterinstalledAt.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.int,
          data['${effectivePrefix}installed_at'],
        )!,
      ),
    );
  }

  @override
  $ModelsInstalledTable createAlias(String alias) {
    return $ModelsInstalledTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<ModelType, String, String> $convertertype =
      const EnumNameConverter<ModelType>(ModelType.values);
  static TypeConverter<DateTime, int> $converterinstalledAt =
      const EpochMsConverter();
}

class InstalledModelRow extends DataClass
    implements Insertable<InstalledModelRow> {
  final String id;
  final ModelType type;
  final String version;
  final String path;
  final String sha256;
  final int size;
  final DateTime installedAt;
  const InstalledModelRow({
    required this.id,
    required this.type,
    required this.version,
    required this.path,
    required this.sha256,
    required this.size,
    required this.installedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    {
      map['type'] = Variable<String>(
        $ModelsInstalledTable.$convertertype.toSql(type),
      );
    }
    map['version'] = Variable<String>(version);
    map['path'] = Variable<String>(path);
    map['sha256'] = Variable<String>(sha256);
    map['size'] = Variable<int>(size);
    {
      map['installed_at'] = Variable<int>(
        $ModelsInstalledTable.$converterinstalledAt.toSql(installedAt),
      );
    }
    return map;
  }

  ModelsInstalledCompanion toCompanion(bool nullToAbsent) {
    return ModelsInstalledCompanion(
      id: Value(id),
      type: Value(type),
      version: Value(version),
      path: Value(path),
      sha256: Value(sha256),
      size: Value(size),
      installedAt: Value(installedAt),
    );
  }

  factory InstalledModelRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return InstalledModelRow(
      id: serializer.fromJson<String>(json['id']),
      type: $ModelsInstalledTable.$convertertype.fromJson(
        serializer.fromJson<String>(json['type']),
      ),
      version: serializer.fromJson<String>(json['version']),
      path: serializer.fromJson<String>(json['path']),
      sha256: serializer.fromJson<String>(json['sha256']),
      size: serializer.fromJson<int>(json['size']),
      installedAt: serializer.fromJson<DateTime>(json['installedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'type': serializer.toJson<String>(
        $ModelsInstalledTable.$convertertype.toJson(type),
      ),
      'version': serializer.toJson<String>(version),
      'path': serializer.toJson<String>(path),
      'sha256': serializer.toJson<String>(sha256),
      'size': serializer.toJson<int>(size),
      'installedAt': serializer.toJson<DateTime>(installedAt),
    };
  }

  InstalledModelRow copyWith({
    String? id,
    ModelType? type,
    String? version,
    String? path,
    String? sha256,
    int? size,
    DateTime? installedAt,
  }) => InstalledModelRow(
    id: id ?? this.id,
    type: type ?? this.type,
    version: version ?? this.version,
    path: path ?? this.path,
    sha256: sha256 ?? this.sha256,
    size: size ?? this.size,
    installedAt: installedAt ?? this.installedAt,
  );
  InstalledModelRow copyWithCompanion(ModelsInstalledCompanion data) {
    return InstalledModelRow(
      id: data.id.present ? data.id.value : this.id,
      type: data.type.present ? data.type.value : this.type,
      version: data.version.present ? data.version.value : this.version,
      path: data.path.present ? data.path.value : this.path,
      sha256: data.sha256.present ? data.sha256.value : this.sha256,
      size: data.size.present ? data.size.value : this.size,
      installedAt: data.installedAt.present
          ? data.installedAt.value
          : this.installedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('InstalledModelRow(')
          ..write('id: $id, ')
          ..write('type: $type, ')
          ..write('version: $version, ')
          ..write('path: $path, ')
          ..write('sha256: $sha256, ')
          ..write('size: $size, ')
          ..write('installedAt: $installedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, type, version, path, sha256, size, installedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is InstalledModelRow &&
          other.id == this.id &&
          other.type == this.type &&
          other.version == this.version &&
          other.path == this.path &&
          other.sha256 == this.sha256 &&
          other.size == this.size &&
          other.installedAt == this.installedAt);
}

class ModelsInstalledCompanion extends UpdateCompanion<InstalledModelRow> {
  final Value<String> id;
  final Value<ModelType> type;
  final Value<String> version;
  final Value<String> path;
  final Value<String> sha256;
  final Value<int> size;
  final Value<DateTime> installedAt;
  final Value<int> rowid;
  const ModelsInstalledCompanion({
    this.id = const Value.absent(),
    this.type = const Value.absent(),
    this.version = const Value.absent(),
    this.path = const Value.absent(),
    this.sha256 = const Value.absent(),
    this.size = const Value.absent(),
    this.installedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ModelsInstalledCompanion.insert({
    required String id,
    required ModelType type,
    required String version,
    required String path,
    required String sha256,
    required int size,
    required DateTime installedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       type = Value(type),
       version = Value(version),
       path = Value(path),
       sha256 = Value(sha256),
       size = Value(size),
       installedAt = Value(installedAt);
  static Insertable<InstalledModelRow> custom({
    Expression<String>? id,
    Expression<String>? type,
    Expression<String>? version,
    Expression<String>? path,
    Expression<String>? sha256,
    Expression<int>? size,
    Expression<int>? installedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (type != null) 'type': type,
      if (version != null) 'version': version,
      if (path != null) 'path': path,
      if (sha256 != null) 'sha256': sha256,
      if (size != null) 'size': size,
      if (installedAt != null) 'installed_at': installedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ModelsInstalledCompanion copyWith({
    Value<String>? id,
    Value<ModelType>? type,
    Value<String>? version,
    Value<String>? path,
    Value<String>? sha256,
    Value<int>? size,
    Value<DateTime>? installedAt,
    Value<int>? rowid,
  }) {
    return ModelsInstalledCompanion(
      id: id ?? this.id,
      type: type ?? this.type,
      version: version ?? this.version,
      path: path ?? this.path,
      sha256: sha256 ?? this.sha256,
      size: size ?? this.size,
      installedAt: installedAt ?? this.installedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (type.present) {
      map['type'] = Variable<String>(
        $ModelsInstalledTable.$convertertype.toSql(type.value),
      );
    }
    if (version.present) {
      map['version'] = Variable<String>(version.value);
    }
    if (path.present) {
      map['path'] = Variable<String>(path.value);
    }
    if (sha256.present) {
      map['sha256'] = Variable<String>(sha256.value);
    }
    if (size.present) {
      map['size'] = Variable<int>(size.value);
    }
    if (installedAt.present) {
      map['installed_at'] = Variable<int>(
        $ModelsInstalledTable.$converterinstalledAt.toSql(installedAt.value),
      );
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ModelsInstalledCompanion(')
          ..write('id: $id, ')
          ..write('type: $type, ')
          ..write('version: $version, ')
          ..write('path: $path, ')
          ..write('sha256: $sha256, ')
          ..write('size: $size, ')
          ..write('installedAt: $installedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SettingsTable extends Settings
    with TableInfo<$SettingsTable, SettingRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SettingsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
    'key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _valueMeta = const VerificationMeta('value');
  @override
  late final GeneratedColumn<String> value = GeneratedColumn<String>(
    'value',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [key, value];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'settings';
  @override
  VerificationContext validateIntegrity(
    Insertable<SettingRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('key')) {
      context.handle(
        _keyMeta,
        key.isAcceptableOrUnknown(data['key']!, _keyMeta),
      );
    } else if (isInserting) {
      context.missing(_keyMeta);
    }
    if (data.containsKey('value')) {
      context.handle(
        _valueMeta,
        value.isAcceptableOrUnknown(data['value']!, _valueMeta),
      );
    } else if (isInserting) {
      context.missing(_valueMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {key};
  @override
  SettingRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SettingRow(
      key: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}key'],
      )!,
      value: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}value'],
      )!,
    );
  }

  @override
  $SettingsTable createAlias(String alias) {
    return $SettingsTable(attachedDatabase, alias);
  }
}

class SettingRow extends DataClass implements Insertable<SettingRow> {
  final String key;
  final String value;
  const SettingRow({required this.key, required this.value});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    map['value'] = Variable<String>(value);
    return map;
  }

  SettingsCompanion toCompanion(bool nullToAbsent) {
    return SettingsCompanion(key: Value(key), value: Value(value));
  }

  factory SettingRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SettingRow(
      key: serializer.fromJson<String>(json['key']),
      value: serializer.fromJson<String>(json['value']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'key': serializer.toJson<String>(key),
      'value': serializer.toJson<String>(value),
    };
  }

  SettingRow copyWith({String? key, String? value}) =>
      SettingRow(key: key ?? this.key, value: value ?? this.value);
  SettingRow copyWithCompanion(SettingsCompanion data) {
    return SettingRow(
      key: data.key.present ? data.key.value : this.key,
      value: data.value.present ? data.value.value : this.value,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SettingRow(')
          ..write('key: $key, ')
          ..write('value: $value')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(key, value);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SettingRow &&
          other.key == this.key &&
          other.value == this.value);
}

class SettingsCompanion extends UpdateCompanion<SettingRow> {
  final Value<String> key;
  final Value<String> value;
  final Value<int> rowid;
  const SettingsCompanion({
    this.key = const Value.absent(),
    this.value = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SettingsCompanion.insert({
    required String key,
    required String value,
    this.rowid = const Value.absent(),
  }) : key = Value(key),
       value = Value(value);
  static Insertable<SettingRow> custom({
    Expression<String>? key,
    Expression<String>? value,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (key != null) 'key': key,
      if (value != null) 'value': value,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SettingsCompanion copyWith({
    Value<String>? key,
    Value<String>? value,
    Value<int>? rowid,
  }) {
    return SettingsCompanion(
      key: key ?? this.key,
      value: value ?? this.value,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (value.present) {
      map['value'] = Variable<String>(value.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SettingsCompanion(')
          ..write('key: $key, ')
          ..write('value: $value, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$VaultVoiceDatabase extends GeneratedDatabase {
  _$VaultVoiceDatabase(QueryExecutor e) : super(e);
  $VaultVoiceDatabaseManager get managers => $VaultVoiceDatabaseManager(this);
  late final $RecordingsTable recordings = $RecordingsTable(this);
  late final $AudioChunksTable audioChunks = $AudioChunksTable(this);
  late final $SpeechSegmentsTable speechSegments = $SpeechSegmentsTable(this);
  late final $MarkersTable markers = $MarkersTable(this);
  late final $SpeakersTable speakers = $SpeakersTable(this);
  late final $TranscriptsTable transcripts = $TranscriptsTable(this);
  late final $TranscriptSegmentsTable transcriptSegments =
      $TranscriptSegmentsTable(this);
  late final $JobsTable jobs = $JobsTable(this);
  late final $ProfilesTable profiles = $ProfilesTable(this);
  late final $TemplatesTable templates = $TemplatesTable(this);
  late final $ExtractionsTable extractions = $ExtractionsTable(this);
  late final $ActionItemsTable actionItems = $ActionItemsTable(this);
  late final $VaultTargetsTable vaultTargets = $VaultTargetsTable(this);
  late final $RoutingRulesTable routingRules = $RoutingRulesTable(this);
  late final $ExportsTable exports = $ExportsTable(this);
  late final $ModelsInstalledTable modelsInstalled = $ModelsInstalledTable(
    this,
  );
  late final $SettingsTable settings = $SettingsTable(this);
  late final RecordingsRepository recordingsRepository = RecordingsRepository(
    this as VaultVoiceDatabase,
  );
  late final TranscriptsRepository transcriptsRepository =
      TranscriptsRepository(this as VaultVoiceDatabase);
  late final JobsRepository jobsRepository = JobsRepository(
    this as VaultVoiceDatabase,
  );
  late final ProfilesRepository profilesRepository = ProfilesRepository(
    this as VaultVoiceDatabase,
  );
  late final ExtractionsRepository extractionsRepository =
      ExtractionsRepository(this as VaultVoiceDatabase);
  late final VaultRepository vaultRepository = VaultRepository(
    this as VaultVoiceDatabase,
  );
  late final ModelsRepository modelsRepository = ModelsRepository(
    this as VaultVoiceDatabase,
  );
  late final SettingsRepository settingsRepository = SettingsRepository(
    this as VaultVoiceDatabase,
  );
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    recordings,
    audioChunks,
    speechSegments,
    markers,
    speakers,
    transcripts,
    transcriptSegments,
    jobs,
    profiles,
    templates,
    extractions,
    actionItems,
    vaultTargets,
    routingRules,
    exports,
    modelsInstalled,
    settings,
  ];
  @override
  StreamQueryUpdateRules get streamUpdateRules => const StreamQueryUpdateRules([
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'recordings',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('audio_chunks', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'recordings',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('speech_segments', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'recordings',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('markers', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'recordings',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('speakers', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'recordings',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('transcripts', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'transcripts',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('transcript_segments', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'recordings',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('jobs', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'profiles',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('templates', kind: UpdateKind.update)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'recordings',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('extractions', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'recordings',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('action_items', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'extractions',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('action_items', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'vault_targets',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('routing_rules', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'recordings',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('exports', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'vault_targets',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('exports', kind: UpdateKind.delete)],
    ),
  ]);
}

typedef $$RecordingsTableCreateCompanionBuilder = RecordingsCompanion Function({
  required String id,
  Value<String> title,
  required DateTime createdAt,
  Value<int> durationMs,
  required RecordingStatus status,
  required RecordingSource source,
  Value<String?> profileId,
  Value<List<String>> tags,
  Value<DateTime?> consentConfirmedAt,
  Value<DateTime?> importAttestedAt,
  Value<StopReason?> stopReason,
  Value<bool> recovered,
  Value<int> rowid,
});
typedef $$RecordingsTableUpdateCompanionBuilder = RecordingsCompanion Function({
  Value<String> id,
  Value<String> title,
  Value<DateTime> createdAt,
  Value<int> durationMs,
  Value<RecordingStatus> status,
  Value<RecordingSource> source,
  Value<String?> profileId,
  Value<List<String>> tags,
  Value<DateTime?> consentConfirmedAt,
  Value<DateTime?> importAttestedAt,
  Value<StopReason?> stopReason,
  Value<bool> recovered,
  Value<int> rowid,
});

final class $$RecordingsTableReferences
    extends
        BaseReferences<_$VaultVoiceDatabase, $RecordingsTable, RecordingRow> {
  $$RecordingsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$AudioChunksTable, List<AudioChunkRow>>
  _audioChunksRefsTable(_$VaultVoiceDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.audioChunks,
        aliasName: 'recordings__id__audio_chunks__recording_id',
      );

  $$AudioChunksTableProcessedTableManager get audioChunksRefs {
    final manager = $$AudioChunksTableTableManager(
      $_db,
      $_db.audioChunks,
    ).filter((f) => f.recordingId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_audioChunksRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$SpeechSegmentsTable, List<SpeechSegmentRow>>
  _speechSegmentsRefsTable(_$VaultVoiceDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.speechSegments,
        aliasName: 'recordings__id__speech_segments__recording_id',
      );

  $$SpeechSegmentsTableProcessedTableManager get speechSegmentsRefs {
    final manager = $$SpeechSegmentsTableTableManager(
      $_db,
      $_db.speechSegments,
    ).filter((f) => f.recordingId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_speechSegmentsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$MarkersTable, List<MarkerRow>> _markersRefsTable(
    _$VaultVoiceDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.markers,
    aliasName: 'recordings__id__markers__recording_id',
  );

  $$MarkersTableProcessedTableManager get markersRefs {
    final manager = $$MarkersTableTableManager(
      $_db,
      $_db.markers,
    ).filter((f) => f.recordingId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_markersRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$SpeakersTable, List<SpeakerRow>>
  _speakersRefsTable(_$VaultVoiceDatabase db) => MultiTypedResultKey.fromTable(
    db.speakers,
    aliasName: 'recordings__id__speakers__recording_id',
  );

  $$SpeakersTableProcessedTableManager get speakersRefs {
    final manager = $$SpeakersTableTableManager(
      $_db,
      $_db.speakers,
    ).filter((f) => f.recordingId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_speakersRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$TranscriptsTable, List<TranscriptRow>>
  _transcriptsRefsTable(_$VaultVoiceDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.transcripts,
        aliasName: 'recordings__id__transcripts__recording_id',
      );

  $$TranscriptsTableProcessedTableManager get transcriptsRefs {
    final manager = $$TranscriptsTableTableManager(
      $_db,
      $_db.transcripts,
    ).filter((f) => f.recordingId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_transcriptsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$JobsTable, List<JobRow>> _jobsRefsTable(
    _$VaultVoiceDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.jobs,
    aliasName: 'recordings__id__jobs__recording_id',
  );

  $$JobsTableProcessedTableManager get jobsRefs {
    final manager = $$JobsTableTableManager(
      $_db,
      $_db.jobs,
    ).filter((f) => f.recordingId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_jobsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$ExtractionsTable, List<ExtractionRow>>
  _extractionsRefsTable(_$VaultVoiceDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.extractions,
        aliasName: 'recordings__id__extractions__recording_id',
      );

  $$ExtractionsTableProcessedTableManager get extractionsRefs {
    final manager = $$ExtractionsTableTableManager(
      $_db,
      $_db.extractions,
    ).filter((f) => f.recordingId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_extractionsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$ActionItemsTable, List<ActionItemRow>>
  _actionItemsRefsTable(_$VaultVoiceDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.actionItems,
        aliasName: 'recordings__id__action_items__recording_id',
      );

  $$ActionItemsTableProcessedTableManager get actionItemsRefs {
    final manager = $$ActionItemsTableTableManager(
      $_db,
      $_db.actionItems,
    ).filter((f) => f.recordingId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_actionItemsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$ExportsTable, List<ExportRow>> _exportsRefsTable(
    _$VaultVoiceDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.exports,
    aliasName: 'recordings__id__exports__recording_id',
  );

  $$ExportsTableProcessedTableManager get exportsRefs {
    final manager = $$ExportsTableTableManager(
      $_db,
      $_db.exports,
    ).filter((f) => f.recordingId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_exportsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$RecordingsTableFilterComposer
    extends Composer<_$VaultVoiceDatabase, $RecordingsTable> {
  $$RecordingsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<DateTime, DateTime, int> get createdAt =>
      $composableBuilder(
        column: $table.createdAt,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnFilters<int> get durationMs => $composableBuilder(
    column: $table.durationMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<RecordingStatus, RecordingStatus, String>
  get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnWithTypeConverterFilters<RecordingSource, RecordingSource, String>
  get source => $composableBuilder(
    column: $table.source,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnFilters<String> get profileId => $composableBuilder(
    column: $table.profileId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<List<String>, List<String>, String> get tags =>
      $composableBuilder(
        column: $table.tags,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnWithTypeConverterFilters<DateTime?, DateTime, int>
  get consentConfirmedAt => $composableBuilder(
    column: $table.consentConfirmedAt,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnWithTypeConverterFilters<DateTime?, DateTime, int>
  get importAttestedAt => $composableBuilder(
    column: $table.importAttestedAt,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnWithTypeConverterFilters<StopReason?, StopReason, String>
  get stopReason => $composableBuilder(
    column: $table.stopReason,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnFilters<bool> get recovered => $composableBuilder(
    column: $table.recovered,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> audioChunksRefs(
    Expression<bool> Function($$AudioChunksTableFilterComposer f) f,
  ) {
    final $$AudioChunksTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.audioChunks,
      getReferencedColumn: (t) => t.recordingId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AudioChunksTableFilterComposer(
            $db: $db,
            $table: $db.audioChunks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> speechSegmentsRefs(
    Expression<bool> Function($$SpeechSegmentsTableFilterComposer f) f,
  ) {
    final $$SpeechSegmentsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.speechSegments,
      getReferencedColumn: (t) => t.recordingId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SpeechSegmentsTableFilterComposer(
            $db: $db,
            $table: $db.speechSegments,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> markersRefs(
    Expression<bool> Function($$MarkersTableFilterComposer f) f,
  ) {
    final $$MarkersTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.markers,
      getReferencedColumn: (t) => t.recordingId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MarkersTableFilterComposer(
            $db: $db,
            $table: $db.markers,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> speakersRefs(
    Expression<bool> Function($$SpeakersTableFilterComposer f) f,
  ) {
    final $$SpeakersTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.speakers,
      getReferencedColumn: (t) => t.recordingId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SpeakersTableFilterComposer(
            $db: $db,
            $table: $db.speakers,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> transcriptsRefs(
    Expression<bool> Function($$TranscriptsTableFilterComposer f) f,
  ) {
    final $$TranscriptsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.transcripts,
      getReferencedColumn: (t) => t.recordingId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TranscriptsTableFilterComposer(
            $db: $db,
            $table: $db.transcripts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> jobsRefs(
    Expression<bool> Function($$JobsTableFilterComposer f) f,
  ) {
    final $$JobsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.jobs,
      getReferencedColumn: (t) => t.recordingId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$JobsTableFilterComposer(
            $db: $db,
            $table: $db.jobs,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> extractionsRefs(
    Expression<bool> Function($$ExtractionsTableFilterComposer f) f,
  ) {
    final $$ExtractionsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.extractions,
      getReferencedColumn: (t) => t.recordingId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ExtractionsTableFilterComposer(
            $db: $db,
            $table: $db.extractions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> actionItemsRefs(
    Expression<bool> Function($$ActionItemsTableFilterComposer f) f,
  ) {
    final $$ActionItemsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.actionItems,
      getReferencedColumn: (t) => t.recordingId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ActionItemsTableFilterComposer(
            $db: $db,
            $table: $db.actionItems,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> exportsRefs(
    Expression<bool> Function($$ExportsTableFilterComposer f) f,
  ) {
    final $$ExportsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.exports,
      getReferencedColumn: (t) => t.recordingId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ExportsTableFilterComposer(
            $db: $db,
            $table: $db.exports,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$RecordingsTableOrderingComposer
    extends Composer<_$VaultVoiceDatabase, $RecordingsTable> {
  $$RecordingsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get durationMs => $composableBuilder(
    column: $table.durationMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get source => $composableBuilder(
    column: $table.source,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get profileId => $composableBuilder(
    column: $table.profileId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get tags => $composableBuilder(
    column: $table.tags,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get consentConfirmedAt => $composableBuilder(
    column: $table.consentConfirmedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get importAttestedAt => $composableBuilder(
    column: $table.importAttestedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get stopReason => $composableBuilder(
    column: $table.stopReason,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get recovered => $composableBuilder(
    column: $table.recovered,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$RecordingsTableAnnotationComposer
    extends Composer<_$VaultVoiceDatabase, $RecordingsTable> {
  $$RecordingsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumnWithTypeConverter<DateTime, int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<int> get durationMs => $composableBuilder(
    column: $table.durationMs,
    builder: (column) => column,
  );

  GeneratedColumnWithTypeConverter<RecordingStatus, String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumnWithTypeConverter<RecordingSource, String> get source =>
      $composableBuilder(column: $table.source, builder: (column) => column);

  GeneratedColumn<String> get profileId =>
      $composableBuilder(column: $table.profileId, builder: (column) => column);

  GeneratedColumnWithTypeConverter<List<String>, String> get tags =>
      $composableBuilder(column: $table.tags, builder: (column) => column);

  GeneratedColumnWithTypeConverter<DateTime?, int> get consentConfirmedAt =>
      $composableBuilder(
        column: $table.consentConfirmedAt,
        builder: (column) => column,
      );

  GeneratedColumnWithTypeConverter<DateTime?, int> get importAttestedAt =>
      $composableBuilder(
        column: $table.importAttestedAt,
        builder: (column) => column,
      );

  GeneratedColumnWithTypeConverter<StopReason?, String> get stopReason =>
      $composableBuilder(
        column: $table.stopReason,
        builder: (column) => column,
      );

  GeneratedColumn<bool> get recovered =>
      $composableBuilder(column: $table.recovered, builder: (column) => column);

  Expression<T> audioChunksRefs<T extends Object>(
    Expression<T> Function($$AudioChunksTableAnnotationComposer a) f,
  ) {
    final $$AudioChunksTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.audioChunks,
      getReferencedColumn: (t) => t.recordingId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AudioChunksTableAnnotationComposer(
            $db: $db,
            $table: $db.audioChunks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> speechSegmentsRefs<T extends Object>(
    Expression<T> Function($$SpeechSegmentsTableAnnotationComposer a) f,
  ) {
    final $$SpeechSegmentsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.speechSegments,
      getReferencedColumn: (t) => t.recordingId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SpeechSegmentsTableAnnotationComposer(
            $db: $db,
            $table: $db.speechSegments,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> markersRefs<T extends Object>(
    Expression<T> Function($$MarkersTableAnnotationComposer a) f,
  ) {
    final $$MarkersTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.markers,
      getReferencedColumn: (t) => t.recordingId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MarkersTableAnnotationComposer(
            $db: $db,
            $table: $db.markers,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> speakersRefs<T extends Object>(
    Expression<T> Function($$SpeakersTableAnnotationComposer a) f,
  ) {
    final $$SpeakersTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.speakers,
      getReferencedColumn: (t) => t.recordingId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SpeakersTableAnnotationComposer(
            $db: $db,
            $table: $db.speakers,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> transcriptsRefs<T extends Object>(
    Expression<T> Function($$TranscriptsTableAnnotationComposer a) f,
  ) {
    final $$TranscriptsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.transcripts,
      getReferencedColumn: (t) => t.recordingId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TranscriptsTableAnnotationComposer(
            $db: $db,
            $table: $db.transcripts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> jobsRefs<T extends Object>(
    Expression<T> Function($$JobsTableAnnotationComposer a) f,
  ) {
    final $$JobsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.jobs,
      getReferencedColumn: (t) => t.recordingId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$JobsTableAnnotationComposer(
            $db: $db,
            $table: $db.jobs,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> extractionsRefs<T extends Object>(
    Expression<T> Function($$ExtractionsTableAnnotationComposer a) f,
  ) {
    final $$ExtractionsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.extractions,
      getReferencedColumn: (t) => t.recordingId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ExtractionsTableAnnotationComposer(
            $db: $db,
            $table: $db.extractions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> actionItemsRefs<T extends Object>(
    Expression<T> Function($$ActionItemsTableAnnotationComposer a) f,
  ) {
    final $$ActionItemsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.actionItems,
      getReferencedColumn: (t) => t.recordingId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ActionItemsTableAnnotationComposer(
            $db: $db,
            $table: $db.actionItems,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> exportsRefs<T extends Object>(
    Expression<T> Function($$ExportsTableAnnotationComposer a) f,
  ) {
    final $$ExportsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.exports,
      getReferencedColumn: (t) => t.recordingId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ExportsTableAnnotationComposer(
            $db: $db,
            $table: $db.exports,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$RecordingsTableTableManager
    extends
        RootTableManager<
          _$VaultVoiceDatabase,
          $RecordingsTable,
          RecordingRow,
          $$RecordingsTableFilterComposer,
          $$RecordingsTableOrderingComposer,
          $$RecordingsTableAnnotationComposer,
          $$RecordingsTableCreateCompanionBuilder,
          $$RecordingsTableUpdateCompanionBuilder,
          (RecordingRow, $$RecordingsTableReferences),
          RecordingRow,
          PrefetchHooks Function({
            bool audioChunksRefs,
            bool speechSegmentsRefs,
            bool markersRefs,
            bool speakersRefs,
            bool transcriptsRefs,
            bool jobsRefs,
            bool extractionsRefs,
            bool actionItemsRefs,
            bool exportsRefs,
          })
        > {
  $$RecordingsTableTableManager(_$VaultVoiceDatabase db, $RecordingsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$RecordingsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$RecordingsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$RecordingsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> durationMs = const Value.absent(),
                Value<RecordingStatus> status = const Value.absent(),
                Value<RecordingSource> source = const Value.absent(),
                Value<String?> profileId = const Value.absent(),
                Value<List<String>> tags = const Value.absent(),
                Value<DateTime?> consentConfirmedAt = const Value.absent(),
                Value<DateTime?> importAttestedAt = const Value.absent(),
                Value<StopReason?> stopReason = const Value.absent(),
                Value<bool> recovered = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => RecordingsCompanion(
                id: id,
                title: title,
                createdAt: createdAt,
                durationMs: durationMs,
                status: status,
                source: source,
                profileId: profileId,
                tags: tags,
                consentConfirmedAt: consentConfirmedAt,
                importAttestedAt: importAttestedAt,
                stopReason: stopReason,
                recovered: recovered,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                Value<String> title = const Value.absent(),
                required DateTime createdAt,
                Value<int> durationMs = const Value.absent(),
                required RecordingStatus status,
                required RecordingSource source,
                Value<String?> profileId = const Value.absent(),
                Value<List<String>> tags = const Value.absent(),
                Value<DateTime?> consentConfirmedAt = const Value.absent(),
                Value<DateTime?> importAttestedAt = const Value.absent(),
                Value<StopReason?> stopReason = const Value.absent(),
                Value<bool> recovered = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => RecordingsCompanion.insert(
                id: id,
                title: title,
                createdAt: createdAt,
                durationMs: durationMs,
                status: status,
                source: source,
                profileId: profileId,
                tags: tags,
                consentConfirmedAt: consentConfirmedAt,
                importAttestedAt: importAttestedAt,
                stopReason: stopReason,
                recovered: recovered,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$RecordingsTable, RecordingRow>(table),
                  $$RecordingsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({
                audioChunksRefs = false,
                speechSegmentsRefs = false,
                markersRefs = false,
                speakersRefs = false,
                transcriptsRefs = false,
                jobsRefs = false,
                extractionsRefs = false,
                actionItemsRefs = false,
                exportsRefs = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (audioChunksRefs) db.audioChunks,
                    if (speechSegmentsRefs) db.speechSegments,
                    if (markersRefs) db.markers,
                    if (speakersRefs) db.speakers,
                    if (transcriptsRefs) db.transcripts,
                    if (jobsRefs) db.jobs,
                    if (extractionsRefs) db.extractions,
                    if (actionItemsRefs) db.actionItems,
                    if (exportsRefs) db.exports,
                  ],
                  addJoins: null,
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (audioChunksRefs)
                        await $_getPrefetchedData<
                          RecordingRow,
                          $RecordingsTable,
                          AudioChunkRow
                        >(
                          currentTable: table,
                          referencedTable: $$RecordingsTableReferences
                              ._audioChunksRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$RecordingsTableReferences(
                                db,
                                table,
                                p0,
                              ).audioChunksRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.recordingId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (speechSegmentsRefs)
                        await $_getPrefetchedData<
                          RecordingRow,
                          $RecordingsTable,
                          SpeechSegmentRow
                        >(
                          currentTable: table,
                          referencedTable: $$RecordingsTableReferences
                              ._speechSegmentsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$RecordingsTableReferences(
                                db,
                                table,
                                p0,
                              ).speechSegmentsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.recordingId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (markersRefs)
                        await $_getPrefetchedData<
                          RecordingRow,
                          $RecordingsTable,
                          MarkerRow
                        >(
                          currentTable: table,
                          referencedTable: $$RecordingsTableReferences
                              ._markersRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$RecordingsTableReferences(
                                db,
                                table,
                                p0,
                              ).markersRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.recordingId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (speakersRefs)
                        await $_getPrefetchedData<
                          RecordingRow,
                          $RecordingsTable,
                          SpeakerRow
                        >(
                          currentTable: table,
                          referencedTable: $$RecordingsTableReferences
                              ._speakersRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$RecordingsTableReferences(
                                db,
                                table,
                                p0,
                              ).speakersRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.recordingId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (transcriptsRefs)
                        await $_getPrefetchedData<
                          RecordingRow,
                          $RecordingsTable,
                          TranscriptRow
                        >(
                          currentTable: table,
                          referencedTable: $$RecordingsTableReferences
                              ._transcriptsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$RecordingsTableReferences(
                                db,
                                table,
                                p0,
                              ).transcriptsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.recordingId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (jobsRefs)
                        await $_getPrefetchedData<
                          RecordingRow,
                          $RecordingsTable,
                          JobRow
                        >(
                          currentTable: table,
                          referencedTable: $$RecordingsTableReferences
                              ._jobsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$RecordingsTableReferences(
                                db,
                                table,
                                p0,
                              ).jobsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.recordingId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (extractionsRefs)
                        await $_getPrefetchedData<
                          RecordingRow,
                          $RecordingsTable,
                          ExtractionRow
                        >(
                          currentTable: table,
                          referencedTable: $$RecordingsTableReferences
                              ._extractionsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$RecordingsTableReferences(
                                db,
                                table,
                                p0,
                              ).extractionsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.recordingId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (actionItemsRefs)
                        await $_getPrefetchedData<
                          RecordingRow,
                          $RecordingsTable,
                          ActionItemRow
                        >(
                          currentTable: table,
                          referencedTable: $$RecordingsTableReferences
                              ._actionItemsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$RecordingsTableReferences(
                                db,
                                table,
                                p0,
                              ).actionItemsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.recordingId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (exportsRefs)
                        await $_getPrefetchedData<
                          RecordingRow,
                          $RecordingsTable,
                          ExportRow
                        >(
                          currentTable: table,
                          referencedTable: $$RecordingsTableReferences
                              ._exportsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$RecordingsTableReferences(
                                db,
                                table,
                                p0,
                              ).exportsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.recordingId == item.id,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$RecordingsTableProcessedTableManager =
    ProcessedTableManager<
      _$VaultVoiceDatabase,
      $RecordingsTable,
      RecordingRow,
      $$RecordingsTableFilterComposer,
      $$RecordingsTableOrderingComposer,
      $$RecordingsTableAnnotationComposer,
      $$RecordingsTableCreateCompanionBuilder,
      $$RecordingsTableUpdateCompanionBuilder,
      (RecordingRow, $$RecordingsTableReferences),
      RecordingRow,
      PrefetchHooks Function({
        bool audioChunksRefs,
        bool speechSegmentsRefs,
        bool markersRefs,
        bool speakersRefs,
        bool transcriptsRefs,
        bool jobsRefs,
        bool extractionsRefs,
        bool actionItemsRefs,
        bool exportsRefs,
      })
    >;
typedef $$AudioChunksTableCreateCompanionBuilder =
    AudioChunksCompanion Function({
      Value<int> id,
      required String recordingId,
      required int seq,
      required String path,
      required int sampleRate,
      required int startMs,
      required int endMs,
      required int bytes,
      Value<String?> sha256,
    });
typedef $$AudioChunksTableUpdateCompanionBuilder =
    AudioChunksCompanion Function({
      Value<int> id,
      Value<String> recordingId,
      Value<int> seq,
      Value<String> path,
      Value<int> sampleRate,
      Value<int> startMs,
      Value<int> endMs,
      Value<int> bytes,
      Value<String?> sha256,
    });

final class $$AudioChunksTableReferences
    extends
        BaseReferences<_$VaultVoiceDatabase, $AudioChunksTable, AudioChunkRow> {
  $$AudioChunksTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $RecordingsTable _recordingIdTable(_$VaultVoiceDatabase db) =>
      db.recordings.createAlias('audio_chunks__recording_id__recordings__id');

  $$RecordingsTableProcessedTableManager get recordingId {
    final $_column = $_itemColumn<String>('recording_id')!;

    final manager = $$RecordingsTableTableManager(
      $_db,
      $_db.recordings,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_recordingIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$AudioChunksTableFilterComposer
    extends Composer<_$VaultVoiceDatabase, $AudioChunksTable> {
  $$AudioChunksTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get seq => $composableBuilder(
    column: $table.seq,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get path => $composableBuilder(
    column: $table.path,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sampleRate => $composableBuilder(
    column: $table.sampleRate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get startMs => $composableBuilder(
    column: $table.startMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get endMs => $composableBuilder(
    column: $table.endMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get bytes => $composableBuilder(
    column: $table.bytes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sha256 => $composableBuilder(
    column: $table.sha256,
    builder: (column) => ColumnFilters(column),
  );

  $$RecordingsTableFilterComposer get recordingId {
    final $$RecordingsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.recordingId,
      referencedTable: $db.recordings,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RecordingsTableFilterComposer(
            $db: $db,
            $table: $db.recordings,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$AudioChunksTableOrderingComposer
    extends Composer<_$VaultVoiceDatabase, $AudioChunksTable> {
  $$AudioChunksTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get seq => $composableBuilder(
    column: $table.seq,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get path => $composableBuilder(
    column: $table.path,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sampleRate => $composableBuilder(
    column: $table.sampleRate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get startMs => $composableBuilder(
    column: $table.startMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get endMs => $composableBuilder(
    column: $table.endMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get bytes => $composableBuilder(
    column: $table.bytes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sha256 => $composableBuilder(
    column: $table.sha256,
    builder: (column) => ColumnOrderings(column),
  );

  $$RecordingsTableOrderingComposer get recordingId {
    final $$RecordingsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.recordingId,
      referencedTable: $db.recordings,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RecordingsTableOrderingComposer(
            $db: $db,
            $table: $db.recordings,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$AudioChunksTableAnnotationComposer
    extends Composer<_$VaultVoiceDatabase, $AudioChunksTable> {
  $$AudioChunksTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get seq =>
      $composableBuilder(column: $table.seq, builder: (column) => column);

  GeneratedColumn<String> get path =>
      $composableBuilder(column: $table.path, builder: (column) => column);

  GeneratedColumn<int> get sampleRate => $composableBuilder(
    column: $table.sampleRate,
    builder: (column) => column,
  );

  GeneratedColumn<int> get startMs =>
      $composableBuilder(column: $table.startMs, builder: (column) => column);

  GeneratedColumn<int> get endMs =>
      $composableBuilder(column: $table.endMs, builder: (column) => column);

  GeneratedColumn<int> get bytes =>
      $composableBuilder(column: $table.bytes, builder: (column) => column);

  GeneratedColumn<String> get sha256 =>
      $composableBuilder(column: $table.sha256, builder: (column) => column);

  $$RecordingsTableAnnotationComposer get recordingId {
    final $$RecordingsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.recordingId,
      referencedTable: $db.recordings,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RecordingsTableAnnotationComposer(
            $db: $db,
            $table: $db.recordings,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$AudioChunksTableTableManager
    extends
        RootTableManager<
          _$VaultVoiceDatabase,
          $AudioChunksTable,
          AudioChunkRow,
          $$AudioChunksTableFilterComposer,
          $$AudioChunksTableOrderingComposer,
          $$AudioChunksTableAnnotationComposer,
          $$AudioChunksTableCreateCompanionBuilder,
          $$AudioChunksTableUpdateCompanionBuilder,
          (AudioChunkRow, $$AudioChunksTableReferences),
          AudioChunkRow,
          PrefetchHooks Function({bool recordingId})
        > {
  $$AudioChunksTableTableManager(
    _$VaultVoiceDatabase db,
    $AudioChunksTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AudioChunksTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AudioChunksTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AudioChunksTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> recordingId = const Value.absent(),
                Value<int> seq = const Value.absent(),
                Value<String> path = const Value.absent(),
                Value<int> sampleRate = const Value.absent(),
                Value<int> startMs = const Value.absent(),
                Value<int> endMs = const Value.absent(),
                Value<int> bytes = const Value.absent(),
                Value<String?> sha256 = const Value.absent(),
              }) => AudioChunksCompanion(
                id: id,
                recordingId: recordingId,
                seq: seq,
                path: path,
                sampleRate: sampleRate,
                startMs: startMs,
                endMs: endMs,
                bytes: bytes,
                sha256: sha256,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String recordingId,
                required int seq,
                required String path,
                required int sampleRate,
                required int startMs,
                required int endMs,
                required int bytes,
                Value<String?> sha256 = const Value.absent(),
              }) => AudioChunksCompanion.insert(
                id: id,
                recordingId: recordingId,
                seq: seq,
                path: path,
                sampleRate: sampleRate,
                startMs: startMs,
                endMs: endMs,
                bytes: bytes,
                sha256: sha256,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$AudioChunksTable, AudioChunkRow>(table),
                  $$AudioChunksTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({recordingId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (recordingId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.recordingId,
                        referencedTable: $$AudioChunksTableReferences
                            ._recordingIdTable(db),
                        referencedColumn: $$AudioChunksTableReferences
                            ._recordingIdTable(db)
                            .id,
                      ) as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$AudioChunksTableProcessedTableManager =
    ProcessedTableManager<
      _$VaultVoiceDatabase,
      $AudioChunksTable,
      AudioChunkRow,
      $$AudioChunksTableFilterComposer,
      $$AudioChunksTableOrderingComposer,
      $$AudioChunksTableAnnotationComposer,
      $$AudioChunksTableCreateCompanionBuilder,
      $$AudioChunksTableUpdateCompanionBuilder,
      (AudioChunkRow, $$AudioChunksTableReferences),
      AudioChunkRow,
      PrefetchHooks Function({bool recordingId})
    >;
typedef $$SpeechSegmentsTableCreateCompanionBuilder =
    SpeechSegmentsCompanion Function({
      Value<int> id,
      required String recordingId,
      required int startMs,
      required int endMs,
    });
typedef $$SpeechSegmentsTableUpdateCompanionBuilder =
    SpeechSegmentsCompanion Function({
      Value<int> id,
      Value<String> recordingId,
      Value<int> startMs,
      Value<int> endMs,
    });

final class $$SpeechSegmentsTableReferences
    extends
        BaseReferences<
          _$VaultVoiceDatabase,
          $SpeechSegmentsTable,
          SpeechSegmentRow
        > {
  $$SpeechSegmentsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $RecordingsTable _recordingIdTable(_$VaultVoiceDatabase db) => db
      .recordings
      .createAlias('speech_segments__recording_id__recordings__id');

  $$RecordingsTableProcessedTableManager get recordingId {
    final $_column = $_itemColumn<String>('recording_id')!;

    final manager = $$RecordingsTableTableManager(
      $_db,
      $_db.recordings,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_recordingIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$SpeechSegmentsTableFilterComposer
    extends Composer<_$VaultVoiceDatabase, $SpeechSegmentsTable> {
  $$SpeechSegmentsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get startMs => $composableBuilder(
    column: $table.startMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get endMs => $composableBuilder(
    column: $table.endMs,
    builder: (column) => ColumnFilters(column),
  );

  $$RecordingsTableFilterComposer get recordingId {
    final $$RecordingsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.recordingId,
      referencedTable: $db.recordings,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RecordingsTableFilterComposer(
            $db: $db,
            $table: $db.recordings,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$SpeechSegmentsTableOrderingComposer
    extends Composer<_$VaultVoiceDatabase, $SpeechSegmentsTable> {
  $$SpeechSegmentsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get startMs => $composableBuilder(
    column: $table.startMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get endMs => $composableBuilder(
    column: $table.endMs,
    builder: (column) => ColumnOrderings(column),
  );

  $$RecordingsTableOrderingComposer get recordingId {
    final $$RecordingsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.recordingId,
      referencedTable: $db.recordings,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RecordingsTableOrderingComposer(
            $db: $db,
            $table: $db.recordings,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$SpeechSegmentsTableAnnotationComposer
    extends Composer<_$VaultVoiceDatabase, $SpeechSegmentsTable> {
  $$SpeechSegmentsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get startMs =>
      $composableBuilder(column: $table.startMs, builder: (column) => column);

  GeneratedColumn<int> get endMs =>
      $composableBuilder(column: $table.endMs, builder: (column) => column);

  $$RecordingsTableAnnotationComposer get recordingId {
    final $$RecordingsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.recordingId,
      referencedTable: $db.recordings,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RecordingsTableAnnotationComposer(
            $db: $db,
            $table: $db.recordings,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$SpeechSegmentsTableTableManager
    extends
        RootTableManager<
          _$VaultVoiceDatabase,
          $SpeechSegmentsTable,
          SpeechSegmentRow,
          $$SpeechSegmentsTableFilterComposer,
          $$SpeechSegmentsTableOrderingComposer,
          $$SpeechSegmentsTableAnnotationComposer,
          $$SpeechSegmentsTableCreateCompanionBuilder,
          $$SpeechSegmentsTableUpdateCompanionBuilder,
          (SpeechSegmentRow, $$SpeechSegmentsTableReferences),
          SpeechSegmentRow,
          PrefetchHooks Function({bool recordingId})
        > {
  $$SpeechSegmentsTableTableManager(
    _$VaultVoiceDatabase db,
    $SpeechSegmentsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SpeechSegmentsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SpeechSegmentsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SpeechSegmentsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> recordingId = const Value.absent(),
                Value<int> startMs = const Value.absent(),
                Value<int> endMs = const Value.absent(),
              }) => SpeechSegmentsCompanion(
                id: id,
                recordingId: recordingId,
                startMs: startMs,
                endMs: endMs,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String recordingId,
                required int startMs,
                required int endMs,
              }) => SpeechSegmentsCompanion.insert(
                id: id,
                recordingId: recordingId,
                startMs: startMs,
                endMs: endMs,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$SpeechSegmentsTable, SpeechSegmentRow>(table),
                  $$SpeechSegmentsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({recordingId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (recordingId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.recordingId,
                        referencedTable: $$SpeechSegmentsTableReferences
                            ._recordingIdTable(db),
                        referencedColumn: $$SpeechSegmentsTableReferences
                            ._recordingIdTable(db)
                            .id,
                      ) as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$SpeechSegmentsTableProcessedTableManager =
    ProcessedTableManager<
      _$VaultVoiceDatabase,
      $SpeechSegmentsTable,
      SpeechSegmentRow,
      $$SpeechSegmentsTableFilterComposer,
      $$SpeechSegmentsTableOrderingComposer,
      $$SpeechSegmentsTableAnnotationComposer,
      $$SpeechSegmentsTableCreateCompanionBuilder,
      $$SpeechSegmentsTableUpdateCompanionBuilder,
      (SpeechSegmentRow, $$SpeechSegmentsTableReferences),
      SpeechSegmentRow,
      PrefetchHooks Function({bool recordingId})
    >;
typedef $$MarkersTableCreateCompanionBuilder = MarkersCompanion Function({
  Value<int> id,
  required String recordingId,
  required int atMs,
  required MarkerKind kind,
  Value<String?> label,
});
typedef $$MarkersTableUpdateCompanionBuilder = MarkersCompanion Function({
  Value<int> id,
  Value<String> recordingId,
  Value<int> atMs,
  Value<MarkerKind> kind,
  Value<String?> label,
});

final class $$MarkersTableReferences
    extends BaseReferences<_$VaultVoiceDatabase, $MarkersTable, MarkerRow> {
  $$MarkersTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $RecordingsTable _recordingIdTable(_$VaultVoiceDatabase db) =>
      db.recordings.createAlias('markers__recording_id__recordings__id');

  $$RecordingsTableProcessedTableManager get recordingId {
    final $_column = $_itemColumn<String>('recording_id')!;

    final manager = $$RecordingsTableTableManager(
      $_db,
      $_db.recordings,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_recordingIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$MarkersTableFilterComposer
    extends Composer<_$VaultVoiceDatabase, $MarkersTable> {
  $$MarkersTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get atMs => $composableBuilder(
    column: $table.atMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<MarkerKind, MarkerKind, String> get kind =>
      $composableBuilder(
        column: $table.kind,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnFilters<String> get label => $composableBuilder(
    column: $table.label,
    builder: (column) => ColumnFilters(column),
  );

  $$RecordingsTableFilterComposer get recordingId {
    final $$RecordingsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.recordingId,
      referencedTable: $db.recordings,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RecordingsTableFilterComposer(
            $db: $db,
            $table: $db.recordings,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$MarkersTableOrderingComposer
    extends Composer<_$VaultVoiceDatabase, $MarkersTable> {
  $$MarkersTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get atMs => $composableBuilder(
    column: $table.atMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get label => $composableBuilder(
    column: $table.label,
    builder: (column) => ColumnOrderings(column),
  );

  $$RecordingsTableOrderingComposer get recordingId {
    final $$RecordingsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.recordingId,
      referencedTable: $db.recordings,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RecordingsTableOrderingComposer(
            $db: $db,
            $table: $db.recordings,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$MarkersTableAnnotationComposer
    extends Composer<_$VaultVoiceDatabase, $MarkersTable> {
  $$MarkersTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get atMs =>
      $composableBuilder(column: $table.atMs, builder: (column) => column);

  GeneratedColumnWithTypeConverter<MarkerKind, String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<String> get label =>
      $composableBuilder(column: $table.label, builder: (column) => column);

  $$RecordingsTableAnnotationComposer get recordingId {
    final $$RecordingsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.recordingId,
      referencedTable: $db.recordings,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RecordingsTableAnnotationComposer(
            $db: $db,
            $table: $db.recordings,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$MarkersTableTableManager
    extends
        RootTableManager<
          _$VaultVoiceDatabase,
          $MarkersTable,
          MarkerRow,
          $$MarkersTableFilterComposer,
          $$MarkersTableOrderingComposer,
          $$MarkersTableAnnotationComposer,
          $$MarkersTableCreateCompanionBuilder,
          $$MarkersTableUpdateCompanionBuilder,
          (MarkerRow, $$MarkersTableReferences),
          MarkerRow,
          PrefetchHooks Function({bool recordingId})
        > {
  $$MarkersTableTableManager(_$VaultVoiceDatabase db, $MarkersTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$MarkersTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$MarkersTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$MarkersTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> recordingId = const Value.absent(),
                Value<int> atMs = const Value.absent(),
                Value<MarkerKind> kind = const Value.absent(),
                Value<String?> label = const Value.absent(),
              }) => MarkersCompanion(
                id: id,
                recordingId: recordingId,
                atMs: atMs,
                kind: kind,
                label: label,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String recordingId,
                required int atMs,
                required MarkerKind kind,
                Value<String?> label = const Value.absent(),
              }) => MarkersCompanion.insert(
                id: id,
                recordingId: recordingId,
                atMs: atMs,
                kind: kind,
                label: label,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$MarkersTable, MarkerRow>(table),
                  $$MarkersTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({recordingId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (recordingId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.recordingId,
                        referencedTable: $$MarkersTableReferences
                            ._recordingIdTable(db),
                        referencedColumn: $$MarkersTableReferences
                            ._recordingIdTable(db)
                            .id,
                      ) as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$MarkersTableProcessedTableManager =
    ProcessedTableManager<
      _$VaultVoiceDatabase,
      $MarkersTable,
      MarkerRow,
      $$MarkersTableFilterComposer,
      $$MarkersTableOrderingComposer,
      $$MarkersTableAnnotationComposer,
      $$MarkersTableCreateCompanionBuilder,
      $$MarkersTableUpdateCompanionBuilder,
      (MarkerRow, $$MarkersTableReferences),
      MarkerRow,
      PrefetchHooks Function({bool recordingId})
    >;
typedef $$SpeakersTableCreateCompanionBuilder = SpeakersCompanion Function({
  Value<int> id,
  required String recordingId,
  required String label,
  Value<String?> displayName,
});
typedef $$SpeakersTableUpdateCompanionBuilder = SpeakersCompanion Function({
  Value<int> id,
  Value<String> recordingId,
  Value<String> label,
  Value<String?> displayName,
});

final class $$SpeakersTableReferences
    extends BaseReferences<_$VaultVoiceDatabase, $SpeakersTable, SpeakerRow> {
  $$SpeakersTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $RecordingsTable _recordingIdTable(_$VaultVoiceDatabase db) =>
      db.recordings.createAlias('speakers__recording_id__recordings__id');

  $$RecordingsTableProcessedTableManager get recordingId {
    final $_column = $_itemColumn<String>('recording_id')!;

    final manager = $$RecordingsTableTableManager(
      $_db,
      $_db.recordings,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_recordingIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$SpeakersTableFilterComposer
    extends Composer<_$VaultVoiceDatabase, $SpeakersTable> {
  $$SpeakersTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get label => $composableBuilder(
    column: $table.label,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get displayName => $composableBuilder(
    column: $table.displayName,
    builder: (column) => ColumnFilters(column),
  );

  $$RecordingsTableFilterComposer get recordingId {
    final $$RecordingsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.recordingId,
      referencedTable: $db.recordings,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RecordingsTableFilterComposer(
            $db: $db,
            $table: $db.recordings,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$SpeakersTableOrderingComposer
    extends Composer<_$VaultVoiceDatabase, $SpeakersTable> {
  $$SpeakersTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get label => $composableBuilder(
    column: $table.label,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get displayName => $composableBuilder(
    column: $table.displayName,
    builder: (column) => ColumnOrderings(column),
  );

  $$RecordingsTableOrderingComposer get recordingId {
    final $$RecordingsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.recordingId,
      referencedTable: $db.recordings,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RecordingsTableOrderingComposer(
            $db: $db,
            $table: $db.recordings,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$SpeakersTableAnnotationComposer
    extends Composer<_$VaultVoiceDatabase, $SpeakersTable> {
  $$SpeakersTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get label =>
      $composableBuilder(column: $table.label, builder: (column) => column);

  GeneratedColumn<String> get displayName => $composableBuilder(
    column: $table.displayName,
    builder: (column) => column,
  );

  $$RecordingsTableAnnotationComposer get recordingId {
    final $$RecordingsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.recordingId,
      referencedTable: $db.recordings,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RecordingsTableAnnotationComposer(
            $db: $db,
            $table: $db.recordings,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$SpeakersTableTableManager
    extends
        RootTableManager<
          _$VaultVoiceDatabase,
          $SpeakersTable,
          SpeakerRow,
          $$SpeakersTableFilterComposer,
          $$SpeakersTableOrderingComposer,
          $$SpeakersTableAnnotationComposer,
          $$SpeakersTableCreateCompanionBuilder,
          $$SpeakersTableUpdateCompanionBuilder,
          (SpeakerRow, $$SpeakersTableReferences),
          SpeakerRow,
          PrefetchHooks Function({bool recordingId})
        > {
  $$SpeakersTableTableManager(_$VaultVoiceDatabase db, $SpeakersTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SpeakersTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SpeakersTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SpeakersTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> recordingId = const Value.absent(),
                Value<String> label = const Value.absent(),
                Value<String?> displayName = const Value.absent(),
              }) => SpeakersCompanion(
                id: id,
                recordingId: recordingId,
                label: label,
                displayName: displayName,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String recordingId,
                required String label,
                Value<String?> displayName = const Value.absent(),
              }) => SpeakersCompanion.insert(
                id: id,
                recordingId: recordingId,
                label: label,
                displayName: displayName,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$SpeakersTable, SpeakerRow>(table),
                  $$SpeakersTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({recordingId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (recordingId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.recordingId,
                        referencedTable: $$SpeakersTableReferences
                            ._recordingIdTable(db),
                        referencedColumn: $$SpeakersTableReferences
                            ._recordingIdTable(db)
                            .id,
                      ) as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$SpeakersTableProcessedTableManager =
    ProcessedTableManager<
      _$VaultVoiceDatabase,
      $SpeakersTable,
      SpeakerRow,
      $$SpeakersTableFilterComposer,
      $$SpeakersTableOrderingComposer,
      $$SpeakersTableAnnotationComposer,
      $$SpeakersTableCreateCompanionBuilder,
      $$SpeakersTableUpdateCompanionBuilder,
      (SpeakerRow, $$SpeakersTableReferences),
      SpeakerRow,
      PrefetchHooks Function({bool recordingId})
    >;
typedef $$TranscriptsTableCreateCompanionBuilder =
    TranscriptsCompanion Function({
      required String id,
      required String recordingId,
      required String modelId,
      required String language,
      required DateTime createdAt,
      Value<bool> edited,
      Value<int> rowid,
    });
typedef $$TranscriptsTableUpdateCompanionBuilder =
    TranscriptsCompanion Function({
      Value<String> id,
      Value<String> recordingId,
      Value<String> modelId,
      Value<String> language,
      Value<DateTime> createdAt,
      Value<bool> edited,
      Value<int> rowid,
    });

final class $$TranscriptsTableReferences
    extends
        BaseReferences<_$VaultVoiceDatabase, $TranscriptsTable, TranscriptRow> {
  $$TranscriptsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $RecordingsTable _recordingIdTable(_$VaultVoiceDatabase db) =>
      db.recordings.createAlias('transcripts__recording_id__recordings__id');

  $$RecordingsTableProcessedTableManager get recordingId {
    final $_column = $_itemColumn<String>('recording_id')!;

    final manager = $$RecordingsTableTableManager(
      $_db,
      $_db.recordings,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_recordingIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<
    $TranscriptSegmentsTable,
    List<TranscriptSegmentRow>
  >
  _transcriptSegmentsRefsTable(_$VaultVoiceDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.transcriptSegments,
        aliasName: 'transcripts__id__transcript_segments__transcript_id',
      );

  $$TranscriptSegmentsTableProcessedTableManager get transcriptSegmentsRefs {
    final manager = $$TranscriptSegmentsTableTableManager(
      $_db,
      $_db.transcriptSegments,
    ).filter((f) => f.transcriptId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _transcriptSegmentsRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$TranscriptsTableFilterComposer
    extends Composer<_$VaultVoiceDatabase, $TranscriptsTable> {
  $$TranscriptsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get modelId => $composableBuilder(
    column: $table.modelId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get language => $composableBuilder(
    column: $table.language,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<DateTime, DateTime, int> get createdAt =>
      $composableBuilder(
        column: $table.createdAt,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnFilters<bool> get edited => $composableBuilder(
    column: $table.edited,
    builder: (column) => ColumnFilters(column),
  );

  $$RecordingsTableFilterComposer get recordingId {
    final $$RecordingsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.recordingId,
      referencedTable: $db.recordings,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RecordingsTableFilterComposer(
            $db: $db,
            $table: $db.recordings,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> transcriptSegmentsRefs(
    Expression<bool> Function($$TranscriptSegmentsTableFilterComposer f) f,
  ) {
    final $$TranscriptSegmentsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.transcriptSegments,
      getReferencedColumn: (t) => t.transcriptId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TranscriptSegmentsTableFilterComposer(
            $db: $db,
            $table: $db.transcriptSegments,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$TranscriptsTableOrderingComposer
    extends Composer<_$VaultVoiceDatabase, $TranscriptsTable> {
  $$TranscriptsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get modelId => $composableBuilder(
    column: $table.modelId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get language => $composableBuilder(
    column: $table.language,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get edited => $composableBuilder(
    column: $table.edited,
    builder: (column) => ColumnOrderings(column),
  );

  $$RecordingsTableOrderingComposer get recordingId {
    final $$RecordingsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.recordingId,
      referencedTable: $db.recordings,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RecordingsTableOrderingComposer(
            $db: $db,
            $table: $db.recordings,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$TranscriptsTableAnnotationComposer
    extends Composer<_$VaultVoiceDatabase, $TranscriptsTable> {
  $$TranscriptsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get modelId =>
      $composableBuilder(column: $table.modelId, builder: (column) => column);

  GeneratedColumn<String> get language =>
      $composableBuilder(column: $table.language, builder: (column) => column);

  GeneratedColumnWithTypeConverter<DateTime, int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<bool> get edited =>
      $composableBuilder(column: $table.edited, builder: (column) => column);

  $$RecordingsTableAnnotationComposer get recordingId {
    final $$RecordingsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.recordingId,
      referencedTable: $db.recordings,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RecordingsTableAnnotationComposer(
            $db: $db,
            $table: $db.recordings,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> transcriptSegmentsRefs<T extends Object>(
    Expression<T> Function($$TranscriptSegmentsTableAnnotationComposer a) f,
  ) {
    final $$TranscriptSegmentsTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.transcriptSegments,
          getReferencedColumn: (t) => t.transcriptId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$TranscriptSegmentsTableAnnotationComposer(
                $db: $db,
                $table: $db.transcriptSegments,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }
}

class $$TranscriptsTableTableManager
    extends
        RootTableManager<
          _$VaultVoiceDatabase,
          $TranscriptsTable,
          TranscriptRow,
          $$TranscriptsTableFilterComposer,
          $$TranscriptsTableOrderingComposer,
          $$TranscriptsTableAnnotationComposer,
          $$TranscriptsTableCreateCompanionBuilder,
          $$TranscriptsTableUpdateCompanionBuilder,
          (TranscriptRow, $$TranscriptsTableReferences),
          TranscriptRow,
          PrefetchHooks Function({
            bool recordingId,
            bool transcriptSegmentsRefs,
          })
        > {
  $$TranscriptsTableTableManager(
    _$VaultVoiceDatabase db,
    $TranscriptsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TranscriptsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TranscriptsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TranscriptsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> recordingId = const Value.absent(),
                Value<String> modelId = const Value.absent(),
                Value<String> language = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<bool> edited = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => TranscriptsCompanion(
                id: id,
                recordingId: recordingId,
                modelId: modelId,
                language: language,
                createdAt: createdAt,
                edited: edited,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String recordingId,
                required String modelId,
                required String language,
                required DateTime createdAt,
                Value<bool> edited = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => TranscriptsCompanion.insert(
                id: id,
                recordingId: recordingId,
                modelId: modelId,
                language: language,
                createdAt: createdAt,
                edited: edited,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$TranscriptsTable, TranscriptRow>(table),
                  $$TranscriptsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({recordingId = false, transcriptSegmentsRefs = false}) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (transcriptSegmentsRefs) db.transcriptSegments,
                  ],
                  addJoins:
                      <
                        T extends TableManagerState<
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic
                        >
                      >(state) {
                        if (recordingId) {
                          state = state.withJoin(
                            currentTable: table,
                            currentColumn: table.recordingId,
                            referencedTable: $$TranscriptsTableReferences
                                ._recordingIdTable(db),
                            referencedColumn: $$TranscriptsTableReferences
                                ._recordingIdTable(db)
                                .id,
                          ) as T;
                        }

                        return state;
                      },
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (transcriptSegmentsRefs)
                        await $_getPrefetchedData<
                          TranscriptRow,
                          $TranscriptsTable,
                          TranscriptSegmentRow
                        >(
                          currentTable: table,
                          referencedTable: $$TranscriptsTableReferences
                              ._transcriptSegmentsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$TranscriptsTableReferences(
                                db,
                                table,
                                p0,
                              ).transcriptSegmentsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.transcriptId == item.id,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$TranscriptsTableProcessedTableManager =
    ProcessedTableManager<
      _$VaultVoiceDatabase,
      $TranscriptsTable,
      TranscriptRow,
      $$TranscriptsTableFilterComposer,
      $$TranscriptsTableOrderingComposer,
      $$TranscriptsTableAnnotationComposer,
      $$TranscriptsTableCreateCompanionBuilder,
      $$TranscriptsTableUpdateCompanionBuilder,
      (TranscriptRow, $$TranscriptsTableReferences),
      TranscriptRow,
      PrefetchHooks Function({bool recordingId, bool transcriptSegmentsRefs})
    >;
typedef $$TranscriptSegmentsTableCreateCompanionBuilder =
    TranscriptSegmentsCompanion Function({
      Value<int> id,
      required String transcriptId,
      required int seq,
      required int startMs,
      required int endMs,
      Value<String?> speaker,
      required String body,
      Value<String?> originalText,
      Value<double?> avgLogprob,
      Value<String?> tokensJson,
    });
typedef $$TranscriptSegmentsTableUpdateCompanionBuilder =
    TranscriptSegmentsCompanion Function({
      Value<int> id,
      Value<String> transcriptId,
      Value<int> seq,
      Value<int> startMs,
      Value<int> endMs,
      Value<String?> speaker,
      Value<String> body,
      Value<String?> originalText,
      Value<double?> avgLogprob,
      Value<String?> tokensJson,
    });

final class $$TranscriptSegmentsTableReferences
    extends
        BaseReferences<
          _$VaultVoiceDatabase,
          $TranscriptSegmentsTable,
          TranscriptSegmentRow
        > {
  $$TranscriptSegmentsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $TranscriptsTable _transcriptIdTable(_$VaultVoiceDatabase db) => db
      .transcripts
      .createAlias('transcript_segments__transcript_id__transcripts__id');

  $$TranscriptsTableProcessedTableManager get transcriptId {
    final $_column = $_itemColumn<String>('transcript_id')!;

    final manager = $$TranscriptsTableTableManager(
      $_db,
      $_db.transcripts,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_transcriptIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$TranscriptSegmentsTableFilterComposer
    extends Composer<_$VaultVoiceDatabase, $TranscriptSegmentsTable> {
  $$TranscriptSegmentsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get seq => $composableBuilder(
    column: $table.seq,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get startMs => $composableBuilder(
    column: $table.startMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get endMs => $composableBuilder(
    column: $table.endMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get speaker => $composableBuilder(
    column: $table.speaker,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get body => $composableBuilder(
    column: $table.body,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get originalText => $composableBuilder(
    column: $table.originalText,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get avgLogprob => $composableBuilder(
    column: $table.avgLogprob,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get tokensJson => $composableBuilder(
    column: $table.tokensJson,
    builder: (column) => ColumnFilters(column),
  );

  $$TranscriptsTableFilterComposer get transcriptId {
    final $$TranscriptsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.transcriptId,
      referencedTable: $db.transcripts,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TranscriptsTableFilterComposer(
            $db: $db,
            $table: $db.transcripts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$TranscriptSegmentsTableOrderingComposer
    extends Composer<_$VaultVoiceDatabase, $TranscriptSegmentsTable> {
  $$TranscriptSegmentsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get seq => $composableBuilder(
    column: $table.seq,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get startMs => $composableBuilder(
    column: $table.startMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get endMs => $composableBuilder(
    column: $table.endMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get speaker => $composableBuilder(
    column: $table.speaker,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get body => $composableBuilder(
    column: $table.body,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get originalText => $composableBuilder(
    column: $table.originalText,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get avgLogprob => $composableBuilder(
    column: $table.avgLogprob,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get tokensJson => $composableBuilder(
    column: $table.tokensJson,
    builder: (column) => ColumnOrderings(column),
  );

  $$TranscriptsTableOrderingComposer get transcriptId {
    final $$TranscriptsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.transcriptId,
      referencedTable: $db.transcripts,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TranscriptsTableOrderingComposer(
            $db: $db,
            $table: $db.transcripts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$TranscriptSegmentsTableAnnotationComposer
    extends Composer<_$VaultVoiceDatabase, $TranscriptSegmentsTable> {
  $$TranscriptSegmentsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get seq =>
      $composableBuilder(column: $table.seq, builder: (column) => column);

  GeneratedColumn<int> get startMs =>
      $composableBuilder(column: $table.startMs, builder: (column) => column);

  GeneratedColumn<int> get endMs =>
      $composableBuilder(column: $table.endMs, builder: (column) => column);

  GeneratedColumn<String> get speaker =>
      $composableBuilder(column: $table.speaker, builder: (column) => column);

  GeneratedColumn<String> get body =>
      $composableBuilder(column: $table.body, builder: (column) => column);

  GeneratedColumn<String> get originalText => $composableBuilder(
    column: $table.originalText,
    builder: (column) => column,
  );

  GeneratedColumn<double> get avgLogprob => $composableBuilder(
    column: $table.avgLogprob,
    builder: (column) => column,
  );

  GeneratedColumn<String> get tokensJson => $composableBuilder(
    column: $table.tokensJson,
    builder: (column) => column,
  );

  $$TranscriptsTableAnnotationComposer get transcriptId {
    final $$TranscriptsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.transcriptId,
      referencedTable: $db.transcripts,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TranscriptsTableAnnotationComposer(
            $db: $db,
            $table: $db.transcripts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$TranscriptSegmentsTableTableManager
    extends
        RootTableManager<
          _$VaultVoiceDatabase,
          $TranscriptSegmentsTable,
          TranscriptSegmentRow,
          $$TranscriptSegmentsTableFilterComposer,
          $$TranscriptSegmentsTableOrderingComposer,
          $$TranscriptSegmentsTableAnnotationComposer,
          $$TranscriptSegmentsTableCreateCompanionBuilder,
          $$TranscriptSegmentsTableUpdateCompanionBuilder,
          (TranscriptSegmentRow, $$TranscriptSegmentsTableReferences),
          TranscriptSegmentRow,
          PrefetchHooks Function({bool transcriptId})
        > {
  $$TranscriptSegmentsTableTableManager(
    _$VaultVoiceDatabase db,
    $TranscriptSegmentsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TranscriptSegmentsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TranscriptSegmentsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TranscriptSegmentsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> transcriptId = const Value.absent(),
                Value<int> seq = const Value.absent(),
                Value<int> startMs = const Value.absent(),
                Value<int> endMs = const Value.absent(),
                Value<String?> speaker = const Value.absent(),
                Value<String> body = const Value.absent(),
                Value<String?> originalText = const Value.absent(),
                Value<double?> avgLogprob = const Value.absent(),
                Value<String?> tokensJson = const Value.absent(),
              }) => TranscriptSegmentsCompanion(
                id: id,
                transcriptId: transcriptId,
                seq: seq,
                startMs: startMs,
                endMs: endMs,
                speaker: speaker,
                body: body,
                originalText: originalText,
                avgLogprob: avgLogprob,
                tokensJson: tokensJson,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String transcriptId,
                required int seq,
                required int startMs,
                required int endMs,
                Value<String?> speaker = const Value.absent(),
                required String body,
                Value<String?> originalText = const Value.absent(),
                Value<double?> avgLogprob = const Value.absent(),
                Value<String?> tokensJson = const Value.absent(),
              }) => TranscriptSegmentsCompanion.insert(
                id: id,
                transcriptId: transcriptId,
                seq: seq,
                startMs: startMs,
                endMs: endMs,
                speaker: speaker,
                body: body,
                originalText: originalText,
                avgLogprob: avgLogprob,
                tokensJson: tokensJson,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$TranscriptSegmentsTable, TranscriptSegmentRow>(
                    table,
                  ),
                  $$TranscriptSegmentsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({transcriptId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (transcriptId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.transcriptId,
                        referencedTable: $$TranscriptSegmentsTableReferences
                            ._transcriptIdTable(db),
                        referencedColumn: $$TranscriptSegmentsTableReferences
                            ._transcriptIdTable(db)
                            .id,
                      ) as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$TranscriptSegmentsTableProcessedTableManager =
    ProcessedTableManager<
      _$VaultVoiceDatabase,
      $TranscriptSegmentsTable,
      TranscriptSegmentRow,
      $$TranscriptSegmentsTableFilterComposer,
      $$TranscriptSegmentsTableOrderingComposer,
      $$TranscriptSegmentsTableAnnotationComposer,
      $$TranscriptSegmentsTableCreateCompanionBuilder,
      $$TranscriptSegmentsTableUpdateCompanionBuilder,
      (TranscriptSegmentRow, $$TranscriptSegmentsTableReferences),
      TranscriptSegmentRow,
      PrefetchHooks Function({bool transcriptId})
    >;
typedef $$JobsTableCreateCompanionBuilder = JobsCompanion Function({
  required String id,
  required String recordingId,
  required String kind,
  required String step,
  required String status,
  Value<double> progress,
  Value<int> attempts,
  Value<int> priority,
  Value<String?> errorCode,
  Value<String?> errorDetail,
  Value<String?> waitingReason,
  Value<DateTime?> notBefore,
  required DateTime createdAt,
  required DateTime updatedAt,
  Value<JsonMap> checkpoint,
  Value<int> rowid,
});
typedef $$JobsTableUpdateCompanionBuilder = JobsCompanion Function({
  Value<String> id,
  Value<String> recordingId,
  Value<String> kind,
  Value<String> step,
  Value<String> status,
  Value<double> progress,
  Value<int> attempts,
  Value<int> priority,
  Value<String?> errorCode,
  Value<String?> errorDetail,
  Value<String?> waitingReason,
  Value<DateTime?> notBefore,
  Value<DateTime> createdAt,
  Value<DateTime> updatedAt,
  Value<JsonMap> checkpoint,
  Value<int> rowid,
});

final class $$JobsTableReferences
    extends BaseReferences<_$VaultVoiceDatabase, $JobsTable, JobRow> {
  $$JobsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $RecordingsTable _recordingIdTable(_$VaultVoiceDatabase db) =>
      db.recordings.createAlias('jobs__recording_id__recordings__id');

  $$RecordingsTableProcessedTableManager get recordingId {
    final $_column = $_itemColumn<String>('recording_id')!;

    final manager = $$RecordingsTableTableManager(
      $_db,
      $_db.recordings,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_recordingIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$JobsTableFilterComposer
    extends Composer<_$VaultVoiceDatabase, $JobsTable> {
  $$JobsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get step => $composableBuilder(
    column: $table.step,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get progress => $composableBuilder(
    column: $table.progress,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get attempts => $composableBuilder(
    column: $table.attempts,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get priority => $composableBuilder(
    column: $table.priority,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get errorCode => $composableBuilder(
    column: $table.errorCode,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get errorDetail => $composableBuilder(
    column: $table.errorDetail,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get waitingReason => $composableBuilder(
    column: $table.waitingReason,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<DateTime?, DateTime, int> get notBefore =>
      $composableBuilder(
        column: $table.notBefore,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnWithTypeConverterFilters<DateTime, DateTime, int> get createdAt =>
      $composableBuilder(
        column: $table.createdAt,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnWithTypeConverterFilters<DateTime, DateTime, int> get updatedAt =>
      $composableBuilder(
        column: $table.updatedAt,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnWithTypeConverterFilters<JsonMap, JsonMap, String> get checkpoint =>
      $composableBuilder(
        column: $table.checkpoint,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  $$RecordingsTableFilterComposer get recordingId {
    final $$RecordingsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.recordingId,
      referencedTable: $db.recordings,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RecordingsTableFilterComposer(
            $db: $db,
            $table: $db.recordings,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$JobsTableOrderingComposer
    extends Composer<_$VaultVoiceDatabase, $JobsTable> {
  $$JobsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get step => $composableBuilder(
    column: $table.step,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get progress => $composableBuilder(
    column: $table.progress,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get attempts => $composableBuilder(
    column: $table.attempts,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get priority => $composableBuilder(
    column: $table.priority,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get errorCode => $composableBuilder(
    column: $table.errorCode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get errorDetail => $composableBuilder(
    column: $table.errorDetail,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get waitingReason => $composableBuilder(
    column: $table.waitingReason,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get notBefore => $composableBuilder(
    column: $table.notBefore,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get checkpoint => $composableBuilder(
    column: $table.checkpoint,
    builder: (column) => ColumnOrderings(column),
  );

  $$RecordingsTableOrderingComposer get recordingId {
    final $$RecordingsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.recordingId,
      referencedTable: $db.recordings,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RecordingsTableOrderingComposer(
            $db: $db,
            $table: $db.recordings,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$JobsTableAnnotationComposer
    extends Composer<_$VaultVoiceDatabase, $JobsTable> {
  $$JobsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<String> get step =>
      $composableBuilder(column: $table.step, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<double> get progress =>
      $composableBuilder(column: $table.progress, builder: (column) => column);

  GeneratedColumn<int> get attempts =>
      $composableBuilder(column: $table.attempts, builder: (column) => column);

  GeneratedColumn<int> get priority =>
      $composableBuilder(column: $table.priority, builder: (column) => column);

  GeneratedColumn<String> get errorCode =>
      $composableBuilder(column: $table.errorCode, builder: (column) => column);

  GeneratedColumn<String> get errorDetail => $composableBuilder(
    column: $table.errorDetail,
    builder: (column) => column,
  );

  GeneratedColumn<String> get waitingReason => $composableBuilder(
    column: $table.waitingReason,
    builder: (column) => column,
  );

  GeneratedColumnWithTypeConverter<DateTime?, int> get notBefore =>
      $composableBuilder(column: $table.notBefore, builder: (column) => column);

  GeneratedColumnWithTypeConverter<DateTime, int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumnWithTypeConverter<DateTime, int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumnWithTypeConverter<JsonMap, String> get checkpoint =>
      $composableBuilder(
        column: $table.checkpoint,
        builder: (column) => column,
      );

  $$RecordingsTableAnnotationComposer get recordingId {
    final $$RecordingsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.recordingId,
      referencedTable: $db.recordings,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RecordingsTableAnnotationComposer(
            $db: $db,
            $table: $db.recordings,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$JobsTableTableManager
    extends
        RootTableManager<
          _$VaultVoiceDatabase,
          $JobsTable,
          JobRow,
          $$JobsTableFilterComposer,
          $$JobsTableOrderingComposer,
          $$JobsTableAnnotationComposer,
          $$JobsTableCreateCompanionBuilder,
          $$JobsTableUpdateCompanionBuilder,
          (JobRow, $$JobsTableReferences),
          JobRow,
          PrefetchHooks Function({bool recordingId})
        > {
  $$JobsTableTableManager(_$VaultVoiceDatabase db, $JobsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$JobsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$JobsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$JobsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> recordingId = const Value.absent(),
                Value<String> kind = const Value.absent(),
                Value<String> step = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<double> progress = const Value.absent(),
                Value<int> attempts = const Value.absent(),
                Value<int> priority = const Value.absent(),
                Value<String?> errorCode = const Value.absent(),
                Value<String?> errorDetail = const Value.absent(),
                Value<String?> waitingReason = const Value.absent(),
                Value<DateTime?> notBefore = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<JsonMap> checkpoint = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => JobsCompanion(
                id: id,
                recordingId: recordingId,
                kind: kind,
                step: step,
                status: status,
                progress: progress,
                attempts: attempts,
                priority: priority,
                errorCode: errorCode,
                errorDetail: errorDetail,
                waitingReason: waitingReason,
                notBefore: notBefore,
                createdAt: createdAt,
                updatedAt: updatedAt,
                checkpoint: checkpoint,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String recordingId,
                required String kind,
                required String step,
                required String status,
                Value<double> progress = const Value.absent(),
                Value<int> attempts = const Value.absent(),
                Value<int> priority = const Value.absent(),
                Value<String?> errorCode = const Value.absent(),
                Value<String?> errorDetail = const Value.absent(),
                Value<String?> waitingReason = const Value.absent(),
                Value<DateTime?> notBefore = const Value.absent(),
                required DateTime createdAt,
                required DateTime updatedAt,
                Value<JsonMap> checkpoint = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => JobsCompanion.insert(
                id: id,
                recordingId: recordingId,
                kind: kind,
                step: step,
                status: status,
                progress: progress,
                attempts: attempts,
                priority: priority,
                errorCode: errorCode,
                errorDetail: errorDetail,
                waitingReason: waitingReason,
                notBefore: notBefore,
                createdAt: createdAt,
                updatedAt: updatedAt,
                checkpoint: checkpoint,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$JobsTable, JobRow>(table),
                  $$JobsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({recordingId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (recordingId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.recordingId,
                        referencedTable: $$JobsTableReferences
                            ._recordingIdTable(db),
                        referencedColumn: $$JobsTableReferences
                            ._recordingIdTable(db)
                            .id,
                      ) as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$JobsTableProcessedTableManager =
    ProcessedTableManager<
      _$VaultVoiceDatabase,
      $JobsTable,
      JobRow,
      $$JobsTableFilterComposer,
      $$JobsTableOrderingComposer,
      $$JobsTableAnnotationComposer,
      $$JobsTableCreateCompanionBuilder,
      $$JobsTableUpdateCompanionBuilder,
      (JobRow, $$JobsTableReferences),
      JobRow,
      PrefetchHooks Function({bool recordingId})
    >;
typedef $$ProfilesTableCreateCompanionBuilder = ProfilesCompanion Function({
  required String id,
  required int version,
  required ProfileSource source,
  required JsonMap definition,
  required DateTime updatedAt,
  Value<int> rowid,
});
typedef $$ProfilesTableUpdateCompanionBuilder = ProfilesCompanion Function({
  Value<String> id,
  Value<int> version,
  Value<ProfileSource> source,
  Value<JsonMap> definition,
  Value<DateTime> updatedAt,
  Value<int> rowid,
});

final class $$ProfilesTableReferences
    extends BaseReferences<_$VaultVoiceDatabase, $ProfilesTable, ProfileRow> {
  $$ProfilesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$TemplatesTable, List<TemplateRow>>
  _templatesRefsTable(_$VaultVoiceDatabase db) => MultiTypedResultKey.fromTable(
    db.templates,
    aliasName: 'profiles__id__templates__profile_id',
  );

  $$TemplatesTableProcessedTableManager get templatesRefs {
    final manager = $$TemplatesTableTableManager(
      $_db,
      $_db.templates,
    ).filter((f) => f.profileId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_templatesRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$ProfilesTableFilterComposer
    extends Composer<_$VaultVoiceDatabase, $ProfilesTable> {
  $$ProfilesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<ProfileSource, ProfileSource, String>
  get source => $composableBuilder(
    column: $table.source,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnWithTypeConverterFilters<JsonMap, JsonMap, String> get definition =>
      $composableBuilder(
        column: $table.definition,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnWithTypeConverterFilters<DateTime, DateTime, int> get updatedAt =>
      $composableBuilder(
        column: $table.updatedAt,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  Expression<bool> templatesRefs(
    Expression<bool> Function($$TemplatesTableFilterComposer f) f,
  ) {
    final $$TemplatesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.templates,
      getReferencedColumn: (t) => t.profileId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TemplatesTableFilterComposer(
            $db: $db,
            $table: $db.templates,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$ProfilesTableOrderingComposer
    extends Composer<_$VaultVoiceDatabase, $ProfilesTable> {
  $$ProfilesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get source => $composableBuilder(
    column: $table.source,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get definition => $composableBuilder(
    column: $table.definition,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ProfilesTableAnnotationComposer
    extends Composer<_$VaultVoiceDatabase, $ProfilesTable> {
  $$ProfilesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get version =>
      $composableBuilder(column: $table.version, builder: (column) => column);

  GeneratedColumnWithTypeConverter<ProfileSource, String> get source =>
      $composableBuilder(column: $table.source, builder: (column) => column);

  GeneratedColumnWithTypeConverter<JsonMap, String> get definition =>
      $composableBuilder(
        column: $table.definition,
        builder: (column) => column,
      );

  GeneratedColumnWithTypeConverter<DateTime, int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  Expression<T> templatesRefs<T extends Object>(
    Expression<T> Function($$TemplatesTableAnnotationComposer a) f,
  ) {
    final $$TemplatesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.templates,
      getReferencedColumn: (t) => t.profileId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TemplatesTableAnnotationComposer(
            $db: $db,
            $table: $db.templates,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$ProfilesTableTableManager
    extends
        RootTableManager<
          _$VaultVoiceDatabase,
          $ProfilesTable,
          ProfileRow,
          $$ProfilesTableFilterComposer,
          $$ProfilesTableOrderingComposer,
          $$ProfilesTableAnnotationComposer,
          $$ProfilesTableCreateCompanionBuilder,
          $$ProfilesTableUpdateCompanionBuilder,
          (ProfileRow, $$ProfilesTableReferences),
          ProfileRow,
          PrefetchHooks Function({bool templatesRefs})
        > {
  $$ProfilesTableTableManager(_$VaultVoiceDatabase db, $ProfilesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ProfilesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ProfilesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ProfilesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<int> version = const Value.absent(),
                Value<ProfileSource> source = const Value.absent(),
                Value<JsonMap> definition = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ProfilesCompanion(
                id: id,
                version: version,
                source: source,
                definition: definition,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required int version,
                required ProfileSource source,
                required JsonMap definition,
                required DateTime updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => ProfilesCompanion.insert(
                id: id,
                version: version,
                source: source,
                definition: definition,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$ProfilesTable, ProfileRow>(table),
                  $$ProfilesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({templatesRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [if (templatesRefs) db.templates],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (templatesRefs)
                    await $_getPrefetchedData<
                      ProfileRow,
                      $ProfilesTable,
                      TemplateRow
                    >(
                      currentTable: table,
                      referencedTable: $$ProfilesTableReferences
                          ._templatesRefsTable(db),
                      managerFromTypedResult: (p0) => $$ProfilesTableReferences(
                        db,
                        table,
                        p0,
                      ).templatesRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where((e) => e.profileId == item.id),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$ProfilesTableProcessedTableManager =
    ProcessedTableManager<
      _$VaultVoiceDatabase,
      $ProfilesTable,
      ProfileRow,
      $$ProfilesTableFilterComposer,
      $$ProfilesTableOrderingComposer,
      $$ProfilesTableAnnotationComposer,
      $$ProfilesTableCreateCompanionBuilder,
      $$ProfilesTableUpdateCompanionBuilder,
      (ProfileRow, $$ProfilesTableReferences),
      ProfileRow,
      PrefetchHooks Function({bool templatesRefs})
    >;
typedef $$TemplatesTableCreateCompanionBuilder = TemplatesCompanion Function({
  required String id,
  Value<String?> profileId,
  required String body,
  required String filenamePattern,
  required DateTime updatedAt,
  Value<int> rowid,
});
typedef $$TemplatesTableUpdateCompanionBuilder = TemplatesCompanion Function({
  Value<String> id,
  Value<String?> profileId,
  Value<String> body,
  Value<String> filenamePattern,
  Value<DateTime> updatedAt,
  Value<int> rowid,
});

final class $$TemplatesTableReferences
    extends BaseReferences<_$VaultVoiceDatabase, $TemplatesTable, TemplateRow> {
  $$TemplatesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $ProfilesTable _profileIdTable(_$VaultVoiceDatabase db) =>
      db.profiles.createAlias('templates__profile_id__profiles__id');

  $$ProfilesTableProcessedTableManager? get profileId {
    final $_column = $_itemColumn<String>('profile_id');
    if ($_column == null) return null;
    final manager = $$ProfilesTableTableManager(
      $_db,
      $_db.profiles,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_profileIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$TemplatesTableFilterComposer
    extends Composer<_$VaultVoiceDatabase, $TemplatesTable> {
  $$TemplatesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get body => $composableBuilder(
    column: $table.body,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get filenamePattern => $composableBuilder(
    column: $table.filenamePattern,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<DateTime, DateTime, int> get updatedAt =>
      $composableBuilder(
        column: $table.updatedAt,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  $$ProfilesTableFilterComposer get profileId {
    final $$ProfilesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.profileId,
      referencedTable: $db.profiles,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProfilesTableFilterComposer(
            $db: $db,
            $table: $db.profiles,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$TemplatesTableOrderingComposer
    extends Composer<_$VaultVoiceDatabase, $TemplatesTable> {
  $$TemplatesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get body => $composableBuilder(
    column: $table.body,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get filenamePattern => $composableBuilder(
    column: $table.filenamePattern,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$ProfilesTableOrderingComposer get profileId {
    final $$ProfilesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.profileId,
      referencedTable: $db.profiles,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProfilesTableOrderingComposer(
            $db: $db,
            $table: $db.profiles,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$TemplatesTableAnnotationComposer
    extends Composer<_$VaultVoiceDatabase, $TemplatesTable> {
  $$TemplatesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get body =>
      $composableBuilder(column: $table.body, builder: (column) => column);

  GeneratedColumn<String> get filenamePattern => $composableBuilder(
    column: $table.filenamePattern,
    builder: (column) => column,
  );

  GeneratedColumnWithTypeConverter<DateTime, int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  $$ProfilesTableAnnotationComposer get profileId {
    final $$ProfilesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.profileId,
      referencedTable: $db.profiles,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProfilesTableAnnotationComposer(
            $db: $db,
            $table: $db.profiles,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$TemplatesTableTableManager
    extends
        RootTableManager<
          _$VaultVoiceDatabase,
          $TemplatesTable,
          TemplateRow,
          $$TemplatesTableFilterComposer,
          $$TemplatesTableOrderingComposer,
          $$TemplatesTableAnnotationComposer,
          $$TemplatesTableCreateCompanionBuilder,
          $$TemplatesTableUpdateCompanionBuilder,
          (TemplateRow, $$TemplatesTableReferences),
          TemplateRow,
          PrefetchHooks Function({bool profileId})
        > {
  $$TemplatesTableTableManager(_$VaultVoiceDatabase db, $TemplatesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TemplatesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TemplatesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TemplatesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String?> profileId = const Value.absent(),
                Value<String> body = const Value.absent(),
                Value<String> filenamePattern = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => TemplatesCompanion(
                id: id,
                profileId: profileId,
                body: body,
                filenamePattern: filenamePattern,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                Value<String?> profileId = const Value.absent(),
                required String body,
                required String filenamePattern,
                required DateTime updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => TemplatesCompanion.insert(
                id: id,
                profileId: profileId,
                body: body,
                filenamePattern: filenamePattern,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$TemplatesTable, TemplateRow>(table),
                  $$TemplatesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({profileId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (profileId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.profileId,
                        referencedTable: $$TemplatesTableReferences
                            ._profileIdTable(db),
                        referencedColumn: $$TemplatesTableReferences
                            ._profileIdTable(db)
                            .id,
                      ) as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$TemplatesTableProcessedTableManager =
    ProcessedTableManager<
      _$VaultVoiceDatabase,
      $TemplatesTable,
      TemplateRow,
      $$TemplatesTableFilterComposer,
      $$TemplatesTableOrderingComposer,
      $$TemplatesTableAnnotationComposer,
      $$TemplatesTableCreateCompanionBuilder,
      $$TemplatesTableUpdateCompanionBuilder,
      (TemplateRow, $$TemplatesTableReferences),
      TemplateRow,
      PrefetchHooks Function({bool profileId})
    >;
typedef $$ExtractionsTableCreateCompanionBuilder =
    ExtractionsCompanion Function({
      required String id,
      required String recordingId,
      required String profileId,
      required int profileVersion,
      required String modelId,
      required JsonMap json,
      required bool valid,
      required DateTime createdAt,
      Value<int> rowid,
    });
typedef $$ExtractionsTableUpdateCompanionBuilder =
    ExtractionsCompanion Function({
      Value<String> id,
      Value<String> recordingId,
      Value<String> profileId,
      Value<int> profileVersion,
      Value<String> modelId,
      Value<JsonMap> json,
      Value<bool> valid,
      Value<DateTime> createdAt,
      Value<int> rowid,
    });

final class $$ExtractionsTableReferences
    extends
        BaseReferences<_$VaultVoiceDatabase, $ExtractionsTable, ExtractionRow> {
  $$ExtractionsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $RecordingsTable _recordingIdTable(_$VaultVoiceDatabase db) =>
      db.recordings.createAlias('extractions__recording_id__recordings__id');

  $$RecordingsTableProcessedTableManager get recordingId {
    final $_column = $_itemColumn<String>('recording_id')!;

    final manager = $$RecordingsTableTableManager(
      $_db,
      $_db.recordings,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_recordingIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<$ActionItemsTable, List<ActionItemRow>>
  _actionItemsRefsTable(_$VaultVoiceDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.actionItems,
        aliasName: 'extractions__id__action_items__extraction_id',
      );

  $$ActionItemsTableProcessedTableManager get actionItemsRefs {
    final manager = $$ActionItemsTableTableManager(
      $_db,
      $_db.actionItems,
    ).filter((f) => f.extractionId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_actionItemsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$ExtractionsTableFilterComposer
    extends Composer<_$VaultVoiceDatabase, $ExtractionsTable> {
  $$ExtractionsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get profileId => $composableBuilder(
    column: $table.profileId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get profileVersion => $composableBuilder(
    column: $table.profileVersion,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get modelId => $composableBuilder(
    column: $table.modelId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<JsonMap, JsonMap, String> get json =>
      $composableBuilder(
        column: $table.json,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnFilters<bool> get valid => $composableBuilder(
    column: $table.valid,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<DateTime, DateTime, int> get createdAt =>
      $composableBuilder(
        column: $table.createdAt,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  $$RecordingsTableFilterComposer get recordingId {
    final $$RecordingsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.recordingId,
      referencedTable: $db.recordings,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RecordingsTableFilterComposer(
            $db: $db,
            $table: $db.recordings,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> actionItemsRefs(
    Expression<bool> Function($$ActionItemsTableFilterComposer f) f,
  ) {
    final $$ActionItemsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.actionItems,
      getReferencedColumn: (t) => t.extractionId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ActionItemsTableFilterComposer(
            $db: $db,
            $table: $db.actionItems,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$ExtractionsTableOrderingComposer
    extends Composer<_$VaultVoiceDatabase, $ExtractionsTable> {
  $$ExtractionsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get profileId => $composableBuilder(
    column: $table.profileId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get profileVersion => $composableBuilder(
    column: $table.profileVersion,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get modelId => $composableBuilder(
    column: $table.modelId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get json => $composableBuilder(
    column: $table.json,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get valid => $composableBuilder(
    column: $table.valid,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$RecordingsTableOrderingComposer get recordingId {
    final $$RecordingsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.recordingId,
      referencedTable: $db.recordings,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RecordingsTableOrderingComposer(
            $db: $db,
            $table: $db.recordings,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ExtractionsTableAnnotationComposer
    extends Composer<_$VaultVoiceDatabase, $ExtractionsTable> {
  $$ExtractionsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get profileId =>
      $composableBuilder(column: $table.profileId, builder: (column) => column);

  GeneratedColumn<int> get profileVersion => $composableBuilder(
    column: $table.profileVersion,
    builder: (column) => column,
  );

  GeneratedColumn<String> get modelId =>
      $composableBuilder(column: $table.modelId, builder: (column) => column);

  GeneratedColumnWithTypeConverter<JsonMap, String> get json =>
      $composableBuilder(column: $table.json, builder: (column) => column);

  GeneratedColumn<bool> get valid =>
      $composableBuilder(column: $table.valid, builder: (column) => column);

  GeneratedColumnWithTypeConverter<DateTime, int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  $$RecordingsTableAnnotationComposer get recordingId {
    final $$RecordingsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.recordingId,
      referencedTable: $db.recordings,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RecordingsTableAnnotationComposer(
            $db: $db,
            $table: $db.recordings,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> actionItemsRefs<T extends Object>(
    Expression<T> Function($$ActionItemsTableAnnotationComposer a) f,
  ) {
    final $$ActionItemsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.actionItems,
      getReferencedColumn: (t) => t.extractionId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ActionItemsTableAnnotationComposer(
            $db: $db,
            $table: $db.actionItems,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$ExtractionsTableTableManager
    extends
        RootTableManager<
          _$VaultVoiceDatabase,
          $ExtractionsTable,
          ExtractionRow,
          $$ExtractionsTableFilterComposer,
          $$ExtractionsTableOrderingComposer,
          $$ExtractionsTableAnnotationComposer,
          $$ExtractionsTableCreateCompanionBuilder,
          $$ExtractionsTableUpdateCompanionBuilder,
          (ExtractionRow, $$ExtractionsTableReferences),
          ExtractionRow,
          PrefetchHooks Function({bool recordingId, bool actionItemsRefs})
        > {
  $$ExtractionsTableTableManager(
    _$VaultVoiceDatabase db,
    $ExtractionsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ExtractionsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ExtractionsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ExtractionsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> recordingId = const Value.absent(),
                Value<String> profileId = const Value.absent(),
                Value<int> profileVersion = const Value.absent(),
                Value<String> modelId = const Value.absent(),
                Value<JsonMap> json = const Value.absent(),
                Value<bool> valid = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ExtractionsCompanion(
                id: id,
                recordingId: recordingId,
                profileId: profileId,
                profileVersion: profileVersion,
                modelId: modelId,
                json: json,
                valid: valid,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String recordingId,
                required String profileId,
                required int profileVersion,
                required String modelId,
                required JsonMap json,
                required bool valid,
                required DateTime createdAt,
                Value<int> rowid = const Value.absent(),
              }) => ExtractionsCompanion.insert(
                id: id,
                recordingId: recordingId,
                profileId: profileId,
                profileVersion: profileVersion,
                modelId: modelId,
                json: json,
                valid: valid,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$ExtractionsTable, ExtractionRow>(table),
                  $$ExtractionsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({recordingId = false, actionItemsRefs = false}) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (actionItemsRefs) db.actionItems,
                  ],
                  addJoins:
                      <
                        T extends TableManagerState<
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic
                        >
                      >(state) {
                        if (recordingId) {
                          state = state.withJoin(
                            currentTable: table,
                            currentColumn: table.recordingId,
                            referencedTable: $$ExtractionsTableReferences
                                ._recordingIdTable(db),
                            referencedColumn: $$ExtractionsTableReferences
                                ._recordingIdTable(db)
                                .id,
                          ) as T;
                        }

                        return state;
                      },
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (actionItemsRefs)
                        await $_getPrefetchedData<
                          ExtractionRow,
                          $ExtractionsTable,
                          ActionItemRow
                        >(
                          currentTable: table,
                          referencedTable: $$ExtractionsTableReferences
                              ._actionItemsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$ExtractionsTableReferences(
                                db,
                                table,
                                p0,
                              ).actionItemsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.extractionId == item.id,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$ExtractionsTableProcessedTableManager =
    ProcessedTableManager<
      _$VaultVoiceDatabase,
      $ExtractionsTable,
      ExtractionRow,
      $$ExtractionsTableFilterComposer,
      $$ExtractionsTableOrderingComposer,
      $$ExtractionsTableAnnotationComposer,
      $$ExtractionsTableCreateCompanionBuilder,
      $$ExtractionsTableUpdateCompanionBuilder,
      (ExtractionRow, $$ExtractionsTableReferences),
      ExtractionRow,
      PrefetchHooks Function({bool recordingId, bool actionItemsRefs})
    >;
typedef $$ActionItemsTableCreateCompanionBuilder =
    ActionItemsCompanion Function({
      Value<int> id,
      required String recordingId,
      required String extractionId,
      required String body,
      Value<String?> owner,
      Value<String?> dueIso,
      Value<int?> tMs,
      Value<bool> done,
      Value<DateTime?> doneAt,
    });
typedef $$ActionItemsTableUpdateCompanionBuilder =
    ActionItemsCompanion Function({
      Value<int> id,
      Value<String> recordingId,
      Value<String> extractionId,
      Value<String> body,
      Value<String?> owner,
      Value<String?> dueIso,
      Value<int?> tMs,
      Value<bool> done,
      Value<DateTime?> doneAt,
    });

final class $$ActionItemsTableReferences
    extends
        BaseReferences<_$VaultVoiceDatabase, $ActionItemsTable, ActionItemRow> {
  $$ActionItemsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $RecordingsTable _recordingIdTable(_$VaultVoiceDatabase db) =>
      db.recordings.createAlias('action_items__recording_id__recordings__id');

  $$RecordingsTableProcessedTableManager get recordingId {
    final $_column = $_itemColumn<String>('recording_id')!;

    final manager = $$RecordingsTableTableManager(
      $_db,
      $_db.recordings,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_recordingIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $ExtractionsTable _extractionIdTable(_$VaultVoiceDatabase db) => db
      .extractions
      .createAlias('action_items__extraction_id__extractions__id');

  $$ExtractionsTableProcessedTableManager get extractionId {
    final $_column = $_itemColumn<String>('extraction_id')!;

    final manager = $$ExtractionsTableTableManager(
      $_db,
      $_db.extractions,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_extractionIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$ActionItemsTableFilterComposer
    extends Composer<_$VaultVoiceDatabase, $ActionItemsTable> {
  $$ActionItemsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get body => $composableBuilder(
    column: $table.body,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get owner => $composableBuilder(
    column: $table.owner,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get dueIso => $composableBuilder(
    column: $table.dueIso,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get tMs => $composableBuilder(
    column: $table.tMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get done => $composableBuilder(
    column: $table.done,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<DateTime?, DateTime, int> get doneAt =>
      $composableBuilder(
        column: $table.doneAt,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  $$RecordingsTableFilterComposer get recordingId {
    final $$RecordingsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.recordingId,
      referencedTable: $db.recordings,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RecordingsTableFilterComposer(
            $db: $db,
            $table: $db.recordings,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$ExtractionsTableFilterComposer get extractionId {
    final $$ExtractionsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.extractionId,
      referencedTable: $db.extractions,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ExtractionsTableFilterComposer(
            $db: $db,
            $table: $db.extractions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ActionItemsTableOrderingComposer
    extends Composer<_$VaultVoiceDatabase, $ActionItemsTable> {
  $$ActionItemsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get body => $composableBuilder(
    column: $table.body,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get owner => $composableBuilder(
    column: $table.owner,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get dueIso => $composableBuilder(
    column: $table.dueIso,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get tMs => $composableBuilder(
    column: $table.tMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get done => $composableBuilder(
    column: $table.done,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get doneAt => $composableBuilder(
    column: $table.doneAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$RecordingsTableOrderingComposer get recordingId {
    final $$RecordingsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.recordingId,
      referencedTable: $db.recordings,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RecordingsTableOrderingComposer(
            $db: $db,
            $table: $db.recordings,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$ExtractionsTableOrderingComposer get extractionId {
    final $$ExtractionsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.extractionId,
      referencedTable: $db.extractions,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ExtractionsTableOrderingComposer(
            $db: $db,
            $table: $db.extractions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ActionItemsTableAnnotationComposer
    extends Composer<_$VaultVoiceDatabase, $ActionItemsTable> {
  $$ActionItemsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get body =>
      $composableBuilder(column: $table.body, builder: (column) => column);

  GeneratedColumn<String> get owner =>
      $composableBuilder(column: $table.owner, builder: (column) => column);

  GeneratedColumn<String> get dueIso =>
      $composableBuilder(column: $table.dueIso, builder: (column) => column);

  GeneratedColumn<int> get tMs =>
      $composableBuilder(column: $table.tMs, builder: (column) => column);

  GeneratedColumn<bool> get done =>
      $composableBuilder(column: $table.done, builder: (column) => column);

  GeneratedColumnWithTypeConverter<DateTime?, int> get doneAt =>
      $composableBuilder(column: $table.doneAt, builder: (column) => column);

  $$RecordingsTableAnnotationComposer get recordingId {
    final $$RecordingsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.recordingId,
      referencedTable: $db.recordings,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RecordingsTableAnnotationComposer(
            $db: $db,
            $table: $db.recordings,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$ExtractionsTableAnnotationComposer get extractionId {
    final $$ExtractionsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.extractionId,
      referencedTable: $db.extractions,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ExtractionsTableAnnotationComposer(
            $db: $db,
            $table: $db.extractions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ActionItemsTableTableManager
    extends
        RootTableManager<
          _$VaultVoiceDatabase,
          $ActionItemsTable,
          ActionItemRow,
          $$ActionItemsTableFilterComposer,
          $$ActionItemsTableOrderingComposer,
          $$ActionItemsTableAnnotationComposer,
          $$ActionItemsTableCreateCompanionBuilder,
          $$ActionItemsTableUpdateCompanionBuilder,
          (ActionItemRow, $$ActionItemsTableReferences),
          ActionItemRow,
          PrefetchHooks Function({bool recordingId, bool extractionId})
        > {
  $$ActionItemsTableTableManager(
    _$VaultVoiceDatabase db,
    $ActionItemsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ActionItemsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ActionItemsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ActionItemsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> recordingId = const Value.absent(),
                Value<String> extractionId = const Value.absent(),
                Value<String> body = const Value.absent(),
                Value<String?> owner = const Value.absent(),
                Value<String?> dueIso = const Value.absent(),
                Value<int?> tMs = const Value.absent(),
                Value<bool> done = const Value.absent(),
                Value<DateTime?> doneAt = const Value.absent(),
              }) => ActionItemsCompanion(
                id: id,
                recordingId: recordingId,
                extractionId: extractionId,
                body: body,
                owner: owner,
                dueIso: dueIso,
                tMs: tMs,
                done: done,
                doneAt: doneAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String recordingId,
                required String extractionId,
                required String body,
                Value<String?> owner = const Value.absent(),
                Value<String?> dueIso = const Value.absent(),
                Value<int?> tMs = const Value.absent(),
                Value<bool> done = const Value.absent(),
                Value<DateTime?> doneAt = const Value.absent(),
              }) => ActionItemsCompanion.insert(
                id: id,
                recordingId: recordingId,
                extractionId: extractionId,
                body: body,
                owner: owner,
                dueIso: dueIso,
                tMs: tMs,
                done: done,
                doneAt: doneAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$ActionItemsTable, ActionItemRow>(table),
                  $$ActionItemsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({recordingId = false, extractionId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (recordingId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.recordingId,
                        referencedTable: $$ActionItemsTableReferences
                            ._recordingIdTable(db),
                        referencedColumn: $$ActionItemsTableReferences
                            ._recordingIdTable(db)
                            .id,
                      ) as T;
                    }
                    if (extractionId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.extractionId,
                        referencedTable: $$ActionItemsTableReferences
                            ._extractionIdTable(db),
                        referencedColumn: $$ActionItemsTableReferences
                            ._extractionIdTable(db)
                            .id,
                      ) as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$ActionItemsTableProcessedTableManager =
    ProcessedTableManager<
      _$VaultVoiceDatabase,
      $ActionItemsTable,
      ActionItemRow,
      $$ActionItemsTableFilterComposer,
      $$ActionItemsTableOrderingComposer,
      $$ActionItemsTableAnnotationComposer,
      $$ActionItemsTableCreateCompanionBuilder,
      $$ActionItemsTableUpdateCompanionBuilder,
      (ActionItemRow, $$ActionItemsTableReferences),
      ActionItemRow,
      PrefetchHooks Function({bool recordingId, bool extractionId})
    >;
typedef $$VaultTargetsTableCreateCompanionBuilder =
    VaultTargetsCompanion Function({
      required String id,
      required VaultPlatform platform,
      required String displayName,
      required String handle,
      required DateTime createdAt,
      Value<int> rowid,
    });
typedef $$VaultTargetsTableUpdateCompanionBuilder =
    VaultTargetsCompanion Function({
      Value<String> id,
      Value<VaultPlatform> platform,
      Value<String> displayName,
      Value<String> handle,
      Value<DateTime> createdAt,
      Value<int> rowid,
    });

final class $$VaultTargetsTableReferences
    extends
        BaseReferences<
          _$VaultVoiceDatabase,
          $VaultTargetsTable,
          VaultTargetRow
        > {
  $$VaultTargetsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$RoutingRulesTable, List<RoutingRuleRow>>
  _routingRulesRefsTable(_$VaultVoiceDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.routingRules,
        aliasName: 'vault_targets__id__routing_rules__target_id',
      );

  $$RoutingRulesTableProcessedTableManager get routingRulesRefs {
    final manager = $$RoutingRulesTableTableManager(
      $_db,
      $_db.routingRules,
    ).filter((f) => f.targetId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_routingRulesRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$ExportsTable, List<ExportRow>> _exportsRefsTable(
    _$VaultVoiceDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.exports,
    aliasName: 'vault_targets__id__exports__target_id',
  );

  $$ExportsTableProcessedTableManager get exportsRefs {
    final manager = $$ExportsTableTableManager(
      $_db,
      $_db.exports,
    ).filter((f) => f.targetId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_exportsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$VaultTargetsTableFilterComposer
    extends Composer<_$VaultVoiceDatabase, $VaultTargetsTable> {
  $$VaultTargetsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<VaultPlatform, VaultPlatform, String>
  get platform => $composableBuilder(
    column: $table.platform,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnFilters<String> get displayName => $composableBuilder(
    column: $table.displayName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get handle => $composableBuilder(
    column: $table.handle,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<DateTime, DateTime, int> get createdAt =>
      $composableBuilder(
        column: $table.createdAt,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  Expression<bool> routingRulesRefs(
    Expression<bool> Function($$RoutingRulesTableFilterComposer f) f,
  ) {
    final $$RoutingRulesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.routingRules,
      getReferencedColumn: (t) => t.targetId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RoutingRulesTableFilterComposer(
            $db: $db,
            $table: $db.routingRules,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> exportsRefs(
    Expression<bool> Function($$ExportsTableFilterComposer f) f,
  ) {
    final $$ExportsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.exports,
      getReferencedColumn: (t) => t.targetId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ExportsTableFilterComposer(
            $db: $db,
            $table: $db.exports,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$VaultTargetsTableOrderingComposer
    extends Composer<_$VaultVoiceDatabase, $VaultTargetsTable> {
  $$VaultTargetsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get platform => $composableBuilder(
    column: $table.platform,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get displayName => $composableBuilder(
    column: $table.displayName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get handle => $composableBuilder(
    column: $table.handle,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$VaultTargetsTableAnnotationComposer
    extends Composer<_$VaultVoiceDatabase, $VaultTargetsTable> {
  $$VaultTargetsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumnWithTypeConverter<VaultPlatform, String> get platform =>
      $composableBuilder(column: $table.platform, builder: (column) => column);

  GeneratedColumn<String> get displayName => $composableBuilder(
    column: $table.displayName,
    builder: (column) => column,
  );

  GeneratedColumn<String> get handle =>
      $composableBuilder(column: $table.handle, builder: (column) => column);

  GeneratedColumnWithTypeConverter<DateTime, int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  Expression<T> routingRulesRefs<T extends Object>(
    Expression<T> Function($$RoutingRulesTableAnnotationComposer a) f,
  ) {
    final $$RoutingRulesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.routingRules,
      getReferencedColumn: (t) => t.targetId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RoutingRulesTableAnnotationComposer(
            $db: $db,
            $table: $db.routingRules,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> exportsRefs<T extends Object>(
    Expression<T> Function($$ExportsTableAnnotationComposer a) f,
  ) {
    final $$ExportsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.exports,
      getReferencedColumn: (t) => t.targetId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ExportsTableAnnotationComposer(
            $db: $db,
            $table: $db.exports,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$VaultTargetsTableTableManager
    extends
        RootTableManager<
          _$VaultVoiceDatabase,
          $VaultTargetsTable,
          VaultTargetRow,
          $$VaultTargetsTableFilterComposer,
          $$VaultTargetsTableOrderingComposer,
          $$VaultTargetsTableAnnotationComposer,
          $$VaultTargetsTableCreateCompanionBuilder,
          $$VaultTargetsTableUpdateCompanionBuilder,
          (VaultTargetRow, $$VaultTargetsTableReferences),
          VaultTargetRow,
          PrefetchHooks Function({bool routingRulesRefs, bool exportsRefs})
        > {
  $$VaultTargetsTableTableManager(
    _$VaultVoiceDatabase db,
    $VaultTargetsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$VaultTargetsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$VaultTargetsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$VaultTargetsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<VaultPlatform> platform = const Value.absent(),
                Value<String> displayName = const Value.absent(),
                Value<String> handle = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => VaultTargetsCompanion(
                id: id,
                platform: platform,
                displayName: displayName,
                handle: handle,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required VaultPlatform platform,
                required String displayName,
                required String handle,
                required DateTime createdAt,
                Value<int> rowid = const Value.absent(),
              }) => VaultTargetsCompanion.insert(
                id: id,
                platform: platform,
                displayName: displayName,
                handle: handle,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$VaultTargetsTable, VaultTargetRow>(table),
                  $$VaultTargetsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({routingRulesRefs = false, exportsRefs = false}) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (routingRulesRefs) db.routingRules,
                    if (exportsRefs) db.exports,
                  ],
                  addJoins: null,
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (routingRulesRefs)
                        await $_getPrefetchedData<
                          VaultTargetRow,
                          $VaultTargetsTable,
                          RoutingRuleRow
                        >(
                          currentTable: table,
                          referencedTable: $$VaultTargetsTableReferences
                              ._routingRulesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$VaultTargetsTableReferences(
                                db,
                                table,
                                p0,
                              ).routingRulesRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.targetId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (exportsRefs)
                        await $_getPrefetchedData<
                          VaultTargetRow,
                          $VaultTargetsTable,
                          ExportRow
                        >(
                          currentTable: table,
                          referencedTable: $$VaultTargetsTableReferences
                              ._exportsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$VaultTargetsTableReferences(
                                db,
                                table,
                                p0,
                              ).exportsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.targetId == item.id,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$VaultTargetsTableProcessedTableManager =
    ProcessedTableManager<
      _$VaultVoiceDatabase,
      $VaultTargetsTable,
      VaultTargetRow,
      $$VaultTargetsTableFilterComposer,
      $$VaultTargetsTableOrderingComposer,
      $$VaultTargetsTableAnnotationComposer,
      $$VaultTargetsTableCreateCompanionBuilder,
      $$VaultTargetsTableUpdateCompanionBuilder,
      (VaultTargetRow, $$VaultTargetsTableReferences),
      VaultTargetRow,
      PrefetchHooks Function({bool routingRulesRefs, bool exportsRefs})
    >;
typedef $$RoutingRulesTableCreateCompanionBuilder =
    RoutingRulesCompanion Function({
      required String id,
      required int priority,
      required JsonMap match,
      required String targetId,
      Value<String> subPath,
      Value<String?> filenamePattern,
      Value<int> rowid,
    });
typedef $$RoutingRulesTableUpdateCompanionBuilder =
    RoutingRulesCompanion Function({
      Value<String> id,
      Value<int> priority,
      Value<JsonMap> match,
      Value<String> targetId,
      Value<String> subPath,
      Value<String?> filenamePattern,
      Value<int> rowid,
    });

final class $$RoutingRulesTableReferences
    extends
        BaseReferences<
          _$VaultVoiceDatabase,
          $RoutingRulesTable,
          RoutingRuleRow
        > {
  $$RoutingRulesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $VaultTargetsTable _targetIdTable(_$VaultVoiceDatabase db) => db
      .vaultTargets
      .createAlias('routing_rules__target_id__vault_targets__id');

  $$VaultTargetsTableProcessedTableManager get targetId {
    final $_column = $_itemColumn<String>('target_id')!;

    final manager = $$VaultTargetsTableTableManager(
      $_db,
      $_db.vaultTargets,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_targetIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$RoutingRulesTableFilterComposer
    extends Composer<_$VaultVoiceDatabase, $RoutingRulesTable> {
  $$RoutingRulesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get priority => $composableBuilder(
    column: $table.priority,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<JsonMap, JsonMap, String> get match =>
      $composableBuilder(
        column: $table.match,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnFilters<String> get subPath => $composableBuilder(
    column: $table.subPath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get filenamePattern => $composableBuilder(
    column: $table.filenamePattern,
    builder: (column) => ColumnFilters(column),
  );

  $$VaultTargetsTableFilterComposer get targetId {
    final $$VaultTargetsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.targetId,
      referencedTable: $db.vaultTargets,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$VaultTargetsTableFilterComposer(
            $db: $db,
            $table: $db.vaultTargets,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$RoutingRulesTableOrderingComposer
    extends Composer<_$VaultVoiceDatabase, $RoutingRulesTable> {
  $$RoutingRulesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get priority => $composableBuilder(
    column: $table.priority,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get match => $composableBuilder(
    column: $table.match,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get subPath => $composableBuilder(
    column: $table.subPath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get filenamePattern => $composableBuilder(
    column: $table.filenamePattern,
    builder: (column) => ColumnOrderings(column),
  );

  $$VaultTargetsTableOrderingComposer get targetId {
    final $$VaultTargetsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.targetId,
      referencedTable: $db.vaultTargets,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$VaultTargetsTableOrderingComposer(
            $db: $db,
            $table: $db.vaultTargets,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$RoutingRulesTableAnnotationComposer
    extends Composer<_$VaultVoiceDatabase, $RoutingRulesTable> {
  $$RoutingRulesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get priority =>
      $composableBuilder(column: $table.priority, builder: (column) => column);

  GeneratedColumnWithTypeConverter<JsonMap, String> get match =>
      $composableBuilder(column: $table.match, builder: (column) => column);

  GeneratedColumn<String> get subPath =>
      $composableBuilder(column: $table.subPath, builder: (column) => column);

  GeneratedColumn<String> get filenamePattern => $composableBuilder(
    column: $table.filenamePattern,
    builder: (column) => column,
  );

  $$VaultTargetsTableAnnotationComposer get targetId {
    final $$VaultTargetsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.targetId,
      referencedTable: $db.vaultTargets,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$VaultTargetsTableAnnotationComposer(
            $db: $db,
            $table: $db.vaultTargets,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$RoutingRulesTableTableManager
    extends
        RootTableManager<
          _$VaultVoiceDatabase,
          $RoutingRulesTable,
          RoutingRuleRow,
          $$RoutingRulesTableFilterComposer,
          $$RoutingRulesTableOrderingComposer,
          $$RoutingRulesTableAnnotationComposer,
          $$RoutingRulesTableCreateCompanionBuilder,
          $$RoutingRulesTableUpdateCompanionBuilder,
          (RoutingRuleRow, $$RoutingRulesTableReferences),
          RoutingRuleRow,
          PrefetchHooks Function({bool targetId})
        > {
  $$RoutingRulesTableTableManager(
    _$VaultVoiceDatabase db,
    $RoutingRulesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$RoutingRulesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$RoutingRulesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$RoutingRulesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<int> priority = const Value.absent(),
                Value<JsonMap> match = const Value.absent(),
                Value<String> targetId = const Value.absent(),
                Value<String> subPath = const Value.absent(),
                Value<String?> filenamePattern = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => RoutingRulesCompanion(
                id: id,
                priority: priority,
                match: match,
                targetId: targetId,
                subPath: subPath,
                filenamePattern: filenamePattern,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required int priority,
                required JsonMap match,
                required String targetId,
                Value<String> subPath = const Value.absent(),
                Value<String?> filenamePattern = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => RoutingRulesCompanion.insert(
                id: id,
                priority: priority,
                match: match,
                targetId: targetId,
                subPath: subPath,
                filenamePattern: filenamePattern,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$RoutingRulesTable, RoutingRuleRow>(table),
                  $$RoutingRulesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({targetId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (targetId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.targetId,
                        referencedTable: $$RoutingRulesTableReferences
                            ._targetIdTable(db),
                        referencedColumn: $$RoutingRulesTableReferences
                            ._targetIdTable(db)
                            .id,
                      ) as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$RoutingRulesTableProcessedTableManager =
    ProcessedTableManager<
      _$VaultVoiceDatabase,
      $RoutingRulesTable,
      RoutingRuleRow,
      $$RoutingRulesTableFilterComposer,
      $$RoutingRulesTableOrderingComposer,
      $$RoutingRulesTableAnnotationComposer,
      $$RoutingRulesTableCreateCompanionBuilder,
      $$RoutingRulesTableUpdateCompanionBuilder,
      (RoutingRuleRow, $$RoutingRulesTableReferences),
      RoutingRuleRow,
      PrefetchHooks Function({bool targetId})
    >;
typedef $$ExportsTableCreateCompanionBuilder = ExportsCompanion Function({
  required String id,
  required String recordingId,
  required String targetId,
  required String relPath,
  required String contentHash,
  required ExportStatus status,
  Value<int> attempts,
  required DateTime updatedAt,
  Value<int> rowid,
});
typedef $$ExportsTableUpdateCompanionBuilder = ExportsCompanion Function({
  Value<String> id,
  Value<String> recordingId,
  Value<String> targetId,
  Value<String> relPath,
  Value<String> contentHash,
  Value<ExportStatus> status,
  Value<int> attempts,
  Value<DateTime> updatedAt,
  Value<int> rowid,
});

final class $$ExportsTableReferences
    extends BaseReferences<_$VaultVoiceDatabase, $ExportsTable, ExportRow> {
  $$ExportsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $RecordingsTable _recordingIdTable(_$VaultVoiceDatabase db) =>
      db.recordings.createAlias('exports__recording_id__recordings__id');

  $$RecordingsTableProcessedTableManager get recordingId {
    final $_column = $_itemColumn<String>('recording_id')!;

    final manager = $$RecordingsTableTableManager(
      $_db,
      $_db.recordings,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_recordingIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $VaultTargetsTable _targetIdTable(_$VaultVoiceDatabase db) =>
      db.vaultTargets.createAlias('exports__target_id__vault_targets__id');

  $$VaultTargetsTableProcessedTableManager get targetId {
    final $_column = $_itemColumn<String>('target_id')!;

    final manager = $$VaultTargetsTableTableManager(
      $_db,
      $_db.vaultTargets,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_targetIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$ExportsTableFilterComposer
    extends Composer<_$VaultVoiceDatabase, $ExportsTable> {
  $$ExportsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get relPath => $composableBuilder(
    column: $table.relPath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get contentHash => $composableBuilder(
    column: $table.contentHash,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<ExportStatus, ExportStatus, String>
  get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnFilters<int> get attempts => $composableBuilder(
    column: $table.attempts,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<DateTime, DateTime, int> get updatedAt =>
      $composableBuilder(
        column: $table.updatedAt,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  $$RecordingsTableFilterComposer get recordingId {
    final $$RecordingsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.recordingId,
      referencedTable: $db.recordings,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RecordingsTableFilterComposer(
            $db: $db,
            $table: $db.recordings,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$VaultTargetsTableFilterComposer get targetId {
    final $$VaultTargetsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.targetId,
      referencedTable: $db.vaultTargets,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$VaultTargetsTableFilterComposer(
            $db: $db,
            $table: $db.vaultTargets,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ExportsTableOrderingComposer
    extends Composer<_$VaultVoiceDatabase, $ExportsTable> {
  $$ExportsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get relPath => $composableBuilder(
    column: $table.relPath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get contentHash => $composableBuilder(
    column: $table.contentHash,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get attempts => $composableBuilder(
    column: $table.attempts,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$RecordingsTableOrderingComposer get recordingId {
    final $$RecordingsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.recordingId,
      referencedTable: $db.recordings,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RecordingsTableOrderingComposer(
            $db: $db,
            $table: $db.recordings,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$VaultTargetsTableOrderingComposer get targetId {
    final $$VaultTargetsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.targetId,
      referencedTable: $db.vaultTargets,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$VaultTargetsTableOrderingComposer(
            $db: $db,
            $table: $db.vaultTargets,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ExportsTableAnnotationComposer
    extends Composer<_$VaultVoiceDatabase, $ExportsTable> {
  $$ExportsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get relPath =>
      $composableBuilder(column: $table.relPath, builder: (column) => column);

  GeneratedColumn<String> get contentHash => $composableBuilder(
    column: $table.contentHash,
    builder: (column) => column,
  );

  GeneratedColumnWithTypeConverter<ExportStatus, String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<int> get attempts =>
      $composableBuilder(column: $table.attempts, builder: (column) => column);

  GeneratedColumnWithTypeConverter<DateTime, int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  $$RecordingsTableAnnotationComposer get recordingId {
    final $$RecordingsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.recordingId,
      referencedTable: $db.recordings,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RecordingsTableAnnotationComposer(
            $db: $db,
            $table: $db.recordings,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$VaultTargetsTableAnnotationComposer get targetId {
    final $$VaultTargetsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.targetId,
      referencedTable: $db.vaultTargets,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$VaultTargetsTableAnnotationComposer(
            $db: $db,
            $table: $db.vaultTargets,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ExportsTableTableManager
    extends
        RootTableManager<
          _$VaultVoiceDatabase,
          $ExportsTable,
          ExportRow,
          $$ExportsTableFilterComposer,
          $$ExportsTableOrderingComposer,
          $$ExportsTableAnnotationComposer,
          $$ExportsTableCreateCompanionBuilder,
          $$ExportsTableUpdateCompanionBuilder,
          (ExportRow, $$ExportsTableReferences),
          ExportRow,
          PrefetchHooks Function({bool recordingId, bool targetId})
        > {
  $$ExportsTableTableManager(_$VaultVoiceDatabase db, $ExportsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ExportsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ExportsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ExportsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> recordingId = const Value.absent(),
                Value<String> targetId = const Value.absent(),
                Value<String> relPath = const Value.absent(),
                Value<String> contentHash = const Value.absent(),
                Value<ExportStatus> status = const Value.absent(),
                Value<int> attempts = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ExportsCompanion(
                id: id,
                recordingId: recordingId,
                targetId: targetId,
                relPath: relPath,
                contentHash: contentHash,
                status: status,
                attempts: attempts,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String recordingId,
                required String targetId,
                required String relPath,
                required String contentHash,
                required ExportStatus status,
                Value<int> attempts = const Value.absent(),
                required DateTime updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => ExportsCompanion.insert(
                id: id,
                recordingId: recordingId,
                targetId: targetId,
                relPath: relPath,
                contentHash: contentHash,
                status: status,
                attempts: attempts,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$ExportsTable, ExportRow>(table),
                  $$ExportsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({recordingId = false, targetId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (recordingId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.recordingId,
                        referencedTable: $$ExportsTableReferences
                            ._recordingIdTable(db),
                        referencedColumn: $$ExportsTableReferences
                            ._recordingIdTable(db)
                            .id,
                      ) as T;
                    }
                    if (targetId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.targetId,
                        referencedTable: $$ExportsTableReferences
                            ._targetIdTable(db),
                        referencedColumn: $$ExportsTableReferences
                            ._targetIdTable(db)
                            .id,
                      ) as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$ExportsTableProcessedTableManager =
    ProcessedTableManager<
      _$VaultVoiceDatabase,
      $ExportsTable,
      ExportRow,
      $$ExportsTableFilterComposer,
      $$ExportsTableOrderingComposer,
      $$ExportsTableAnnotationComposer,
      $$ExportsTableCreateCompanionBuilder,
      $$ExportsTableUpdateCompanionBuilder,
      (ExportRow, $$ExportsTableReferences),
      ExportRow,
      PrefetchHooks Function({bool recordingId, bool targetId})
    >;
typedef $$ModelsInstalledTableCreateCompanionBuilder =
    ModelsInstalledCompanion Function({
      required String id,
      required ModelType type,
      required String version,
      required String path,
      required String sha256,
      required int size,
      required DateTime installedAt,
      Value<int> rowid,
    });
typedef $$ModelsInstalledTableUpdateCompanionBuilder =
    ModelsInstalledCompanion Function({
      Value<String> id,
      Value<ModelType> type,
      Value<String> version,
      Value<String> path,
      Value<String> sha256,
      Value<int> size,
      Value<DateTime> installedAt,
      Value<int> rowid,
    });

class $$ModelsInstalledTableFilterComposer
    extends Composer<_$VaultVoiceDatabase, $ModelsInstalledTable> {
  $$ModelsInstalledTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<ModelType, ModelType, String> get type =>
      $composableBuilder(
        column: $table.type,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnFilters<String> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get path => $composableBuilder(
    column: $table.path,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sha256 => $composableBuilder(
    column: $table.sha256,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get size => $composableBuilder(
    column: $table.size,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<DateTime, DateTime, int> get installedAt =>
      $composableBuilder(
        column: $table.installedAt,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );
}

class $$ModelsInstalledTableOrderingComposer
    extends Composer<_$VaultVoiceDatabase, $ModelsInstalledTable> {
  $$ModelsInstalledTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get path => $composableBuilder(
    column: $table.path,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sha256 => $composableBuilder(
    column: $table.sha256,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get size => $composableBuilder(
    column: $table.size,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get installedAt => $composableBuilder(
    column: $table.installedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ModelsInstalledTableAnnotationComposer
    extends Composer<_$VaultVoiceDatabase, $ModelsInstalledTable> {
  $$ModelsInstalledTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumnWithTypeConverter<ModelType, String> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumn<String> get version =>
      $composableBuilder(column: $table.version, builder: (column) => column);

  GeneratedColumn<String> get path =>
      $composableBuilder(column: $table.path, builder: (column) => column);

  GeneratedColumn<String> get sha256 =>
      $composableBuilder(column: $table.sha256, builder: (column) => column);

  GeneratedColumn<int> get size =>
      $composableBuilder(column: $table.size, builder: (column) => column);

  GeneratedColumnWithTypeConverter<DateTime, int> get installedAt =>
      $composableBuilder(
        column: $table.installedAt,
        builder: (column) => column,
      );
}

class $$ModelsInstalledTableTableManager
    extends
        RootTableManager<
          _$VaultVoiceDatabase,
          $ModelsInstalledTable,
          InstalledModelRow,
          $$ModelsInstalledTableFilterComposer,
          $$ModelsInstalledTableOrderingComposer,
          $$ModelsInstalledTableAnnotationComposer,
          $$ModelsInstalledTableCreateCompanionBuilder,
          $$ModelsInstalledTableUpdateCompanionBuilder,
          (
            InstalledModelRow,
            BaseReferences<
              _$VaultVoiceDatabase,
              $ModelsInstalledTable,
              InstalledModelRow
            >,
          ),
          InstalledModelRow,
          PrefetchHooks Function()
        > {
  $$ModelsInstalledTableTableManager(
    _$VaultVoiceDatabase db,
    $ModelsInstalledTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ModelsInstalledTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ModelsInstalledTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ModelsInstalledTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<ModelType> type = const Value.absent(),
                Value<String> version = const Value.absent(),
                Value<String> path = const Value.absent(),
                Value<String> sha256 = const Value.absent(),
                Value<int> size = const Value.absent(),
                Value<DateTime> installedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ModelsInstalledCompanion(
                id: id,
                type: type,
                version: version,
                path: path,
                sha256: sha256,
                size: size,
                installedAt: installedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required ModelType type,
                required String version,
                required String path,
                required String sha256,
                required int size,
                required DateTime installedAt,
                Value<int> rowid = const Value.absent(),
              }) => ModelsInstalledCompanion.insert(
                id: id,
                type: type,
                version: version,
                path: path,
                sha256: sha256,
                size: size,
                installedAt: installedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$ModelsInstalledTable, InstalledModelRow>(table),
                  BaseReferences<
                    _$VaultVoiceDatabase,
                    $ModelsInstalledTable,
                    InstalledModelRow
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ModelsInstalledTableProcessedTableManager =
    ProcessedTableManager<
      _$VaultVoiceDatabase,
      $ModelsInstalledTable,
      InstalledModelRow,
      $$ModelsInstalledTableFilterComposer,
      $$ModelsInstalledTableOrderingComposer,
      $$ModelsInstalledTableAnnotationComposer,
      $$ModelsInstalledTableCreateCompanionBuilder,
      $$ModelsInstalledTableUpdateCompanionBuilder,
      (
        InstalledModelRow,
        BaseReferences<
          _$VaultVoiceDatabase,
          $ModelsInstalledTable,
          InstalledModelRow
        >,
      ),
      InstalledModelRow,
      PrefetchHooks Function()
    >;
typedef $$SettingsTableCreateCompanionBuilder = SettingsCompanion Function({
  required String key,
  required String value,
  Value<int> rowid,
});
typedef $$SettingsTableUpdateCompanionBuilder = SettingsCompanion Function({
  Value<String> key,
  Value<String> value,
  Value<int> rowid,
});

class $$SettingsTableFilterComposer
    extends Composer<_$VaultVoiceDatabase, $SettingsTable> {
  $$SettingsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SettingsTableOrderingComposer
    extends Composer<_$VaultVoiceDatabase, $SettingsTable> {
  $$SettingsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SettingsTableAnnotationComposer
    extends Composer<_$VaultVoiceDatabase, $SettingsTable> {
  $$SettingsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<String> get value =>
      $composableBuilder(column: $table.value, builder: (column) => column);
}

class $$SettingsTableTableManager
    extends
        RootTableManager<
          _$VaultVoiceDatabase,
          $SettingsTable,
          SettingRow,
          $$SettingsTableFilterComposer,
          $$SettingsTableOrderingComposer,
          $$SettingsTableAnnotationComposer,
          $$SettingsTableCreateCompanionBuilder,
          $$SettingsTableUpdateCompanionBuilder,
          (
            SettingRow,
            BaseReferences<_$VaultVoiceDatabase, $SettingsTable, SettingRow>,
          ),
          SettingRow,
          PrefetchHooks Function()
        > {
  $$SettingsTableTableManager(_$VaultVoiceDatabase db, $SettingsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SettingsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SettingsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SettingsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> key = const Value.absent(),
            Value<String> value = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) => SettingsCompanion(key: key, value: value, rowid: rowid),
          createCompanionCallback: ({
            required String key,
            required String value,
            Value<int> rowid = const Value.absent(),
          }) => SettingsCompanion.insert(key: key, value: value, rowid: rowid),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$SettingsTable, SettingRow>(table),
                  BaseReferences<
                    _$VaultVoiceDatabase,
                    $SettingsTable,
                    SettingRow
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SettingsTableProcessedTableManager =
    ProcessedTableManager<
      _$VaultVoiceDatabase,
      $SettingsTable,
      SettingRow,
      $$SettingsTableFilterComposer,
      $$SettingsTableOrderingComposer,
      $$SettingsTableAnnotationComposer,
      $$SettingsTableCreateCompanionBuilder,
      $$SettingsTableUpdateCompanionBuilder,
      (
        SettingRow,
        BaseReferences<_$VaultVoiceDatabase, $SettingsTable, SettingRow>,
      ),
      SettingRow,
      PrefetchHooks Function()
    >;

class $VaultVoiceDatabaseManager {
  final _$VaultVoiceDatabase _db;
  $VaultVoiceDatabaseManager(this._db);
  $$RecordingsTableTableManager get recordings =>
      $$RecordingsTableTableManager(_db, _db.recordings);
  $$AudioChunksTableTableManager get audioChunks =>
      $$AudioChunksTableTableManager(_db, _db.audioChunks);
  $$SpeechSegmentsTableTableManager get speechSegments =>
      $$SpeechSegmentsTableTableManager(_db, _db.speechSegments);
  $$MarkersTableTableManager get markers =>
      $$MarkersTableTableManager(_db, _db.markers);
  $$SpeakersTableTableManager get speakers =>
      $$SpeakersTableTableManager(_db, _db.speakers);
  $$TranscriptsTableTableManager get transcripts =>
      $$TranscriptsTableTableManager(_db, _db.transcripts);
  $$TranscriptSegmentsTableTableManager get transcriptSegments =>
      $$TranscriptSegmentsTableTableManager(_db, _db.transcriptSegments);
  $$JobsTableTableManager get jobs => $$JobsTableTableManager(_db, _db.jobs);
  $$ProfilesTableTableManager get profiles =>
      $$ProfilesTableTableManager(_db, _db.profiles);
  $$TemplatesTableTableManager get templates =>
      $$TemplatesTableTableManager(_db, _db.templates);
  $$ExtractionsTableTableManager get extractions =>
      $$ExtractionsTableTableManager(_db, _db.extractions);
  $$ActionItemsTableTableManager get actionItems =>
      $$ActionItemsTableTableManager(_db, _db.actionItems);
  $$VaultTargetsTableTableManager get vaultTargets =>
      $$VaultTargetsTableTableManager(_db, _db.vaultTargets);
  $$RoutingRulesTableTableManager get routingRules =>
      $$RoutingRulesTableTableManager(_db, _db.routingRules);
  $$ExportsTableTableManager get exports =>
      $$ExportsTableTableManager(_db, _db.exports);
  $$ModelsInstalledTableTableManager get modelsInstalled =>
      $$ModelsInstalledTableTableManager(_db, _db.modelsInstalled);
  $$SettingsTableTableManager get settings =>
      $$SettingsTableTableManager(_db, _db.settings);
}
