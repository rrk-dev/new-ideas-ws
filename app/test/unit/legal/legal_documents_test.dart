import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vaultvoice/core/l10n/l10n.dart';
import 'package:vaultvoice/core/network/model_hosts.dart';
import 'package:vaultvoice/features/legal/domain/legal_documents.dart';

String _read(String path) => File(path).readAsStringSync();

/// Hard-wrapped Markdown lines joined, so phrases can be matched.
String _flat(String s) => s.replaceAll(RegExp(r'\s+'), ' ');

void main() {
  final terms = _read(kTermsAsset);
  final privacy = _read(kPrivacyAsset);

  group('[LEG-01/AC1] documents', () {
    test('[LEG-01/AC1] the Terms carry every required section', () {
      for (final needle in [
        '## Summary in plain language',
        'You must be 21 or older',
        'at least 21 years old',
        'You alone are responsible',
        'all-party',
        'one-party',
        'does not record phone or VoIP calls',
        'only after you tap Record',
        'Your content stays yours',
        'indemnify',
        'as is',
        'Limit of liability',
        'INR 1,000',
        'USD 10',
        'fraud',
        'third-party beneficiaries',
        'Governing law and courts',
        'laws of India',
        '[CITY, INDIA]',
        'we do not use arbitration',
        'Export controls and sanctions',
        'Events outside our control',
        'Entire agreement',
        'Severability',
        'AI output can be wrong',
        'lumen@lumensupport.org',
        'Lumen LLC',
        'Open-source & model',
        'Backups, data loss',
      ]) {
        expect(
          _flat(terms).toLowerCase(),
          contains(needle.toLowerCase()),
          reason: needle,
        );
      }
      expect(terms, isNot(contains('18 years')));
    });

    test('[LEG-01/AC1] the Privacy Policy carries every required section', () {
      for (final needle in [
        'Digital Personal Data Protection Act, 2023',
        'GDPR',
        'CCPA',
        'To the extent',
        'lumen@lumensupport.org',
        '21',
        'Apple Reminders',
        'iCloud',
        'Delete all data',
        'Changes to this policy',
      ]) {
        expect(_flat(privacy), contains(needle), reason: needle);
      }
    });

    test('[LEG-01/AC1] both documents start with the draft banner and carry '
        'the same version as the code', () {
      for (final doc in [terms, privacy]) {
        expect(doc, startsWith('[//]: # ($kDraftBannerMarker'));
        expect(
          doc,
          contains(
            '> **DRAFT — requires review by a qualified '
            'lawyer before release**',
          ),
        );
        expect(legalDocumentVersion(doc), kLegalVersion);
      }
    });

    test('[LEG-01/AC1] neither document uses the old product name', () {
      expect(terms + privacy, isNot(contains('VaultVoice')));
    });
  });

  group('[LEG-01/AC6] release flag and policy truthfulness', () {
    test('[LEG-01/AC6] the release flag removes only the draft banner', () {
      final shown = legalDisplayText(terms);
      expect(shown, terms);
      final hidden = legalDisplayText(terms, released: true);
      expect(hidden, isNot(contains('DRAFT')));
      expect(hidden, isNot(contains(kDraftBannerMarker)));
      expect(hidden, startsWith('# Terms of Use'));
      expect(
        legalDisplayText(privacy, released: true),
        startsWith('# Privacy'),
      );
    });

    test('[LEG-01/AC6] the policy states no analytics, advertising or crash '
        'reporting and no data collected', () {
      final text = _flat(privacy).toLowerCase();
      expect(text, contains('no data is collected'));
      expect(text, contains('no analytics'));
      expect(text, contains('no advertising'));
      expect(text, contains('crash-reporting service'));
      expect(text, contains('no account'));
      expect(text, contains('does not record phone or voip calls'));
      for (final lie in [
        'we collect your',
        'we share your',
        'we sell your',
        'third-party analytics',
        'advertising partners',
      ]) {
        expect(text, isNot(contains(lie)), reason: lie);
      }
    });

    test('[LEG-01/AC6] the policy lists every allowlisted model host', () {
      for (final host in {...kModelHosts, ...kModelRedirectHosts}) {
        expect(privacy, contains('`$host`'), reason: host);
      }
    });
  });

  test(
    '[LEG-01/AC5] the in-app disclaimer equals docs/legal/disclaimers.md',
    () {
      final l10n = lookupAppLocalizations(const Locale('en'));
      final docs = _read('../docs/legal/disclaimers.md');
      final rows = <String, String>{};
      for (final m in RegExp(
        r'^\| `(\w+)` \| [^|]+ \| ([^|]+) \|$',
        multiLine: true,
      ).allMatches(docs)) {
        rows[m.group(1)!] = m.group(2)!.trim();
      }
      expect(rows['aiOutputDisclaimer'], l10n.aiOutputDisclaimer);
      expect(rows['legalAgeConfirm'], l10n.legalAgeConfirm);
      expect(rows['legalAgreeConfirm'], l10n.legalAgreeConfirm);
      expect(
        rows['legalRecordingResponsibility'],
        l10n.legalRecordingResponsibility,
      );
    },
  );

  test('[LEG-01/AC6] the legal assets are registered and no network code '
      'is in the legal feature', () {
    expect(_read('pubspec.yaml'), contains('assets/legal/'));
    for (final f
        in Directory('lib/features/legal')
            .listSync(recursive: true)
            .whereType<File>()
            .where((f) => f.path.endsWith('.dart'))) {
      final src = f.readAsStringSync();
      expect(src, isNot(contains('dart:io')), reason: f.path);
      expect(src, isNot(contains('url_launcher')), reason: f.path);
      expect(src, isNot(contains('http')), reason: f.path);
    }
  });
}
