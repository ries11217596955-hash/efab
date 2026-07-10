$ErrorActionPreference='Stop'
$RepoRoot=(Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
Set-Location $RepoRoot
function Assert($Cond,[string]$Msg){if(-not $Cond){throw $Msg}}
$reportPath='reports/self_development/OPERATIONS_LIVE_START_LAB_BOUNDARY_GATE_V1.json'
$proofPath='tests/self_development/OPERATIONS_LIVE_START_LAB_BOUNDARY_GATE_V1_PROOF.json'
$passportPath='self_model/organ_passports/operations_live_start/ORGAN_PASSPORT_V1.json'
foreach($p in @($reportPath,$proofPath,$passportPath)){Assert (Test-Path $p) "MISSING:$p"}
$r=Get-Content $reportPath -Raw|ConvertFrom-Json
$p=Get-Content $proofPath -Raw|ConvertFrom-Json
$pass=Get-Content $passportPath -Raw|ConvertFrom-Json
Assert ($r.status -eq 'BLOCKED_OPERATIONS_LIVE_START_LAB_BOUNDARY_GATE_V1') 'REPORT_STATUS_BAD'
Assert ($p.status -eq 'BLOCKED_OPERATIONS_LIVE_START_LAB_BOUNDARY_GATE_V1') 'PROOF_STATUS_BAD'
Assert ($p.decision -eq 'DO_NOT_PROMOTE_TO_VALIDATED_LAB') 'DECISION_BAD'
Assert ($p.live_boundary_detected -eq $true) 'LIVE_BOUNDARY_NOT_DETECTED'
Assert ([int]$p.live_proof_label_count -ge 1) 'LIVE_PROOF_LABEL_COUNT_BAD'
Assert ([int]$p.live_start_proof_count -ge 1) 'LIVE_START_PROOF_COUNT_BAD'
Assert ($pass.maturity -eq 'DRAFT') 'PASSPORT_SHOULD_REMAIN_DRAFT'
Assert ($pass.live_or_lab_status -eq 'NOT_PROVEN') 'PASSPORT_SHOULD_REMAIN_NOT_PROVEN'
Assert ($pass.status -eq 'PASSPORT_DRAFT_FROM_EVIDENCE') 'PASSPORT_STATUS_CHANGED_UNEXPECTEDLY'
Assert ($p.no_validated_lab_claim_created -eq $true) 'VALIDATED_LAB_BOUNDARY_BAD'
Assert ($p.no_active_passports_created -eq $true) 'ACTIVE_BOUNDARY_BAD'
Assert ($p.no_proven_live_claim -eq $true) 'PROVEN_LIVE_BOUNDARY_BAD'
Assert ($p.live_process_touched -eq $false) 'LIVE_PROCESS_TOUCHED_BAD'
Assert ($r.boundaries.lab_boundary_gate_only -eq $true) 'REPORT_LAB_GATE_BOUNDARY_BAD'
Assert ($r.root_cause -match 'live-start proofs') 'ROOT_CAUSE_BAD'
Write-Host 'VALIDATION_PASS=BLOCKED_OPERATIONS_LIVE_START_LAB_BOUNDARY_GATE_V1'
Write-Host 'DECISION=DO_NOT_PROMOTE_TO_VALIDATED_LAB'
Write-Host 'PASSPORT_MATURITY=DRAFT'
Write-Host 'LIVE_OR_LAB_STATUS=NOT_PROVEN'
Write-Host 'LIVE_PROCESS_TOUCHED=false'
Write-Host "REPORT_PATH=$reportPath"
Write-Host "PROOF_PATH=$proofPath"
