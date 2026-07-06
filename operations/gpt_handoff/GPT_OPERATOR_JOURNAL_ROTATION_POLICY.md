# GPT Operator Journal Rotation Policy

Status: ACTIVE_RULE

## Problem

`operations/gpt_handoff/GPT_OPERATOR_JOURNAL.md` became a 1.67 GB active file after full-file read/write normalization and encoding corruption. It caused OutOfMemoryException and made the journal unusable as active memory.

## Hard rules

- Do not use full-file raw reads on large active journals.
- Do not normalize the whole active journal in-place.
- Do not paste raw command logs, proof dumps, source answers, or full reports into the journal.
- Journal entries are pointers, not archives.
- If more detail is needed, create a focused compact note under `operations/autonomy_diagnostics/` or the relevant organ directory.

## Size gates

- soft limit: 128 KB
- hard limit: 256 KB
- if hard limit is reached: rotate immediately

## Rotation shape

```text
GPT_OPERATOR_JOURNAL.md              # active compact pointer only
GPT_OPERATOR_JOURNAL_YYYYMMDD.md     # compact rotated pointer, not raw dump
```

## Source/proof storage

Proofs stay in their proof directories. The journal stores only path/hash/status pointers.

## Encoding rule

When writing journal files from PowerShell, use explicit UTF-8 and avoid full-file rewrites.

Allowed append method: `[System.IO.File]::AppendAllText(path, compactEntry, [Text.UTF8Encoding]::new($false))`.