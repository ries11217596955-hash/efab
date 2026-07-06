param(
  [string]$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path,
  [string]$CandidateRoot = 'reports/self_development/protected_state_update_candidates'
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'

function Assert-BuilderState {
  param([bool]$Condition, [string]$Message)
  if (-not $Condition) { throw $Message }
}

$root = (Resolve-Path $RepoRoot).Path
$candidateFull = Join-Path $root $CandidateRoot
$snapshotFull = Join-Path $candidateFull 'rollback_snapshots/PHASE161G2'
$genesisBefore = Get-Content -LiteralPath (Join-Path $snapshotFull 'GENESIS_STATE.json') -Raw | ConvertFrom-Json
$roadmapBefore = Get-Content -LiteralPath (Join-Path $snapshotFull 'CAPABILITY_ROADMAP.json') -Raw | ConvertFrom-Json
$genesis = Get-Content -LiteralPath (Join-Path $root 'GENESIS_STATE.json') -Raw | ConvertFrom-Json
$roadmap = Get-Content -LiteralPath (Join-Path $root 'CAPABILITY_ROADMAP.json') -Raw | ConvertFrom-Json
$queue = Get-Content -LiteralPath (Join-Path $root 'TASK_QUEUE.json') -Raw | ConvertFrom-Json

Assert-BuilderState ($genesis.PSObject.Properties.Name -contains 'protected_self_model_memory') 'GENESIS_STATE reference missing'
Assert-BuilderState ($roadmap.PSObject.Properties.Name -contains 'phase161e_self_map_auto_refresh') 'CAPABILITY_ROADMAP reference missing'
Assert-BuilderState ($genesis.current_phase -eq $genesisBefore.current_phase) 'current_phase changed'
Assert-BuilderState ($genesis.current_capability -eq $genesisBefore.current_capability) 'current_capability changed'
Assert-BuilderState ($genesis.protected_self_model_memory.evidence_boundary -eq 'DERIVED_MAP_REFERENCE_ONLY') 'GENESIS_STATE evidence boundary changed'
Assert-BuilderState ($roadmap.phase161e_self_map_auto_refresh.status -eq 'ACCEPTED_EVIDENCE_REFERENCE_CANDIDATE') 'Roadmap status is unsafe'
Assert-BuilderState ($roadmap.phase161e_self_map_auto_refresh.protected_promotion_status -eq 'OWNER_REVIEW_REQUIRED') 'Protected promotion status is unsafe'

foreach ($property in $genesisBefore.PSObject.Properties) {
  Assert-BuilderState (($property.Value | ConvertTo-Json -Depth 100 -Compress) -eq ($genesis.($property.Name) | ConvertTo-Json -Depth 100 -Compress)) "GENESIS_STATE field changed: $($property.Name)"
}
foreach ($property in $roadmapBefore.PSObject.Properties) {
  Assert-BuilderState (($property.Value | ConvertTo-Json -Depth 100 -Compress) -eq ($roadmap.($property.Name) | ConvertTo-Json -Depth 100 -Compress)) "CAPABILITY_ROADMAP field changed: $($property.Name)"
}

$blockedExpected = [ordered]@{
  'TASK_QUEUE.json' = '27220D7E169EDA9E60341B4A7A2817D3515DE8C8BB11DFC7C841A941FC01C4EC'
  'packs/registry.json' = 'C3BBD8313FA46CA80298154964DC82431DB60525C485207C40D8059F8F88F760'
  'orchestrator/run.ps1' = '51AA1CBEB0339B2DF0CBA84606E414D9DFA7395DED7179CC5248B3C4BC5CC91D'
}
foreach ($path in $blockedExpected.Keys) {
  Assert-BuilderState ((Get-FileHash -LiteralPath (Join-Path $root $path) -Algorithm SHA256).Hash -eq $blockedExpected[$path]) "Blocked file changed: $path"
}

$manifest = Get-Content -LiteralPath (Join-Path $candidateFull 'PHASE161G2_ROLLBACK_SNAPSHOT_MANIFEST.json') -Raw | ConvertFrom-Json
foreach ($route in $manifest.route_lock_hashes) {
  Assert-BuilderState ((Get-FileHash -LiteralPath (Join-Path $root $route.path) -Algorithm SHA256).Hash -eq $route.sha256) "Route lock changed: $($route.path)"
}

[pscustomobject]@{
  result = 'PASS'
  current_phase_unchanged = $true
  current_capability_unchanged = $true
  active_task_id = $queue.active_task_id
  task_queue_unchanged = $true
  packs_registry_unchanged = $true
  orchestrator_run_unchanged = $true
  route_lock_unchanged = $true
  validator_only_promoted_to_live = $false
}
