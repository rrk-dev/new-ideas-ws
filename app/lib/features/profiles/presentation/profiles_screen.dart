import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:vaultvoice/core/errors/result.dart';
import 'package:vaultvoice/core/l10n/l10n.dart';
import 'package:vaultvoice/core/widgets/status_message.dart';
import 'package:vaultvoice/features/licensing/domain/entitlement.dart';
import 'package:vaultvoice/features/licensing/domain/paywall.dart';
import 'package:vaultvoice/features/licensing/presentation/feature_gate.dart';
import 'package:vaultvoice/features/profiles/data/custom_profile_providers.dart';
import 'package:vaultvoice/features/profiles/domain/profile.dart';

/// Profiles tab (PRF-07): built-in profiles (read-only, duplicable) and the
/// user's custom profiles; creating/editing is gated by
/// `Feature.customProfiles` (LIC-01).
class ProfilesScreen extends ConsumerWidget {
  const ProfilesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final profiles = ref.watch(profileListProvider);
    final canEdit = ref.watch(canEditProfilesProvider);
    return Scaffold(
      appBar: AppBar(title: Text(l.tabProfiles)),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _create(context, ref),
        icon: const Icon(Icons.add),
        label: Text(l.profilesNew),
      ),
      body: switch (profiles) {
        AsyncData(:final value) => _list(context, ref, value, canEdit),
        AsyncError() => StatusMessage(
          icon: Icons.error_outline,
          message: l.profilesLoadFailed,
        ),
        _ => const SizedBox.shrink(),
      },
    );
  }

  Future<void> _create(BuildContext context, WidgetRef ref) async {
    if (!await ensureFeature(
      ref,
      Feature.customProfiles,
      from: PaywallEntryPoint.profileEditor,
    )) {
      if (context.mounted) _snack(context, context.l10n.profilesProOnly);
      return;
    }
    if (context.mounted) await context.push('/profiles/new');
  }

  Future<void> _duplicate(
    BuildContext context,
    WidgetRef ref,
    Profile p,
  ) async {
    final l = context.l10n;
    if (!await ensureFeature(
      ref,
      Feature.customProfiles,
      from: PaywallEntryPoint.profileEditor,
    )) {
      if (context.mounted) _snack(context, l.profilesProOnly);
      return;
    }
    final service = await ref.read(customProfileServiceProvider.future);
    final draft = await service.duplicateAsDraft(
      p.id,
      copyName: l.profilesCopyName(p.name),
    );
    final saved = switch (draft) {
      Ok(:final value) => await service.save(value),
      Err(:final failure) => Err<Profile>(failure),
    };
    if (!context.mounted) return;
    switch (saved) {
      case Ok(:final value):
        await context.push('/profiles/${value.id}');
      case Err(:final failure):
        _snack(context, l.profileEditorSaveFailed(failure.message));
    }
  }

  Widget _list(
    BuildContext context,
    WidgetRef ref,
    List<Profile> all,
    bool canEdit,
  ) {
    final l = context.l10n;
    final builtins = all.where((p) => p.source == ProfileSource.builtin);
    final custom = all.where((p) => p.source != ProfileSource.builtin).toList();
    return ListView(
      padding: const EdgeInsets.only(bottom: 96),
      children: [
        _Header(l.profilesBuiltinSection),
        for (final p in builtins)
          ListTile(
            leading: const Icon(Icons.tune),
            title: Text(p.name),
            subtitle: Text(p.description),
            onTap: () => context.push('/profiles/${p.id}'),
            trailing: IconButton(
              icon: const Icon(Icons.copy_outlined),
              tooltip: l.profilesDuplicate(p.name),
              onPressed: () => _duplicate(context, ref, p),
            ),
          ),
        _Header(l.profilesCustomSection),
        if (!canEdit)
          ListTile(
            leading: const Icon(Icons.lock_outline),
            title: Text(l.profilesProOnly),
          ),
        if (custom.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(l.profilesCustomEmpty),
          ),
        for (final p in custom)
          ListTile(
            leading: Icon(
              p.source == ProfileSource.enterprise
                  ? Icons.business_outlined
                  : Icons.edit_note,
            ),
            title: Text(p.name),
            subtitle: Text(
              p.source == ProfileSource.enterprise
                  ? l.profilesManaged
                  : (canEdit ? p.description : l.profilesReadOnly),
            ),
            onTap: () => context.push('/profiles/${p.id}'),
            trailing: IconButton(
              icon: const Icon(Icons.copy_outlined),
              tooltip: l.profilesDuplicate(p.name),
              onPressed: () => _duplicate(context, ref, p),
            ),
          ),
      ],
    );
  }
}

void _snack(BuildContext context, String text) =>
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

class _Header extends StatelessWidget {
  const _Header(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
    child: Semantics(
      header: true,
      child: Text(text, style: Theme.of(context).textTheme.titleSmall),
    ),
  );
}
