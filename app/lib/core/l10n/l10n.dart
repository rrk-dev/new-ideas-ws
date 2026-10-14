import 'package:flutter/widgets.dart';
import 'package:vaultvoice/core/l10n/gen/app_localizations.dart';

export 'package:vaultvoice/core/l10n/gen/app_localizations.dart';

/// Locale used when the device locale is not supported (English at launch).
const kFallbackLocale = Locale('en');

extension L10nContext on BuildContext {
  /// The app's strings for this context (`lib/core/l10n/arb/app_en.arb`).
  /// Falls back to English when no `AppLocalizations` delegate is installed
  /// (e.g. a widget pumped without `MaterialApp.localizationsDelegates`).
  AppLocalizations get l10n =>
      Localizations.of<AppLocalizations>(this, AppLocalizations) ??
      lookupAppLocalizations(kFallbackLocale);
}

/// Strings for [locale] outside the widget tree (notifications), falling back
/// to English for unsupported locales.
AppLocalizations l10nFor(Locale locale) {
  final supported = AppLocalizations.supportedLocales.any(
    (l) => l.languageCode == locale.languageCode,
  );
  return lookupAppLocalizations(supported ? locale : kFallbackLocale);
}
