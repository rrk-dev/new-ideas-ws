import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vaultvoice/core/l10n/l10n.dart';
import 'package:vaultvoice/core/network/network_activity.dart';
import 'package:vaultvoice/core/platform/providers.dart';

/// Every request the gateway saw (SEC-02), newest first.
final StreamProvider<List<NetworkActivityEntry>> networkActivityProvider =
    StreamProvider.autoDispose<List<NetworkActivityEntry>>(
      (ref) => ref.watch(networkActivityLogProvider).watch(),
    );

/// Settings → Privacy → Network activity.
class NetworkActivityTile extends StatelessWidget {
  const NetworkActivityTile({super.key});

  @override
  Widget build(BuildContext context) => ListTile(
    key: const ValueKey('privacy-network-activity'),
    leading: const Icon(Icons.swap_vert),
    title: Text(context.l10n.networkActivityTitle),
    subtitle: Text(context.l10n.networkActivitySubtitle),
    trailing: const Icon(Icons.chevron_right),
    onTap: () => Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const NetworkActivityScreen()),
    ),
  );
}

class NetworkActivityScreen extends ConsumerWidget {
  const NetworkActivityScreen({super.key});

  static String describe(AppLocalizations l, NetworkActivityEntry e) {
    final what = switch (e.outcome) {
      NetworkOutcome.completed => l.networkActivityCompleted(
        '${e.statusCode ?? '?'}',
      ),
      NetworkOutcome.denied => l.networkActivityDenied,
      NetworkOutcome.failed => l.networkActivityFailed,
      NetworkOutcome.handedToSystem => l.networkActivitySystem,
    };
    final at = e.at.toLocal().toIso8601String().substring(0, 19);
    return [
      at.replaceFirst('T', ' '),
      what,
      if (e.bytes case final b?) l.networkActivityBytes('$b'),
    ].join(' · ');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final entries = ref.watch(networkActivityProvider).value ?? const [];
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.networkActivityTitle),
        actions: [
          IconButton(
            key: const ValueKey('network-activity-clear'),
            tooltip: l10n.networkActivityClear,
            icon: const Icon(Icons.delete_sweep_outlined),
            onPressed: entries.isEmpty
                ? null
                : () => ref.read(networkActivityLogProvider).clear(),
          ),
        ],
      ),
      body: entries.isEmpty
          ? Center(child: Text(l10n.networkActivityEmpty))
          : ListView.builder(
              itemCount: entries.length,
              itemBuilder: (context, i) {
                final e = entries[entries.length - 1 - i];
                return ListTile(
                  leading: Icon(
                    e.outcome == NetworkOutcome.denied
                        ? Icons.block
                        : Icons.cloud_download_outlined,
                  ),
                  title: Text('${e.host}${e.path}'),
                  subtitle: Text(describe(l10n, e)),
                );
              },
            ),
    );
  }
}
