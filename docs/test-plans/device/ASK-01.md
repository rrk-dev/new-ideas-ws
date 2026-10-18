# Device verification — ASK-01 Llama 3.2 3B Instruct in the model catalog

Host numbers (Apple M3 Pro, CPU backend): `tools/bench/results/2026-10-17-ask01-1b-vs-3b.md`.
The 3B peaked at ≈ 3.6 GiB RSS on the host (3718 MiB, 4096 context), so the catalog lists it for the
High tier only (`min_ram_mb` 7168); **Mid is not recommended until the Mid row below passes**.
STT and LLM must never be resident together (AGENTS.md → Memory).

| AC | Steps | Expected | Device | OS | Result | Date | Tester |
|---|---|---|---|---|---|---|---|
| [ASK-01/AC4] ⏳ | Settings › Models › Llama 3.2 3B: confirm the large-download dialog shows ≈ 2.0 GB, download on the team network, then run one 30-minute recording through Meeting + Lecture; watch Xcode/Android Studio memory gauge during extraction | Loads, extracts and unloads with no OOM/jetsam kill; peak footprint recorded; whisper unloaded before the LLM loads (never both resident); model unloads after extraction | iPhone 15 Pro / 8 GB (VV-IOS-16) — High tier | iOS 17+ | | | |
| [ASK-01/AC4] ⏳ | Same, with a 6 GB device; record peak footprint and whether the OS kills the app (decides if Mid is ever recommended) | No OOM, or the failure is recorded and Mid stays "not recommended" | 6 GB phone, e.g. iPhone 14 (VV-IOS-14) — Mid tier | iOS 16+ | | | |
| [ASK-01/AC4] ⏳ | Same on Android | Same as above | Android 8 GB flagship (VV-AND-FLG) — High tier; 6 GB device — Mid tier | Android 14+ | | | |
| [ASK-01/AC4] ⏳ | Delete the model from Settings › Models, then import it offline (MDL-04) with the signed single-model manifest from `tools/model-catalog/README.md` | Delete frees ≈ 2.0 GB; import verifies and installs; the model is usable again | Any High-tier device | iOS 17+ / Android 14+ | | | |
| [ASK-01/AC2] ⏳ | On the Cisco corporate network, download the model from Settings › Models; capture the hosts contacted (`tools/ci/check_egress.sh` procedure in `model_hosts.dart`) | Only `huggingface.co` and the redirect host `us.aws.cdn.hf.co` (both already allowlisted) are contacted; download completes and hash verifies | Any device on corporate Wi-Fi/VPN | any | | | |
