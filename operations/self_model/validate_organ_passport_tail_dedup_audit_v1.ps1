$ErrorActionPreference='Stop'
$RepoRoot=(Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
Set-Location $RepoRoot
function Assert($Cond,[string]$Msg){if(-not $Cond){throw $Msg}}
$reportPath='reports/self_development/ORGAN_PASSPORT_TAIL_DEDUP_AUDIT_V1.json'
$proofPath='tests/self_development/ORGAN_PASSPORT_TAIL_DEDUP_AUDIT_V1_PROOF.json'
foreach($p in @($reportPath,$proofPath)){Assert (Test-Path $p) "MISSING:$p"}
$r=Get-Content $reportPath -Raw|ConvertFrom-Json
$p=Get-Content $proofPath -Raw|ConvertFrom-Json
Assert ($r.status -eq 'PASS_ORGAN_PASSPORT_TAIL_DEDUP_AUDIT_V1') 'REPORT_STATUS_BAD'
Assert ($p.status -eq 'PASS_ORGAN_PASSPORT_TAIL_DEDUP_AUDIT_V1') 'PROOF_STATUS_BAD'
Assert (@($r.audited_ids).Count -eq 5) 'AUDITED_COUNT_BAD'
Assert ([int]$p.audited_count -eq 5) 'PROOF_AUDITED_COUNT_BAD'
Assert ([int]$p.downclassify_candidates -eq 2) 'DOWNCLASSIFY_COUNT_BAD'
Assert ([int]$p.keep_as_draft -eq 2) 'KEEP_DRAFT_COUNT_BAD'
Assert ([int]$p.repaired_passport_links -eq 1) 'REPAIRED_LINK_COUNT_BAD'
foreach($id in @('operations_contracts','operations_smoke_trials','operations_active_behavior','operations_organ_promotion_lanes','operations_overnight_school')){Assert (@($r.audited_ids) -contains $id) "AUDITED_ID_MISSING:$id"}
$contracts=@($r.decisions|Where-Object{$_.organ_id -eq 'operations_contracts'})[0]
$smoke=@($r.decisions|Where-Object{$_.organ_id -eq 'operations_smoke_trials'})[0]
$active=@($r.decisions|Where-Object{$_.organ_id -eq 'operations_active_behavior'})[0]
$lanes=@($r.decisions|Where-Object{$_.organ_id -eq 'operations_organ_promotion_lanes'})[0]
$overnight=@($r.decisions|Where-Object{$_.organ_id -eq 'operations_overnight_school'})[0]
Assert ($contracts.decision -eq 'DOWNCLASSIFY_CANDIDATE') 'CONTRACTS_DECISION_BAD'
Assert ($smoke.decision -eq 'DOWNCLASSIFY_CANDIDATE') 'SMOKE_DECISION_BAD'
Assert ($active.decision -eq 'KEEP_AS_ORGAN_DRAFT') 'ACTIVE_DECISION_BAD'
Assert ($lanes.decision -eq 'KEEP_AS_GOVERNANCE_DRAFT') 'LANES_DECISION_BAD'
Assert ($overnight.decision -eq 'REPAIR_PASSPORT_LINK_KEEP_DRAFT') 'OVERNIGHT_DECISION_BAD'
$op=Get-Content 'self_model/organ_passports/operations_overnight_school/ORGAN_PASSPORT_V1.json' -Raw|ConvertFrom-Json
Assert (@($op.validators) -contains 'operations/overnight_school/validate_useful_school_30k_full_process_v1.ps1') 'OVERNIGHT_VALIDATOR_NOT_REPAIRED'
Assert (@($op.validators|Where-Object{$_ -match 'ps1operations/'}).Count -eq 0) 'OVERNIGHT_BAD_VALIDATOR_STILL_PRESENT'
Assert ($p.no_files_deleted -eq $true) 'DELETE_BOUNDARY_BAD'
Assert ($p.no_passport_promoted -eq $true) 'PROMOTION_BOUNDARY_BAD'
Assert ($p.no_passport_active_created -eq $true) 'ACTIVE_BOUNDARY_BAD'
Assert ($p.no_live_runtime_touched -eq $true) 'LIVE_BOUNDARY_BAD'
Write-Host 'VALIDATION_PASS=PASS_ORGAN_PASSPORT_TAIL_DEDUP_AUDIT_V1'
Write-Host 'DOWNCLASSIFY_CANDIDATES=operations_contracts,operations_smoke_trials'
Write-Host 'KEEP_DRAFT=operations_active_behavior,operations_organ_promotion_lanes'
Write-Host 'REPAIRED_LINK=operations_overnight_school'
Write-Host "REPORT_PATH=$reportPath"
Write-Host "PROOF_PATH=$proofPath"
