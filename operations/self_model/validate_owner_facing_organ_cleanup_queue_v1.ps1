$ErrorActionPreference='Stop'
$RepoRoot=(Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
Set-Location $RepoRoot
function Assert($Cond,[string]$Msg){if(-not $Cond){throw $Msg}}
$reportPath='reports/self_development/OWNER_FACING_ORGAN_CLEANUP_QUEUE_V1.json'
$mdPath='reports/self_development/OWNER_FACING_ORGAN_CLEANUP_QUEUE_V1.md'
$proofPath='tests/self_development/OWNER_FACING_ORGAN_CLEANUP_QUEUE_V1_PROOF.json'
foreach($p in @($reportPath,$mdPath,$proofPath)){Assert (Test-Path $p) "MISSING:$p"}
$r=Get-Content $reportPath -Raw|ConvertFrom-Json
$p=Get-Content $proofPath -Raw|ConvertFrom-Json
Assert ($r.status -eq 'PASS_OWNER_FACING_ORGAN_CLEANUP_QUEUE_V1') 'REPORT_STATUS_BAD'
Assert ($p.status -eq 'PASS_OWNER_FACING_ORGAN_CLEANUP_QUEUE_V1') 'PROOF_STATUS_BAD'
Assert ([int]$r.summary.total -eq 5) 'TOTAL_BAD'
Assert ([int]$r.summary.owner_decision_required -eq 2) 'OWNER_DECISION_COUNT_BAD'
Assert ([int]$r.summary.safe_keep_or_proof_actions -eq 3) 'SAFE_ACTION_COUNT_BAD'
Assert ([int]$r.summary.delete_candidates_without_deletion -eq 1) 'DELETE_CANDIDATE_COUNT_BAD'
Assert ([int]$r.summary.downclassify_candidates_without_mutation -eq 2) 'DOWNCLASSIFY_COUNT_BAD'
foreach($id in @('operations_contracts','operations_smoke_trials','operations_active_behavior','operations_organ_promotion_lanes','operations_overnight_school')){Assert (@($r.queue|Where-Object{$_.organ_id -eq $id}).Count -eq 1) "QUEUE_ID_BAD:$id"}
$contracts=@($r.queue|Where-Object{$_.organ_id -eq 'operations_contracts'})[0]
$smoke=@($r.queue|Where-Object{$_.organ_id -eq 'operations_smoke_trials'})[0]
Assert ($contracts.owner_decision_needed -eq $true) 'CONTRACTS_OWNER_DECISION_BAD'
Assert ($smoke.owner_decision_needed -eq $true) 'SMOKE_OWNER_DECISION_BAD'
Assert ($smoke.owner_decision_prompt -match 'DELETE_CANDIDATE') 'SMOKE_DELETE_PROMPT_BAD'
Assert ($r.boundaries.queue_only -eq $true) 'QUEUE_ONLY_BAD'
Assert ($p.no_files_deleted -eq $true) 'NO_DELETE_BAD'
Assert ($p.no_passport_promoted -eq $true) 'NO_PROMOTE_BAD'
Assert ($p.no_passport_downclassified -eq $true) 'NO_DOWNCLASSIFY_BAD'
Assert ($p.no_passport_active_created -eq $true) 'NO_ACTIVE_BAD'
Assert ($p.no_live_runtime_touched -eq $true) 'NO_LIVE_BAD'
Write-Host 'VALIDATION_PASS=PASS_OWNER_FACING_ORGAN_CLEANUP_QUEUE_V1'
Write-Host ('TOTAL='+$r.summary.total)
Write-Host ('OWNER_DECISION_REQUIRED='+$r.summary.owner_decision_required)
Write-Host ('SAFE_KEEP_OR_PROOF_ACTIONS='+$r.summary.safe_keep_or_proof_actions)
Write-Host "REPORT_PATH=$reportPath"
Write-Host "MARKDOWN_PATH=$mdPath"
Write-Host "PROOF_PATH=$proofPath"
