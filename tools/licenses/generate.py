#!/usr/bin/env python3
"""Regenerate resolved pub license inventory after flutter pub get/deps."""
import hashlib
import json
from pathlib import Path
import subprocess
from urllib.parse import urljoin, urlparse, unquote

ROOT = Path(__file__).resolve().parents[2]
app = ROOT / 'app'
deps = json.loads(subprocess.check_output(['fvm', 'flutter', 'pub', 'deps', '--json'], cwd=app))
config_path = app / '.dart_tool/package_config.json'
config = json.loads(config_path.read_text())
paths = {p['name']: Path(unquote(urlparse(urljoin(config_path.as_uri(), p['rootUri'])).path)) for p in config['packages']}
rows = []
for p in sorted(deps['packages'], key=lambda p: p['name']):
    if p['kind'] == 'root':
        continue
    base = paths[p['name']]
    files = sorted(f for f in base.iterdir() if f.is_file() and f.name.upper().startswith(('LICENSE', 'COPYING')))
    if not files and p['source'] == 'sdk':
        files = [base.parents[1] / 'LICENSE']
    # vv_native is first-party code, covered by the app distribution terms.
    if not files and p['name'] != 'vv_native':
        raise RuntimeError(f"Missing license: {p['name']}")
    text = '\n\n'.join(f.read_text() for f in files) if files else 'VaultVoice first-party native bridge; app distribution terms apply.'
    rows.append(dict(name=p['name'], version=p['version'], kind=p['kind'], source=p['source'], license_text=text, sha256=hashlib.sha256(text.encode()).hexdigest()))
(ROOT / 'app/assets/licenses/pub_inventory.json').write_text(json.dumps(rows, indent=2) + '\n')
header = (ROOT / 'tools/licenses/inventory-header.md').read_text()
models = json.loads((app/'assets/catalog/catalog.json').read_text())['models']
body = '\n'.join(f"- `{p['name']}` {p['version']} ({p['kind']}, {p['source']}): notice SHA-256 `{p['sha256']}`." for p in rows)
body += '\n\n## Catalog snapshot\n\n' + '\n'.join(f"- `{m['id']}`: [{m['license']}]({m['license_url']}); attribution: {m['attribution'] or 'upstream copyright retained in bundled notice'}." for m in models)
(ROOT/'docs/licenses.md').write_text(header + '\n## Resolved pub inventory\n\n' + body + '\n')
print(f'{len(rows)} package notices generated')
