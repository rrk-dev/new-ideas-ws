# Device / lab verification — PRF-05

Rows need real models and devices that were unavailable when this was authored.

| AC | Steps | Expected | Device | OS | Result | Date | Tester |
|---|---|---|---|---|---|---|---|
| [PRF-05/AC1] | Run `make eval PROFILE=engineering` with a 3B-class model on a lab device. | TODO recall ≥ 80 %, trade-offs paired ≥ 70 %. | Lab device | — | | | |
| [PRF-05/AC2] | Run `tools/ci/markdownlint.sh` (needs npx) over the engineering goldens. | No markdownlint findings. | Any host with node | — | | | |
