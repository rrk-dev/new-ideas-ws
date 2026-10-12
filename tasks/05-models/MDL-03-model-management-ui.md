# MDL-03 — Model Management Screen

**Workstream:** Model Delivery | **Phase:** 3 | **Size:** S | **Depends on:** MDL-02, LLM-07, LIC-01 | **Source:** Gap
**Status:** todo
**Skills:** vv-task-workflow, vv-model-delivery, vv-flutter-architecture, vv-licensing-iap, vv-testing

## Goal
Users see installed/available models, disk usage and can swap or delete them.

## Scope
- [ ] List models by type with size, tier, Pro badge, device-compatibility indicator.
- [ ] Download / delete / set-as-default actions.
- [ ] Total storage used by models, audio, transcripts.
- [ ] Update notification when a newer model version appears in the manifest.

## Acceptance Criteria
- Deleting the active model prompts for a replacement and never leaves the pipeline without a usable model.
