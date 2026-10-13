# tools/model-catalog — build and sign the model catalog (MDL-01)

`catalog.py` turns `models.json` (the human-edited source) into the signed catalog the app
trusts: `catalog.json` + `catalog.json.sig`. Format: `catalog.schema.json` and ADR-MDL-01.

**Dependency:** Python 3.10+ and pyca `cryptography` (Ed25519):
`python3 -m pip install cryptography==46.0.3`. Everything else is stdlib.
Tests: `python3 -m pytest tools/model-catalog/tests -q` (CI job `task-gate`).

## Keys — never in the repository
- Generate: `python3 tools/model-catalog/catalog.py keygen --out ~/secure/vv-catalog.pem`
  (PKCS#8 PEM, mode 0600; refuses to write inside a git work tree or over an existing file).
  Prints the base64 public key and its `key_id`.
- Use: `--key-file PATH`, or `VV_CATALOG_SIGNING_KEY_FILE=PATH`, or
  `VV_CATALOG_SIGNING_KEY=<PEM or base64 32-byte seed>` (CI secret; never echo it).
- Pin: put the base64 public key in `app/lib/features/models/domain/catalog_keys.dart`
  (max two keys). Rotation: ship an app with old + new key → sign with the new key → drop the
  old key in a later release.
- The committed bundled catalog is signed with the **development** key `vv-catalog-dev-2026a`
  (key_id `c6ced0f07343ec41`). Its private half is not in the repo; if you need to re-sign and
  do not have it, generate a new dev key and replace the pinned key + re-sign (pre-release only).
  The production key is an owner decision (ADR-MDL-01 → Open).

## Add or update a model
```bash
python3 tools/model-catalog/catalog.py hash ~/Downloads/ggml-base.en-q5_1.bin   # sha256 + size
# edit tools/model-catalog/models.json (urls: our CDN first, then pinned-revision mirrors;
# every host must be in app/lib/core/network/model_hosts.dart)
python3 tools/model-catalog/catalog.py build --models tools/model-catalog/models.json \
  --out app/assets/catalog/catalog.json            # issued_at = now (UTC); must increase
python3 tools/model-catalog/catalog.py sign --catalog app/assets/catalog/catalog.json \
  --key-file ~/secure/vv-catalog.pem
python3 tools/model-catalog/catalog.py verify --catalog app/assets/catalog/catalog.json \
  --sig app/assets/catalog/catalog.json.sig --pubkey <base64 pinned key>
```
Never hand-edit `catalog.json` after signing: the signature covers the exact bytes
(`.gitattributes` marks the files binary). Publish the same two files to
`https://<cdn>/catalog/v1/` for online refresh. Each new catalog needs a later `issued_at`
than the one apps already accepted, or apps reject it as a rollback.
