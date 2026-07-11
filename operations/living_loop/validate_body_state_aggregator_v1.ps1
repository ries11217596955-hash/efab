$ErrorActionPreference='Stop'
$repoRoot=(git rev-parse --show-toplevel).Trim(); Set-Location $repoRoot
function Assert($Cond,[string]$Msg){ if(-not $Cond){ throw $Msg } }
$requirement='contracts/living_loop/BODY_STATE_AGGREGATOR_V1_REQUIREMENT.md'
$statePath='reports/self_development/BODY_STATE_AGGREGATOR_V1_STATE.json'
$reportPath='reports/self_development/BODY_STATE_AGGREGATOR_V1_REPORT.json'
$proofPath='tests/self_development/BODY_STATE_AGGREGATOR_V1_PROOF.json'
foreach($p in @($requirement,$statePath,$reportPath,$proofPath)){Assert (Test-Path $p) "MISSING:$p"}
# Ensure evaluator still validates.
powershell -ExecutionPolicy Bypass -File operations/living_loop/validate_living_loop_evaluator_v1.ps1 | Out-Host
Assert ($LASTEXITCODE -eq 0) 'EVALUATOR_VALIDATION_FAILED'
$s=Get-Content $statePath -Raw|ConvertFrom-Json
$r=Get-Content $reportPath -Raw|ConvertFrom-Json
$p=Get-Content $proofPath -Raw|ConvertFrom-Json
Assert ($s.status -eq 'PASS_BODY_STATE_AGGREGATOR_V1_STATE') 'STATE_STATUS_BAD'
Assert ($r.status -eq 'PASS_BODY_STATE_AGGREGATOR_V1') 'REPORT_STATUS_BAD'
Assert ($p.status -eq 'PASS_BODY_STATE_AGGREGATOR_V1') 'PROOF_STATUS_BAD'
foreach($bucket in @('validated_lab_non_active','blocked','boundary_guarded','return_to_parent','owner_decision_required','repair_required','no_action_needed')){ Assert ($s.categories.PSObject.Properties.Name -contains $bucket) "BUCKET_MISSING:$bucket" }
Assert ([int]$s.summary.total_signals -eq 7) 'TOTAL_SIGNALS_BAD'
Assert ([int]$s.summary.validated_lab_non_active_count -eq 3) 'VALIDATED_COUNT_BAD'
Assert ([int]$s.summary.blocked_count -eq 1) 'BLOCKED_COUNT_BAD'
Assert ([int]$s.summary.boundary_guarded_count -ge 2) 'BOUNDARY_COUNT_BAD'
Assert ([int]$s.summary.return_to_parent_count -eq 1) 'RETURN_COUNT_BAD'
Assert ([int]$s.summary.repair_required_count -eq 1) 'REPAIR_COUNT_BAD'
Assert ([int]$s.summary.no_action_needed_count -eq 3) 'NO_ACTION_COUNT_BAD'
Assert ($s.summary.brain_input_ready -eq $true) 'BRAIN_INPUT_NOT_READY'
Assert ($s.summary.mutation_authorized -eq $false) 'MUTATION_AUTHORIZED_OVERCLAIM'
Assert ($s.summary.runtime_ready -eq $false) 'RUNTIME_READY_OVERCLAIM'
Assert ($s.summary.live_ready -eq $false) 'LIVE_READY_OVERCLAIM'
Assert ($s.summary.autonomous_runtime -eq $false) 'AUTONOMOUS_OVERCLAIM'
Assert ($s.summary.recommended_next_route -eq 'REPAIR_BLOCKED_SOURCE_PROOF_OR_KEEP_BLOCKED') 'RECOMMENDED_ROUTE_BAD'
Assert ($p.blocked_signal_preserved -eq $true) 'BLOCKED_SIGNAL_NOT_PRESERVED'
Assert ($p.boundary_guard_signals_preserved -eq $true) 'BOUNDARY_SIGNALS_NOT_PRESERVED'
Assert ($p.return_to_parent_signal_preserved -eq $true) 'RETURN_SIGNAL_NOT_PRESERVED'
Assert ($p.no_passport_active_created -eq $true) 'PASSPORT_ACTIVE_OVERCLAIM'
Assert ($p.no_live_runtime_touched -eq $true) 'LIVE_TOUCHED_OVERCLAIM'
Assert ($p.not_brain -eq $true) 'BRAIN_OVERCLAIM'
Assert ($p.not_execution_authority -eq $true) 'EXECUTION_AUTHORITY_OVERCLAIM'
Write-Host 'VALIDATION_PASS=PASS_BODY_STATE_AGGREGATOR_V1'
Write-Host 'TOTAL_SIGNALS=7'
Write-Host 'VALIDATED_LAB_NON_ACTIVE=3'
Write-Host 'BLOCKED=1'
Write-Host 'BOUNDARY_GUARDED>=2'
Write-Host 'REPAIR_REQUIRED=1'
Write-Host 'BRAIN_INPUT_READY=true'
Write-Host 'MUTATION_AUTHORIZED=false'
