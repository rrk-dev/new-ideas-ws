import 'package:flutter/widgets.dart';
import 'package:vaultvoice/bootstrap.dart';
import 'package:vaultvoice/core/flavor.dart';
import 'package:vaultvoice/features/extraction/data/dev_llm_engine.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final devLlm = await devLlmOverrides();
  await bootstrap(Flavor.dev, overrides: devLlm, productionLlm: devLlm.isEmpty);
}
