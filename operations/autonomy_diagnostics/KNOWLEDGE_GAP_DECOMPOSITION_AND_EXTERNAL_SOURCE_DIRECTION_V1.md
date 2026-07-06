# Knowledge gap, decomposition, and outside source direction V1

Status: STRATEGY_SUPPORTED / NOT_IMPLEMENTED

## Rule 1: knowledge gap for X

If AIMO wants to perform step X and active memory does not contain executable knowledge for X, it must not force unrelated memory Y onto X.

Instead, memory mismatch becomes:

```text
KNOWLEDGE_GAP_FOR_X
```

The next action is to search for the missing knowledge needed for X.

## Rule 2: recursive decomposition

If X is too large or unknown, AIMO should decompose X into smaller parts:

- concept parts
- action parts
- object parts
- tool parts
- validation/proof parts

Each unknown part can be decomposed again, with a finite focus budget and mandatory return-to-parent.

## Owner sequencing correction

Deep decomposition should not be wired into the motor before AIMO has a governed way to go outside its current memory.

Otherwise decomposition can become internal word-chewing:

```text
I do not know X -> split X -> still do not know parts -> split forever
```

Correct sequence:

```text
missing knowledge -> decompose -> source lookup -> learn/understand part -> return-to-parent -> retry X
```

## Outside source direction

Needed next organ/port candidate:

```text
OUTSIDE_SOURCE_PORT / KNOWLEDGE_ACQUISITION_PORT
```

But outside does not mean uncontrolled web or free live action. It means a governed source ladder:

1. active compact memory
2. reflex registry
3. repo/spec/map/policy
4. internal library/source pack
5. school/learning task
6. web/source port later, policy-gated and proof-gated

## Boundary

- Not implemented yet.
- Do not wire deep recursive decomposition until source lookup exists.
- Do not give the motor uncontrolled web/Codex/shell authority.
- The port must return compact source proof and learning trace.
