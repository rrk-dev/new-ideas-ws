import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:vaultvoice/app.dart';
import 'package:vaultvoice/core/errors/error_boundary.dart';
import 'package:vaultvoice/core/flavor.dart';
import 'package:vaultvoice/core/flavor_provider.dart';

/// Shared startup path for every flavor.
///
/// Real engine implementations are added to [overrides] by the features that
/// own them.
void bootstrap(Flavor flavor, {List<Override> overrides = const []}) {
  WidgetsFlutterBinding.ensureInitialized();
  installErrorBoundary();
  runApp(
    ProviderScope(
      overrides: [flavorProvider.overrideWithValue(flavor), ...overrides],
      child: const App(),
    ),
  );
}
