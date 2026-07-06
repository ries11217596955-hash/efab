# Controlled Runtime Structured Generator Diversity Review V1

Status: STRUCTURED_GENERATOR_DIVERSITY_REPAIR_PASS

The prior 30000 diversity proof showed `NORMALIZED_LOW` because the synthetic generator produced template-repeated payloads after volatile fields were removed. This review records the local controlled-runtime repair: `StructuredV1` candidate generation.

`StructuredV1` varies retained semantic fields across families such as proof, memory, source, action, quarantine, dedup, cleanup, checkpoint, mode, autonomy, external material, owner control, failure handling, and capability map. The generated candidates remain ephemeral fuel and are accepted through the existing D2B runner path with RuntimeDeltaOnly active.

The bounded 3000-candidate trial passed, kept tracked accepted-core files clean, and left `runtime_ready=false`.

Decision: generator diversity repaired locally for controlled runtime.

Next required: RUN_STRUCTURED_30000_STRESS_OR_KNOWLEDGE_BOOTSTRAP_PLAN
