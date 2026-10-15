# Sync engine design

- Date: 2026-10-13 14:05
- Duration: 1h 02m

## Context

Offline edits conflict when two devices change one note.

## Concepts

- CRDT
- Vector clocks

## API Designs

### SyncService

Merges local and remote change sets.

- Future\<void> push(ChangeSet set)
- Stream\<ChangeSet> pull()

## Trade-offs

- CRDT
  - Pro: No conflicts
  - Pro: Offline first
  - Con: Metadata overhead
- Last write wins
  - Pro: Simple
  - Con: Loses edits
  - Con: Clock skew

## Decisions

- Prototype with a CRDT library

## TODOs

- [ ] Benchmark CRDT size (Lena) [00:03:10]

## Open Questions

- How large do tombstones get?
