---
inclusion: always
---

# Firestore Cost Optimization Rule

Whenever modifying or building any feature in this app, actively look for
unnecessary Firestore reads and writes. The goal is to reduce Firestore
usage wherever safely possible WITHOUT changing existing app behavior or
data correctness.

## Before changing anything, identify:

- Why the read/write exists
- What triggers it
- How frequently it happens
- Whether the same data is already available locally
- Whether multiple screens are requesting the same data
- Whether a real-time listener is actually necessary
- Whether the same document is being written repeatedly
- Whether a write can safely be avoided, batched, debounced, or moved to a
  meaningful state change

## Prefer, where appropriate:

- Shared repository/cache instead of duplicate reads
- Reusing already-loaded data
- In-memory state when appropriate
- Persistent local cache when appropriate
- One shared listener instead of multiple listeners
- Querying only the required documents
- Querying only the required fields/data where supported
- Avoiding reads triggered by unnecessary widget rebuilds
- Avoiding writes when the value has not actually changed
- Debouncing rapidly changing writes
- Batching related writes where safe
- Writing only on meaningful state changes
- Keeping daily/session values locally when they don't need to be
  persisted continuously

## DO NOT:

- Remove required Firestore synchronization
- Introduce stale data
- Change Firestore schema unnecessarily
- Change security rules unnecessarily
- Break multi-device synchronization
- Move important source-of-truth data entirely to local storage
- Change user-visible behavior
- Optimize at the expense of data correctness

## For every feature modified:

1. Identify its Firestore reads.
2. Identify its Firestore writes.
3. Identify duplicate/unnecessary operations.
4. Make only safe optimizations.
5. Verify the feature still behaves exactly the same.
6. Report what reads/writes were reduced and why.

If there is no safe optimization, leave it alone.

## Scope

Only optimize code relevant to the current task unless explicitly asked
for a full Firestore cost audit. Do not modify unrelated features just
because they use Firestore.
