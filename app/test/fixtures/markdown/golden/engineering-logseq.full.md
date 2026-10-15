title:: Sync engine design
type:: engineering
date:: [[2026-10-13]]
time:: 14:05
duration:: 1h 02m
tags:: [[work]] [[planning]]
source:: vaultvoice
recording-id:: 0f8d2c1e-7a5b-4c3d-9e1f-2a3b4c5d6e7f

- **Context**
  - Offline edits conflict when two devices change one note.
- **Concepts**
  - CRDT
  - Vector clocks
- **API Designs**
  - **SyncService**
    - Merges local and remote change sets.
    - Future\<void> push(ChangeSet set)
    - Stream\<ChangeSet> pull()
- **Trade-offs**
  - **CRDT**
    - Pro: No conflicts
    - Pro: Offline first
    - Con: Metadata overhead
  - **Last write wins**
    - Pro: Simple
    - Con: Loses edits
    - Con: Clock skew
- **Decisions**
  - Prototype with a CRDT library
- **TODOs**
  - TODO Benchmark CRDT size (@Lena) [00:03:10]
- **Open Questions**
  - How large do tombstones get?
- Generated on-device by VaultVoice · 1h 02m
