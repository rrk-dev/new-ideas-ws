import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vaultvoice/core/errors/result.dart';
import 'package:vaultvoice/core/licenses/bundled_licenses.dart';
import 'package:vaultvoice/core/network/model_hosts.dart';
import 'package:vaultvoice/features/extraction/domain/device_tiering.dart';
import 'package:vaultvoice/features/licensing/domain/entitlement.dart';
import 'package:vaultvoice/features/licensing/domain/feature_access.dart';
import 'package:vaultvoice/features/licensing/domain/feature_matrix.dart';
import 'package:vaultvoice/features/models/domain/model_bundle.dart';
import 'package:vaultvoice/features/models/domain/model_catalog.dart';
import 'package:vaultvoice/features/pipeline/domain/active_models.dart';

const _id = 'llama-3.2-3b-instruct-q4_k_m';
const _licensePackage = 'Llama-3.2-3B-Instruct (model)';

ModelCatalog _bundled() => switch (ModelCatalog.parse(
  File('assets/catalog/catalog.json').readAsBytesSync(),
)) {
  Ok(:final value) => value,
  Err(:final failure) => throw StateError('$failure'),
};

DeviceProfile _device(double gib) => DeviceProfile(
  platform: 'ios',
  osVersion: 'test',
  totalRamBytes: (gib * 1024 * 1024 * 1024).round(),
  availableRamBytes: 3 * 1024 * 1024 * 1024,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final catalog = _bundled();
  final m = catalog.byId(_id)!;

  test('[ASK-01/AC2] every URL of the 3B entry is on an allowlisted host; '
      'the HF redirect host is a known redirect host', () {
    expect(m.urls, hasLength(2));
    for (final u in m.urls) {
      expect(u.scheme, 'https');
      expect(kModelHosts, contains(u.host), reason: '$u');
      expect(u.hasQuery, isFalse);
    }
    expect(m.urls.last.host, 'huggingface.co');
    expect(
      m.urls.last.path,
      contains('5ab33fa94d1d04e903623ae72c95d1696f09f9e8'),
    );
    // Observed 2026-10-17: the pinned HF URL redirects to us.aws.cdn.hf.co.
    expect(kModelRedirectHosts, contains('us.aws.cdn.hf.co'));
    // Same hosts as the 1B entry: no new network host was added for the 3B.
    final one = catalog.byId('llama-3.2-1b-instruct-q4_k_m')!;
    expect(
      m.urls.map((u) => u.host).toSet(),
      one.urls.map((u) => u.host).toSet(),
    );
  });

  test('[ASK-01/AC5] the licence text and attribution of the 3B are in the '
      'licences screen data and docs/licenses.md', () async {
    expect(m.license, 'Llama 3.2 Community License');
    expect(m.attribution, 'Built with Llama');
    registerBundledLicenses();
    final entries = await LicenseRegistry.licenses
        .where((e) => e.packages.contains(_licensePackage))
        .toList();
    expect(entries, isNotEmpty);
    final text = entries
        .expand((e) => e.paragraphs.map((p) => p.text))
        .join('\n');
    expect(text, contains('LLAMA 3.2 COMMUNITY LICENSE AGREEMENT'));
    expect(text, contains('Built with Llama'));
    final doc = File('../docs/licenses.md').readAsStringSync();
    expect(doc, contains('`$_id`'));
    expect(doc, contains('3B Instruct'));
    expect(doc, contains('https://www.llama.com/llama3_2/use-policy'));
  });

  test('[ASK-01] 3B is a large LLM: recommended for High only; never the '
      'default when the plan lacks Feature.largeLlm', () {
    expect(isLargeLlm(m), isTrue);
    expect(m.recommendedDeviceTiers, [DeviceTier.high]);
    expect(m.size, greaterThan(kSmallLlmMaxBytes));
    // PRODUCT-DECISION (LIC-05): the intended tier is recorded in the data.
    expect(m.tier, ModelTier.pro);
    const free = LlmPlanGate(largeLlm: _no);
    const allowed = LlmPlanGate(largeLlm: _yes);
    for (final gib in [3.7, 5.6, 7.3, 11.0]) {
      expect(
        defaultsFor(_device(gib), catalog, free).llm!.id,
        'llama-3.2-1b-instruct-q4_k_m',
        reason: '$gib GiB, large LLM not allowed',
      );
    }
    expect(
      defaultsFor(_device(5.6), catalog, allowed).llm!.id,
      'llama-3.2-1b-instruct-q4_k_m',
      reason: 'Mid is not recommended for the 3B',
    );
    // Product decision: the 3B is explicit-selection only, never a default.
    expect(
      defaultsFor(_device(7.3), catalog, allowed).llm!.id,
      'llama-3.2-1b-instruct-q4_k_m',
    );
  });

  test('[ASK-01] an installed 3B never silently becomes the default LLM; '
      'it is used only when explicitly selected', () {
    const oneB = 'llama-3.2-1b-instruct-q4_k_m';
    final now = DateTime.utc(2026, 10, 17);
    final access = FeatureAccess.resolve(
      Entitlement.free(now),
      now: now,
      mode: DistributionMode.personal,
    );
    expect(access.has(Feature.largeLlm), isTrue);
    InstalledModelInfo inst(String id) {
      final c = catalog.byId(id)!;
      return InstalledModelInfo(
        id: id,
        kind: EngineModelKind.llm,
        sizeBytes: c.size,
        file: c.file,
      );
    }

    String? active(List<String> ids, {String? preferred}) => selectActiveModels(
      installed: [for (final i in ids) inst(i)],
      access: access,
      catalog: catalog,
      device: _device(7.3),
      preferredLlm: preferred,
    ).llm;

    expect(active([oneB, _id]), oneB);
    expect(active([oneB, _id], preferred: _id), _id);
    expect(active([_id]), _id, reason: 'only model installed');
    final bundle = recommendBundle(
      _device(7.3),
      catalog,
      LlmPlanGate(largeLlm: () => true),
    );
    expect(bundle.models.map((e) => e.id), isNot(contains(_id)));
  });
}

bool _no() => false;
bool _yes() => true;
