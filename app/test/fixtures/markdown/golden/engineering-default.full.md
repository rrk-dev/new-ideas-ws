---
title: "Sync engine design"
date: 2026-10-13
time: "14:05"
duration: "1h 02m"
type: "engineering"
tags: ["work", "planning"]
source: vaultvoice
recording_id: "0f8d2c1e-7a5b-4c3d-9e1f-2a3b4c5d6e7f"
consent_at: "2026-10-13T12:04:30+00:00"
---

# Sync engine design

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

| Option | Pros | Cons |
| --- | --- | --- |
| CRDT | No conflicts; Offline first | Metadata overhead |
| Last write wins | Simple | Loses edits; Clock skew |

## Decisions

- Prototype with a CRDT library

## TODOs

- [ ] Benchmark CRDT size (@Lena) [00:03:10]

## Open Questions

- How large do tombstones get?

![[attachments/rec-1.m4a]]

---

_Generated on-device by VaultVoice · 1h 02m._
