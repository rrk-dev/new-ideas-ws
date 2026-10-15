import 'package:flutter_riverpod/misc.dart';
import 'package:vaultvoice/features/recording/data/recording_screen_providers.dart';

/// Hermetic Record-screen (AUD-08) pickers for widget tests that pump the
/// Record tab: no profile registry and no vault-folder DB streams.
List<Override> recordScreenPickerOverrides() => [
  profileChoicesProvider.overrideWith((ref) => Stream.value(const [])),
  destinationChoicesProvider.overrideWith((ref) async => const []),
];
