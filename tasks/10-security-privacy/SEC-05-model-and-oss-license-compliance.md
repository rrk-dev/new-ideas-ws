# SEC-05 — Model & Open-Source License Compliance

**Workstream:** Security & Privacy | **Phase:** 2–4 | **Size:** S | **Depends on:** LLM-08, STT-07 | **Source:** Gap
**Status:** todo
**Skills:** vv-task-workflow, vv-privacy-security, vv-model-delivery

## Goal
Every redistributed model and library is used within its license, with required attributions in-app.

## Scope
- [ ] Llama 3.2 Community License: "Built with Llama" attribution, acceptable-use policy, redistribution terms; note EU restrictions on Llama 3.2 multimodal (text models OK — verify).
- [ ] Gemma Terms of Use: prohibited-use policy pass-through.
- [ ] Whisper (MIT), whisper.cpp / llama.cpp (MIT), VAD/diarization models (check each — some pyannote models are gated / non-commercial).
- [ ] Generate OSS license screen (`LicenseRegistry` + native libs + models).
- [ ] Record license id per model in manifest (MDL-01).

## Acceptance Criteria
- License inventory `docs/licenses.md` complete and reviewed; in-app About screen lists all.
