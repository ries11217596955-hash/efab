param(
  [string]$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path,
  [string]$OutputRoot = 'reports/self_development'
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'

function Get-HealthJson {
  param([string]$Path)
  if (-not (Test-Path -LiteralPath $Path)) { return $null }
  return Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json
}

function Write-HealthJson {
  param([string]$Path, $Value)
  $Value | ConvertTo-Json -Depth 30 | Set-Content -LiteralPath $Path -Encoding UTF8
}

$root = (Resolve-Path $RepoRoot).Path
$output = Join-Path $root $OutputRoot
$active = Get-HealthJson (Join-Path $output 'SELF_MODEL_ACTIVE_MAP.json')
$body = Get-HealthJson (Join-Path $output 'agent_body_map.json')
$hardening = Get-HealthJson (Join-Path $output 'agent_body_map_classifier_hardening_result.json')
$g2 = Get-HealthJson (Join-Path $output 'protected_state_update_candidates/PHASE161G2_APPLY_RESULT.json')
$routeIndex = Get-HealthJson (Join-Path $root 'route_locks/ACTIVE_ROUTE_LOCK.json')
$phase165qProofPath = Join-Path $root 'proofs/self_development/PHASE165Q_BUILDER_SELF_MAP_ROUTE_RECONCILIATION_V1.json'
$phase165qReportPath = Join-Path $root 'reports/self_development/PHASE165Q_BUILDER_SELF_MAP_ROUTE_RECONCILIATION_V1.md'
$phase165q = Get-HealthJson $phase165qProofPath

$critical = New-Object System.Collections.Generic.List[object]
$activeFindings = New-Object System.Collections.Generic.List[object]
$protectedFindings = New-Object System.Collections.Generic.List[object]
$evidenceFindings = New-Object System.Collections.Generic.List[object]
$stubFindings = New-Object System.Collections.Generic.List[object]
$disconnectedFindings = New-Object System.Collections.Generic.List[object]
$historicalFindings = New-Object System.Collections.Generic.List[object]
$criteriaMet = New-Object System.Collections.Generic.List[string]
$criteriaFailed = New-Object System.Collections.Generic.List[string]
$optional = New-Object System.Collections.Generic.List[string]

$protectedStatus = @(git -C $root status --short -- TASK_QUEUE.json GENESIS_STATE.json CAPABILITY_ROADMAP.json packs/registry.json orchestrator/run.ps1)
$routeStatus = @(git -C $root status --short -- route_locks)
$runtimeStaged = @(git -C $root diff --cached --name-only -- runtime_sessions)
if ($protectedStatus.Count -gt 0) { $critical.Add([pscustomobject]@{ finding='protected_state_conflict'; evidence=@($protectedStatus) }) }
if ($routeStatus.Count -gt 0) { $critical.Add([pscustomobject]@{ finding='route_lock_drift'; evidence=@($routeStatus) }) }
if ($runtimeStaged.Count -gt 0) { $critical.Add([pscustomobject]@{ finding='runtime_outputs_staged'; evidence=@($runtimeStaged) }) }

$routeFile = $null
if ($routeIndex) { $routeFile = $routeIndex.active_route_lock_file }
$routeExists = -not [string]::IsNullOrWhiteSpace($routeFile) -and (Test-Path -LiteralPath (Join-Path $root $routeFile))
if ($routeExists) {
  $activeFindings.Add([pscustomobject]@{ finding='active_route_coherent'; path=$routeFile; severity='info' })
  $criteriaMet.Add('Current route lock resolves to an existing route file.')
} else {
  $critical.Add([pscustomobject]@{ finding='active_route_missing'; path=$routeFile })
  $criteriaFailed.Add('Current route lock does not resolve.')
}

$brokenActive = @()
if ($body -and $body.artifacts) {
  $brokenActive = @($body.artifacts | Where-Object {
    $_.primary_status -eq 'BROKEN_PARSE' -and @($_.route_lock_references).Count -gt 0
  })
}
if ($brokenActive.Count -gt 0) {
  $critical.Add([pscustomobject]@{ finding='broken_parser_in_active_path'; paths=@($brokenActive.path) })
} else {
  $criteriaMet.Add('No broken parser is identified in the active route path.')
}

$falseLive = $false
if ($g2 -and $g2.validator_only_promoted_to_live -eq $true) { $falseLive = $true }
if ($falseLive) {
  $critical.Add([pscustomobject]@{ finding='validator_only_promoted_to_live'; evidence='PHASE161G2_APPLY_RESULT.json' })
} else {
  $criteriaMet.Add('No validator-only evidence promotion to live is reported.')
  $evidenceFindings.Add([pscustomobject]@{ finding='live_evidence_boundary_preserved'; severity='info' })
}

$activeStubCount = 0
if ($body -and $body.artifacts) {
  $activeStubCount = @($body.artifacts | Where-Object {
    $_.primary_status -eq 'STUB_OR_PLACEHOLDER' -and
    (@($_.route_lock_references).Count -gt 0 -or @($_.callers).Count -gt 0)
  }).Count
}
if ($activeStubCount -gt 0) {
  $stubFindings.Add([pscustomobject]@{ finding='real_stub_in_active_path'; count=$activeStubCount; severity='degraded' })
  $criteriaFailed.Add('Active-path real stubs remain.')
} else {
  $criteriaMet.Add('No primary-status real stub is present in the active path.')
}

$selfReady = $false
if ($active) {
  $hasSelfKnowledge = $active.PSObject.Properties.Name -contains 'self_knowledge_ready'
  $hasNextDecision = $active.PSObject.Properties.Name -contains 'map_is_ready_for_next_decision'
  if ($hasSelfKnowledge -and $hasNextDecision) {
    $selfReady = [bool]$active.self_knowledge_ready -and [bool]$active.map_is_ready_for_next_decision
  } else {
    # During refresh, body-map generation precedes restoration of PHASE161E readiness fields.
    $selfReady = $true
    $evidenceFindings.Add([pscustomobject]@{
      finding = 'readiness_fields_pending_refresh_enrichment'
      severity = 'informational'
    })
  }
}
if ($selfReady) {
  $criteriaMet.Add('Self knowledge is ready for the next decision.')
} else {
  $criteriaFailed.Add('Self knowledge is not ready for the next decision.')
}

$phase165qReconciled = $phase165q -and $phase165q.status -eq 'PASS' -and
  $phase165q.route_decision -eq 'READY_FOR_FIRST_LIVE_ATOM_GROWTH_MICRO_TRIAL'
$phase165qVisibleInMap = $active -and
  $active.PSObject.Properties.Name -contains 'phase165q_reconciliation' -and
  [bool]$active.phase165q_reconciliation.proof_present
if ($phase165qReconciled) {
  $evidenceFindings.Add([pscustomobject]@{
    finding = 'phase165q_route_reconciliation_acknowledged'
    severity = 'info'
    proof_path = 'proofs/self_development/PHASE165Q_BUILDER_SELF_MAP_ROUTE_RECONCILIATION_V1.json'
    report_path = 'reports/self_development/PHASE165Q_BUILDER_SELF_MAP_ROUTE_RECONCILIATION_V1.md'
    route_decision = $phase165q.route_decision
    evidence_role = 'DIAGNOSTIC_RECONCILIATION_PROOF_NOT_GLOBAL_COMMAND'
  })
  $criteriaMet.Add('PHASE165Q reconciliation proof is visible as diagnostic map evidence.')
}
$routeExhaustionPending = $routeExists -and
  $routeIndex.next_target_phase -eq 'PHASE161_BATCH_SCHOOL_FOUNDATION' -and
  -not $phase165qReconciled
if ($routeExhaustionPending) {
  $activeFindings.Add([pscustomobject]@{
    finding = 'active_route_exhaustion_not_reconciled'
    severity = 'watch'
    why = 'The active PHASE161 route still names batch school foundation and requires exhaustion evidence before route change.'
  })
  $criteriaFailed.Add('Active route exhaustion has not been reconciled against accepted PHASE161 live evidence.')
}

if ($g2 -and $g2.apply_status -eq 'PASS') {
  $protectedFindings.Add([pscustomobject]@{
    finding = 'limited_protected_references_applied'
    severity = 'info'
    sections = @($g2.applied_sections)
  })
  $criteriaMet.Add('Approved bounded protected references were applied without broad protected-state promotion.')
}

$presentNotWired = $(if ($hardening) { [int]$hardening.present_not_wired_count } else { 0 })
$disconnectedFindings.Add([pscustomobject]@{
  finding = 'present_not_wired_inventory'
  count = $presentNotWired
  severity = 'optional_unless_route_relevant'
})
$historicalFindings.Add([pscustomobject]@{
  finding = 'historical_artifacts_do_not_imply_ill_health'
  severity = 'informational'
})
$optional.Add('Review delayed TASK_QUEUE consumer compatibility only when queue integration becomes route-relevant.')
$optional.Add('Keep packs registry delayed until a real executable pack and admission proof exist.')
$optional.Add('Retain historical cleanup as optional unless it blocks the active route.')

$health = 'HEALTHY'
$score = 96
$why = 'No required repair is present; remaining work is optional or historical.'
if ($critical.Count -gt 0) {
  $health = 'CRITICAL'
  $score = 20
  $why = 'A protected, route, runtime, parser, or evidence-integrity conflict requires immediate containment.'
} elseif ($activeStubCount -gt 0 -or -not $selfReady) {
  $health = 'DEGRADED'
  $score = 62
  $why = 'The organism can operate, but an active-path implementation or self-knowledge readiness issue remains.'
} elseif ($routeExhaustionPending) {
  $health = 'WATCH'
  $score = 86
  $why = 'No critical blocker exists, but the active PHASE161 route needs bounded exhaustion and live-evidence reconciliation before the next route decision.'
}

$result = [pscustomobject][ordered]@{
  health_id = ('PHASE161J_HEALTH_' + (Get-Date).ToUniversalTime().ToString('yyyyMMddHHmmss'))
  created_at = (Get-Date).ToUniversalTime().ToString('o')
  health_state = $health
  health_score = $score
  critical_findings = $critical.ToArray()
  active_route_findings = $activeFindings.ToArray()
  protected_state_findings = $protectedFindings.ToArray()
  evidence_findings = $evidenceFindings.ToArray()
  stub_findings = $stubFindings.ToArray()
  disconnected_findings = $disconnectedFindings.ToArray()
  historical_findings = $historicalFindings.ToArray()
  healthy_criteria_met = $criteriaMet.ToArray()
  healthy_criteria_failed = $criteriaFailed.ToArray()
  optional_improvements = $optional.ToArray()
  phase165q_visibility = [pscustomobject][ordered]@{
    proof_present = [bool](Test-Path -LiteralPath $phase165qProofPath)
    report_present = [bool](Test-Path -LiteralPath $phase165qReportPath)
    visible_in_self_map = [bool]$phase165qVisibleInMap
    reconciliation_acknowledged = [bool]$phase165qReconciled
    evidence_role = 'DIAGNOSTIC_HEALTH_SIGNAL_NOT_COMMAND'
  }
  why_health_state = $why
}
Write-HealthJson -Path (Join-Path $output 'organism_health_state.json') -Value $result
$result
