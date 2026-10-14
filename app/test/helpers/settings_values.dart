import 'package:vaultvoice/features/settings/domain/setting_definitions.dart';

/// A value different from [def]'s default, as the UI would set it.
Object otherValue(SettingDef<Object> def) => switch (def) {
  ToggleSetting(:final defaultValue) => !defaultValue,
  ChoiceSetting(:final options, :final defaultValue) => options.firstWhere(
    (o) => o != defaultValue,
  ),
  TextSetting() => '{{date:YYYY}}/{{slug}}.md',
};
