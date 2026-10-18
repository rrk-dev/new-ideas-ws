import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vaultvoice/core/l10n/l10n.dart';
import 'package:vaultvoice/core/theme/app_tokens.dart';
import 'package:vaultvoice/core/widgets/grouped_card.dart';
import 'package:vaultvoice/features/licensing/data/licensing_providers.dart';
import 'package:vaultvoice/features/licensing/domain/paywall.dart';
import 'package:vaultvoice/features/licensing/presentation/feature_gate.dart';
import 'package:vaultvoice/features/profiles/domain/profile_features.dart';
import 'package:vaultvoice/features/recording/domain/recording_session.dart';

/// The user's pick in `showProfilePicker`; id null = Auto.
typedef ProfilePick = ({String? id});

/// Bottom sheet listing every profile with icon, name and one-line
/// description. Returns null when dismissed.
Future<ProfilePick?> showProfilePicker(
  BuildContext context, {
  required List<ProfileChoice> choices,
  required String? selectedId,
  bool includeAuto = true,
}) => showModalBottomSheet<ProfilePick>(
  context: context,
  isScrollControlled: true,
  showDragHandle: true,
  builder: (_) => ProfilePicker(
    choices: choices,
    selectedId: selectedId,
    includeAuto: includeAuto,
  ),
);

/// Built-in and custom profiles as a `GroupedCard`. A profile behind a
/// feature the user does not have shows a lock; tapping it opens the
/// paywall (`ensureFeature`) and selects it only when it became available.
class ProfilePicker extends ConsumerWidget {
  const ProfilePicker({
    required this.choices,
    required this.selectedId,
    this.includeAuto = true,
    super.key,
  });

  final List<ProfileChoice> choices;
  final String? selectedId;
  final bool includeAuto;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: Semantics(
                header: true,
                child: Text(
                  l10n.profilePickerTitle,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            GroupedCard(
              children: [
                if (includeAuto)
                  _ProfileRow(
                    id: 'auto',
                    icon: Icons.auto_awesome,
                    name: l10n.recordAuto,
                    description: l10n.profilePickerAutoDescription,
                    selected: selectedId == null,
                    locked: false,
                    onTap: () => Navigator.of(context).pop((id: null)),
                  ),
                for (final c in choices)
                  _ProfileRow(
                    id: c.id,
                    icon: profileIcon(c.icon),
                    name: c.name,
                    description: c.description,
                    selected: selectedId == c.id,
                    locked: _isLocked(ref, c.id),
                    onTap: () => _pick(context, ref, c),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static bool _isLocked(WidgetRef ref, String profileId) {
    final feature = featureForProfile(profileId);
    return feature != null && !ref.watch(featureProvider(feature));
  }

  Future<void> _pick(
    BuildContext context,
    WidgetRef ref,
    ProfileChoice choice,
  ) async {
    final feature = featureForProfile(choice.id);
    if (feature != null &&
        !await ensureFeature(
          ref,
          feature,
          from: PaywallEntryPoint.profilePicker,
        )) {
      return;
    }
    if (!context.mounted) return;
    Navigator.of(context).pop((id: choice.id));
  }
}

class _ProfileRow extends StatelessWidget {
  const _ProfileRow({
    required this.id,
    required this.icon,
    required this.name,
    required this.description,
    required this.selected,
    required this.locked,
    required this.onTap,
  });

  final String id;
  final IconData icon;
  final String name;
  final String description;
  final bool selected;
  final bool locked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      selected: selected,
      label: locked ? l10n.profilePickerLockedHint(name) : null,
      child: ListTile(
        key: ValueKey('profile-option-$id'),
        leading: Icon(icon),
        title: Text(name),
        subtitle: description.isEmpty
            ? null
            : Text(description, maxLines: 2, overflow: TextOverflow.ellipsis),
        trailing: locked
            ? Icon(
                Icons.lock_outline,
                key: ValueKey('profile-lock-$id'),
                color: scheme.onSurfaceVariant,
              )
            : selected
            ? Icon(Icons.check, color: scheme.primary)
            : null,
        selected: selected,
        onTap: onTap,
      ),
    );
  }
}

/// Material icon for a profile's `icon` name; the generic profile icon for
/// null or unknown names (custom profiles may use any string).
IconData profileIcon(String? name) => switch (name) {
  'groups' => Icons.groups,
  'receipt_long' => Icons.receipt_long,
  'architecture' => Icons.architecture,
  'school' => Icons.school,
  'handshake' => Icons.handshake,
  'record_voice_over' => Icons.record_voice_over,
  _ => Icons.tune,
};
