# Device / lab verification — PRF-06

Rows need real models and devices that were unavailable when this was authored.

| AC | Steps | Expected | Device | OS | Result | Date | Tester |
|---|---|---|---|---|---|---|---|
| [PRF-06/AC1] | Run the mixed 90-case set through `ProfileClassifier` with the shipped LLM (keyword stage + LLM). | ≥ 90 % correct profile. | Lab device | — | | | |
| [PRF-06/AC2] | Time the classify step on a mid-tier phone (≈1500-token sample). | < 10 s added. | Mid-tier Android + iPhone | — | | | |
