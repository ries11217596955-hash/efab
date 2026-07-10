# Organ Promotion Lanes V1

status: PASS_ORGAN_PROMOTION_LANES_V1

Purpose: persistent growth gate. It turns body-map candidate triage into lanes so Builder does not process all candidates manually or promote materials as organs.

Counts:
- source candidates: 151
- lane decisions: 151
- lanes: 8
- fast lane passport draft: 1
- calibrated passport draft blocked runtime: 1
- owner link required: 8
- review lane: 23
- material/archive: 118

Boundary:
- lanes are not organ acceptance.
- no active passport is created.
- no live claim is created.
- no full passport generation for all candidates.
- accepted_atom_retention_organ is calibrated but blocked by missing runtime/micro proof.

Next: restore/regenerate accepted atom micro-proof or continue with remaining fast-lane candidate under same boundary.
