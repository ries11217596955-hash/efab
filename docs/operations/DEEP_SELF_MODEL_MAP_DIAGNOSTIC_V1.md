# Deep Self-Model Map Diagnostic V1

status: DIAGNOSTIC_COMPLETE_RECOMMEND_TWO_MAP_ORGANS_WITH_THIN_SELF_MODEL_LINK

## Finding

There is already a canonical body/composition map. It should remain responsible for what exists, what each organ is, status, and proof boundaries.

The capability/skill side exists mostly as material: `CAPABILITY_ROADMAP.json`, `tasks/*.json`, validators, and scripts. It is not yet a mature canonical invocation map.

## Recommendation

Do not merge everything into one big organ. Keep two map organs and add a thin self-model link between them:

1. Body / Organ Inventory Map: what organs exist and what they are responsible for.
2. Capability Invocation Map: what can be done and exactly how to run/validate it.
3. Deep Self Model Index: cross-links organs to capabilities and checks contradictions.

## Capability map quality now

- task JSON count: 112
- has mode: 33/112
- has inputs: 0/112
- has outputs: 0/112
- has validator: 11/112
- has command-like data: 64/112
- has proof-like data: 86/112

## What not to delete now

Do not delete legacy self-knowledge, capability roadmap, genesis state, or task contracts yet. First build a canonical capability invocation map and migration validator.

## Best next move

Create `CAPABILITY_INVOCATION_MAP_V1` contract and validator, then generate a draft map from current tasks and validators.
