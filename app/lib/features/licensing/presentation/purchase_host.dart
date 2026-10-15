import 'dart:async';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vaultvoice/features/licensing/data/purchase_providers.dart';
import 'package:vaultvoice/features/licensing/domain/feature_matrix.dart';

/// Store updates start at launch; requery on foreground and hourly, including
/// acknowledgement retries for purchases completed while the app was killed.
class PurchaseHost extends ConsumerStatefulWidget {
  const PurchaseHost({required this.child, super.key});
  final Widget child;
  @override
  ConsumerState<PurchaseHost> createState() => _PurchaseHostState();
}

class _PurchaseHostState extends ConsumerState<PurchaseHost> {
  AppLifecycleListener? _lifecycle;
  Timer? _timer;
  @override
  void initState() {
    super.initState();
    if (kCommercialBuild && (Platform.isIOS || Platform.isAndroid)) {
      final service = ref.read(purchaseServiceProvider);
      unawaited(service.start());
      _lifecycle = AppLifecycleListener(
        onResume: () => unawaited(service.refresh()),
      );
      _timer = Timer.periodic(
        const Duration(hours: 1),
        (_) => unawaited(service.refresh()),
      );
    }
  }

  @override
  void dispose() {
    _lifecycle?.dispose();
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
