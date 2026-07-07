param([string]$OutputPath='reports/self_development/BUILDER_GAP_MAP_V1.json')
$ErrorActionPreference='Stop'
$RepoRoot=(git rev-parse --show-toplevel).Trim(); Set-Location $RepoRoot
$snapshotPath='reports/self_development/CURRENT_BODY_CAPABILITY_SNAPSHOT_V1.json'
$identityPath='self_model/BUILDER_IDENTITY_CONTRACT_V1.json'
if(-not(Test-Path $snapshotPath)){ & powershell -NoProfile -ExecutionPolicy Bypass -File operations/self_model/export_current_body_capability_snapshot_v1.ps1 | Out-Host }
$s=Get-Content $snapshotPath -Raw|ConvertFrom-Json
$i=Get-Content $identityPath -Raw|ConvertFrom-Json
$components=@($s.components)
function Component($Name){ return @($components|Where-Object{$_.name -eq $Name}|Select-Object -First 1)[0] }
$gaps=@()
function Add-Gap($Id,$Title,$Severity,$Mission,$Category,$Reason,$ProofNeeded,$ValidatorNeeded,$Blocks,$SourceDependencyRisk){
  $script:gaps += [ordered]@{id=$Id;title=$Title;severity=$Severity;mission_relevance=$Mission;category=$Category;reason=$Reason;proof_needed=@($ProofNeeded);validator_needed=@($ValidatorNeeded);blocks=@($Blocks);source_dependency_risk=$SourceDependencyRisk;status='OPEN'}
}
if(-not (Component 'source_agnostic_path_selector').built){ Add-Gap 'source_agnostic_path_selector_missing' 'AIMO selector is not source-agnostic yet' 'CRITICAL' 'primary_self_build' 'selector' 'Current live task still shows source-shaped selection; V4 requires identity/gap based selection.' @('lab path selector proof','controlled live AIMO proof') @('source-agnostic selector validator','School missing/stale/failed negative tests') @('identity_based_next_step_selection','school_independence') $true }
if(-not (Component 'builder_mission_scoring').built){ Add-Gap 'builder_mission_scoring_missing' 'No Builder mission scoring layer' 'HIGH' 'primary_self_build' 'scoring' 'Candidates are not scored by self-build leverage, proof path, dependency reduction, and overfitting risk.' @('scoring proof JSON') @('latest signal loses to higher Builder gap validator') @('source_agnostic_path_selector') $false }
$identityComp=Component 'builder_identity_contract'
if($identityComp.wired -ne $true){ Add-Gap 'identity_contract_not_wired_into_aimo' 'Identity contract exists but is not wired into AIMO selection' 'HIGH' 'primary_self_build' 'wiring' 'Contract is lab-proven as law but AIMO task selection does not consume it yet.' @('AIMO lab integration proof','live hotswap proof') @('AIMO identity contract integration validator') @('identity_based_next_step_selection') $false }
if(-not (Component 'provenance_rejection_trace').built){ Add-Gap 'provenance_rejection_trace_missing' 'Selected action lacks full source use/rejection trace' 'HIGH' 'primary_self_build' 'trace' 'AIMO needs source_refs_used, source_refs_rejected, and why_not_latest_signal for trustworthy selection.' @('trace proof JSON') @('rejection reasons non-empty validator') @('auditable_selection') $false }
Add-Gap 'latest_signal_overfit_negative_tests_missing' 'Latest-signal overfit negative tests are missing' 'HIGH' 'primary_self_build' 'validator' 'Route V4 requires proof that a fresh but low-value signal loses to a higher Builder gap.' @('negative test proof') @('latest-signal rejection validator') @('identity_based_next_step_selection') $true
Add-Gap 'single_source_dependency_negative_tests_missing' 'Single-source dependency negative tests are missing' 'HIGH' 'primary_self_build' 'validator' 'School, AgentLife, or any single packet must be absent/stale/failed without blocking next-step choice.' @('missing/stale/failed source proof') @('source dependency negative validator') @('school_independence') $true
if(-not (Component 'child_agent_factory').built){ Add-Gap 'child_agent_factory_not_ready_future_blocker' 'Child-agent factory is not ready and must stay secondary' 'MEDIUM' 'secondary_child_agent_future' 'future_factory' 'Child agents remain blocked until self-build selector, proof discipline, and source-agnostic planning are mature.' @('future route proof after owner review') @('child-agent readiness validator later') @('child_agent_production') $false }
$gapMap=[ordered]@{
  schema='builder_gap_map_v1'
  status='GAP_MAP_EXPORTED'
  route_lock='route_locks/AGENT_BUILDER_NEXT_15_STEPS_LOCK_V4_IDENTITY_BASED_SELECTION.md'
  identity_contract_path=$identityPath
  snapshot_path=$snapshotPath
  gap_count=@($gaps).Count
  gaps=@($gaps)
  priority_order=@($gaps|Sort-Object @{Expression={switch($_.severity){'CRITICAL'{0};'HIGH'{1};'MEDIUM'{2};default{3}}}},id|ForEach-Object{$_.id})
  next_recommended_phase='PHASE_E_SOURCE_EVIDENCE_INVENTORY_V1'
  live_process_touched=$false
  active_memory_mutated=$false
  created_at=(Get-Date).ToString('o')
}
New-Item -ItemType Directory -Force -Path (Split-Path $OutputPath -Parent)|Out-Null
$gapMap|ConvertTo-Json -Depth 80|Set-Content $OutputPath -Encoding UTF8
Write-Host 'EXPORT_STATUS=GAP_MAP_EXPORTED'
Write-Host ('OUTPUT_PATH='+$OutputPath)
Write-Host 'LIVE_PROCESS_TOUCHED=false'
