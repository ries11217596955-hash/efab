$ErrorActionPreference='Stop'
$repoRoot=(git rev-parse --show-toplevel).Trim(); Set-Location $repoRoot
function Assert($Cond,[string]$Msg){if(-not $Cond){throw $Msg}}
$paths=@('reports/self_development/LIVING_LOOP_CURRENT_STATE_REFRESH_V1_SIGNALS.json','reports/self_development/LIVING_LOOP_CURRENT_STATE_REFRESH_V1_BODY_STATE.json','reports/self_development/LIVING_LOOP_CURRENT_STATE_REFRESH_V1_REASONER.json','reports/self_development/LIVING_LOOP_CURRENT_STATE_REFRESH_V1_DECISION.json','reports/self_development/LIVING_LOOP_CURRENT_STATE_REFRESH_V1_REPORT.json','tests/self_development/LIVING_LOOP_CURRENT_STATE_REFRESH_V1_PROOF.json')
foreach($p in $paths){Assert (Test-Path $p) "MISSING:$p"}
$s=Get-Content $paths[0] -Raw|ConvertFrom-Json
$b=Get-Content $paths[1] -Raw|ConvertFrom-Json
$r=Get-Content $paths[2] -Raw|ConvertFrom-Json
$d=Get-Content $paths[3] -Raw|ConvertFrom-Json
$proof=Get-Content $paths[5] -Raw|ConvertFrom-Json
Assert ($s.status -eq 'PASS_LIVING_LOOP_CURRENT_STATE_REFRESH_V1_SIGNALS') 'SIGNALS_STATUS_BAD'
Assert ($b.status -eq 'PASS_LIVING_LOOP_CURRENT_STATE_REFRESH_V1_BODY_STATE') 'BODY_STATUS_BAD'
Assert ($r.status -eq 'PASS_LIVING_LOOP_CURRENT_STATE_REFRESH_V1_REASONER') 'REASON_STATUS_BAD'
Assert ($d.status -eq 'PASS_LIVING_LOOP_CURRENT_STATE_REFRESH_V1_DECISION') 'DECISION_STATUS_BAD'
Assert ($proof.status -eq 'PASS_LIVING_LOOP_CURRENT_STATE_REFRESH_V1') 'PROOF_STATUS_BAD'
Assert ([int]$b.summary.validated_lab_non_active_count -eq 4) 'VALIDATED_COUNT_BAD'
Assert ([int]$b.summary.blocked_count -eq 0) 'BLOCKED_COUNT_NOT_ZERO'
Assert ([int]$b.summary.repair_required_count -eq 0) 'REPAIR_REQUIRED_NOT_ZERO'
Assert ([int]$b.summary.boundary_guarded_count -eq 2) 'BOUNDARY_COUNT_BAD'
Assert ($r.summary.dominant_root_cause -eq 'NO_BLOCKING_ROOT_CAUSE') 'DOMINANT_ROOT_CAUSE_BAD'
Assert ($d.route_class -eq 'CONTINUE_NON_EXECUTING_BRAIN_BUILD_OR_SEPARATE_AUTHORITY_GATE') 'ROUTE_CLASS_BAD'
foreach($x in @($b.summary,$r.summary,$d,$proof)){Assert ($x.mutation_authorized -eq $false) 'MUTATION_OVERCLAIM'; Assert ($x.runtime_ready -eq $false) 'RUNTIME_OVERCLAIM'; Assert ($x.live_ready -eq $false) 'LIVE_OVERCLAIM'; Assert ($x.autonomous_runtime -eq $false) 'AUTONOMOUS_OVERCLAIM'}
Assert ($proof.active_behavior_current_validated_lab -eq $true) 'ACTIVE_BEHAVIOR_NOT_CURRENT_VALIDATED'
Assert ($proof.stale_blocked_route_removed -eq $true) 'STALE_BLOCKED_ROUTE_NOT_REMOVED'
Write-Host 'VALIDATION_PASS=PASS_LIVING_LOOP_CURRENT_STATE_REFRESH_V1'
Write-Host 'VALIDATED_LAB_NON_ACTIVE=4'
Write-Host 'BLOCKED=0'
Write-Host 'REPAIR_REQUIRED=0'
Write-Host 'DOMINANT_ROOT_CAUSE=NO_BLOCKING_ROOT_CAUSE'
