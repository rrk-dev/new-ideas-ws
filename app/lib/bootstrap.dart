import 'package:flutter/widgets.dart';
import 'package:vaultvoice/app.dart';
import 'package:vaultvoice/core/flavor.dart';

/// Shared startup path for every flavor. FND-02 extends it with error hooks.
void bootstrap(Flavor flavor) {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(App(flavor: flavor));
}
