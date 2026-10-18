import 'package:vaultvoice/features/settings/domain/setting_definitions.dart';

/// A parsed retention setting (`RetentionOption` ids, APP-03 settings
/// "Keep audio" / "Keep transcripts and notes").
sealed class RetentionPolicy {
  const RetentionPolicy();

  /// Unknown ids keep data (fail safe: never delete on a value we do not
  /// understand).
  factory RetentionPolicy.parse(String option) => switch (option) {
    RetentionOption.afterExport => const DeleteAfterExport(),
    RetentionOption.days7 => const DeleteAfterDays(7),
    RetentionOption.days30 => const DeleteAfterDays(30),
    RetentionOption.days90 => const DeleteAfterDays(90),
    _ => switch (RetentionOption.daysOf(option)) {
      final int d => DeleteAfterDays(d),
      null => const KeepForever(),
    },
  };

  /// Whether data of a recording created at [createdAt] is due for deletion
  /// at [now]. [exported]: at least one export of its note was written.
  bool isDue({
    required DateTime createdAt,
    required DateTime now,
    required bool exported,
  });
}

final class KeepForever extends RetentionPolicy {
  const KeepForever();

  @override
  bool isDue({
    required DateTime createdAt,
    required DateTime now,
    required bool exported,
  }) => false;
}

/// Deleted once the note was successfully written to a vault folder.
final class DeleteAfterExport extends RetentionPolicy {
  const DeleteAfterExport();

  @override
  bool isDue({
    required DateTime createdAt,
    required DateTime now,
    required bool exported,
  }) => exported;
}

/// Deleted [days] days after the recording was made.
final class DeleteAfterDays extends RetentionPolicy {
  const DeleteAfterDays(this.days);

  final int days;

  @override
  bool isDue({
    required DateTime createdAt,
    required DateTime now,
    required bool exported,
  }) => !now.isBefore(createdAt.add(Duration(days: days)));
}
