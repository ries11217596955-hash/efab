# FACTORY_MEMORY_AND_LADDER_LEDGER_V1

Status: LAB_IMPLEMENTED
Runtime ready: false

## Purpose

The local curriculum factory must not only create run-scoped unique candidates. It must remember what the active repo-body already contains, select weaker coverage areas first, and report whether generated batches add at least weak new learning surface.

## Memory surfaces

```text
memory/factory_ledger.jsonl
memory/coverage_map.json
memory/prerequisite_graph.json
memory/factory_memory_ladder_report.json
```

## Ladder contract

A factory atom has:

```text
root
verb
level 1..5
source_mode
learning_key = verb|root|level|source_mode
prerequisite_key = verb|root|level-1|source_mode when level > 1
```

Level is not enough by itself. The ladder proof must show which prerequisite is being strengthened and whether the generated run adds new or undercovered learning keys.

## Boundary

This is factory memory and lab validation only. It does not promote active memory and does not prove live runtime learning.