import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vaultvoice/core/errors/result.dart';
import 'package:vaultvoice/core/l10n/l10n.dart';
import 'package:vaultvoice/features/licensing/data/purchase_providers.dart';
import 'package:vaultvoice/features/licensing/domain/store_purchase.dart';

class PaywallScreen extends ConsumerStatefulWidget {
  const PaywallScreen({super.key});
  @override
  ConsumerState<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends ConsumerState<PaywallScreen> {
  bool _busy = false;
  String? _message;

  Future<void> _purchase(String id) async {
    setState(() {
      _busy = true;
      _message = null;
    });
    final result = await ref.read(purchaseServiceProvider).purchase(id);
    if (!mounted) return;
    final l = context.l10n;
    setState(() {
      _busy = false;
      _message = switch (result) {
        Ok(value: PurchaseOutcome.purchased) => l.purchaseComplete,
        Ok(value: PurchaseOutcome.pending) => l.purchasePending,
        Ok(value: PurchaseOutcome.cancelled) => l.purchaseCancelled,
        Err() => l.purchaseUnavailable,
      };
    });
  }

  Future<void> _restore() async {
    setState(() {
      _busy = true;
      _message = null;
    });
    final result = await ref.read(purchaseServiceProvider).restore();
    if (!mounted) return;
    setState(() {
      _busy = false;
      _message = result is Ok<void>
          ? context.l10n.purchaseRestored
          : context.l10n.purchaseUnavailable;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final products = ref.watch(storeProductsProvider);
    return Scaffold(
      appBar: AppBar(title: Text(l.paywallTitle)),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text(
            l.paywallBenefits,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 24),
          products.when(
            loading: () => Semantics(
              label: l.purchaseLoading,
              child: const Center(child: CircularProgressIndicator()),
            ),
            error: (_, _) => Text(l.purchaseUnavailable),
            data: (items) => Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (items.isEmpty) Text(l.purchaseUnavailable),
                for (final p in items)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: FilledButton(
                      onPressed: _busy ? null : () => _purchase(p.id),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Text(
                          p.id == annualProductId
                              ? l.purchaseAnnual(p.price)
                              : l.purchaseLifetime(p.price),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Text(l.purchaseAnnualTerms),
          const SizedBox(height: 16),
          OutlinedButton(
            onPressed: _busy ? null : _restore,
            child: Text(l.purchaseRestore),
          ),
          TextButton(
            onPressed: _busy
                ? null
                : () => ref.invalidate(storeProductsProvider),
            child: Text(l.purchaseRetry),
          ),
          if (_busy) const LinearProgressIndicator(),
          if (_message != null)
            Semantics(liveRegion: true, child: Text(_message!)),
        ],
      ),
    );
  }
}
