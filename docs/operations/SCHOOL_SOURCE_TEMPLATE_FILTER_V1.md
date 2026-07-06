# School Source Template Filter V1

Status: ACTIVE_MINIMAL_SELECTOR_LAYER

## Purpose

Select a bounded school source route and query template before source ports are used.

## Boundary

The template filter is not the school brain, not proof, not accepted memory, and not a web truth engine. It decides source route and query constraints only.

## V1 decision path

```text
factory metrics + source need
-> choose InternalFactory / CodexSourcePort / ExternalWorldSourcePort
-> produce query template and source ladder constraints
-> source ports still validate material
-> school validators still decide candidate readiness
```

## Hard rules

```text
sponsored/ad = reject
SEO/content farm = reject or quarantine
official docs preferred for technical/current behavior
forum/blog cannot be primary proof
high authority score means better candidate source, not truth
```

## Router Auto integration

When School Source Router runs with `SourceMode=Auto`, it may call Template Filter first. The filter returns a selected source and reason. The router still enforces `enabled_sources`; a filter decision cannot open Codex or ExternalWorld by itself.

```text
Auto
-> Template Filter decision
-> router enabled_sources gate
-> selected source port
```

This preserves safety: Template Filter recommends route, Source Router authorizes route.
