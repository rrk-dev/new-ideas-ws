import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:vaultvoice/core/flavor.dart';

part 'flavor_provider.g.dart';

/// Active build flavor; `bootstrap` overrides it with the entrypoint's value.
@Riverpod(keepAlive: true)
Flavor flavor(Ref ref) => Flavor.prod;
