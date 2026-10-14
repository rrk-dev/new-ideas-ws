import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vaultvoice/core/errors/failure.dart';
import 'package:vaultvoice/core/flavor.dart';
import 'package:vaultvoice/core/flavor_provider.dart';
import 'package:vaultvoice/core/platform/cancel_token.dart';
import 'package:vaultvoice/core/platform/llm_engine.dart';
import 'package:vaultvoice/core/platform/providers.dart';

/// Dev-flavor-only LLM playground (LLM-04): streams the output of the
/// configured [LlmEngine] and cancels it. Never shown in prod builds; the
/// typed text stays on this screen (not logged).
class LlmDebugScreen extends ConsumerStatefulWidget {
  const LlmDebugScreen({super.key});

  @override
  ConsumerState<LlmDebugScreen> createState() => _LlmDebugScreenState();
}

class _LlmDebugScreenState extends ConsumerState<LlmDebugScreen> {
  final _prompt = TextEditingController(text: 'Name three colors.');
  final _output = StringBuffer();
  CancelToken? _cancel;
  String _status = 'idle';

  bool get _running => _cancel != null;

  Future<void> _generate() async {
    final LlmEngine engine;
    try {
      engine = ref.read(llmEngineProvider);
    } on Object {
      // provider not overridden (no model configured)
      setState(() => _status = 'no LLM engine configured');
      return;
    }
    final cancel = CancelToken();
    setState(() {
      _output.clear();
      _cancel = cancel;
      _status = 'generating';
    });
    final sw = Stopwatch()..start();
    final result = await engine.generate(
      LlmRequest(
        prompt: _prompt.text,
        maxTokens: 256,
        sampling: const LlmSampling(preset: LlmPreset.summary),
      ),
      cancel: cancel,
      onToken: (t) {
        if (mounted) setState(() => _output.write(t));
      },
    );
    if (!mounted) return;
    setState(() {
      _cancel = null;
      _status = result.when(
        ok: (_) => 'done in ${sw.elapsedMilliseconds} ms',
        err: (f) =>
            f is CancelledFailure ? 'cancelled' : 'failed: ${f.message}',
      );
    });
  }

  @override
  void dispose() {
    _cancel?.cancel();
    _prompt.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('LLM debug')),
    body: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            key: const Key('llm-debug-prompt'),
            controller: _prompt,
            maxLines: 3,
            decoration: const InputDecoration(labelText: 'Prompt'),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              FilledButton(
                key: const Key('llm-debug-generate'),
                onPressed: _running ? null : _generate,
                child: const Text('Generate'),
              ),
              const SizedBox(width: 8),
              OutlinedButton(
                key: const Key('llm-debug-cancel'),
                onPressed: _running ? () => _cancel?.cancel() : null,
                child: const Text('Cancel'),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(_status, key: const Key('llm-debug-status')),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: SingleChildScrollView(
              child: SelectableText(
                _output.toString(),
                key: const Key('llm-debug-output'),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

/// Settings entry for [LlmDebugScreen], dev flavor only.
class LlmDebugTile extends ConsumerWidget {
  const LlmDebugTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (ref.watch(flavorProvider) != Flavor.dev) return const SizedBox.shrink();
    return ListTile(
      leading: const Icon(Icons.memory),
      title: const Text('LLM debug (dev)'),
      onTap: () => Navigator.of(
        context,
      ).push(MaterialPageRoute<void>(builder: (_) => const LlmDebugScreen())),
    );
  }
}
