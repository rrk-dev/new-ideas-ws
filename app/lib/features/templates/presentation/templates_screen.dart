import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vaultvoice/core/l10n/l10n.dart';
import 'package:vaultvoice/core/routing/app_routes.dart';
import 'package:vaultvoice/core/theme/app_tokens.dart';
import 'package:vaultvoice/core/widgets/status_message.dart';
import 'package:vaultvoice/features/licensing/data/licensing_providers.dart';
import 'package:vaultvoice/features/licensing/domain/entitlement.dart';
import 'package:vaultvoice/features/templates/data/template_editor_providers.dart';
import 'package:vaultvoice/features/templates/domain/builtin_templates.dart';

/// Display label of a template flavor.
String flavorLabel(BuildContext context, TemplateFlavor f) => switch (f) {
  TemplateFlavor.obsidian => context.l10n.templateFlavorObsidian,
  TemplateFlavor.logseq => context.l10n.templateFlavorLogseq,
  TemplateFlavor.plain => context.l10n.templateFlavorPlain,
};

/// Settings → Templates (EXP-07): built-in templates (read-only, can be
/// duplicated) and the user's custom templates (Pro).
class TemplatesScreen extends ConsumerWidget {
  const TemplatesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final custom = ref.watch(customTemplatesProvider);
    final editable = ref.watch(featureProvider(Feature.customTemplates));
    Widget header(String text) => Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.xs,
      ),
      child: Text(
        text,
        style: Theme.of(context).textTheme.titleSmall
            ?.copyWith(color: Theme.of(context).colorScheme.primary),
      ),
    );
    void open(String id) =>
        TemplateEditorRoute(templateId: id).push<void>(context);

    return Scaffold(
      appBar: AppBar(title: Text(l.settingsTemplates)),
      body: ListView(
        padding: const EdgeInsets.only(bottom: AppSpacing.xl),
        children: [
          if (!editable)
            Padding(
              key: const ValueKey('templates-locked'),
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Text(l.templatesLocked),
            ),
          header(l.templatesCustom),
          ...custom.when(
            loading: () => [
              Center(
                child: CircularProgressIndicator(
                  semanticsLabel: l.commonLoading,
                ),
              ),
            ],
            error: (_, _) => [
              StatusMessage(
                icon: Icons.error_outline,
                message: l.templatesLoadFailed,
              ),
            ],
            data: (rows) => rows.isEmpty
                ? [
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                      ),
                      child: Text(l.templatesCustomEmpty),
                    ),
                  ]
                : [
                    for (final t in rows)
                      ListTile(
                        key: ValueKey('template-${t.id}'),
                        leading: const Icon(Icons.edit_note),
                        title: Text(t.id),
                        subtitle: Text(l.templateForProfile(t.profileId)),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => open(t.id),
                      ),
                  ],
          ),
          header(l.templatesBuiltin),
          for (final t in kBuiltinTemplates)
            ListTile(
              key: ValueKey('template-${t.id}'),
              leading: const Icon(Icons.description_outlined),
              title: Text(t.id),
              subtitle: Text(
                '${flavorLabel(context, t.flavor)} · '
                '${switch (t.profileId) {
                  null => l.templateForAnyProfile,
                  final id => l.templateForProfile(id),
                }}',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => open(t.id),
            ),
        ],
      ),
    );
  }
}
