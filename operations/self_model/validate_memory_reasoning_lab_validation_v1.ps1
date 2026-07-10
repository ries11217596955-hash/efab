$ErrorActionPreference='Stop'
$RepoRoot=(Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
Set-Location $RepoRoot
function Assert($Cond,[string]$Msg){if(-not $Cond){throw $Msg}}
$reportPath='reports/self_development/MEMORY_REASONING_LAB_VALIDATION_V1.json'
$proofPath='tests/self_development/MEMORY_REASONING_LAB_VALIDATION_V1_PROOF.json'
foreach($p in @($reportPath,$proofPath)){Assert (Test-Path $p) "MISSING:$p"}
$r=Get-Content $reportPath -Raw|ConvertFrom-Json
$p=Get-Content $proofPath -Raw|ConvertFrom-Json
Assert ($r.status -eq 'PASS_MEMORY_REASONING_LAB_VALIDATION_V1') 'REPORT_STATUS_BAD'
Assert ($p.status -eq 'PASS_MEMORY_REASONING_LAB_VALIDATION_V1') 'PROOF_STATUS_BAD'
Assert ([int]$p.validated_count -eq 2) 'VALIDATED_COUNT_BAD'
foreach($id in @('operations_memory','operations_reasoning')){
  Assert (@($p.validated_organs) -contains $id) "VALIDATED_ID_MISSING:$id"
  $pp=Get-Content "self_model/organ_passports/$id/ORGAN_PASSPORT_V1.json" -Raw|ConvertFrom-Json
  Assert ($pp.maturity -eq 'VALIDATED_LAB') "Maturity_NOT_VALIDATED_LAB:$id"
  Assert ($pp.live_or_lab_status -eq 'PROVEN_LAB') "STATUS_NOT_PROVEN_LAB:$id"
  Assert ($pp.status -eq 'PASSPORT_DRAFT_FROM_EVIDENCE') "PASSPORT_STATUS_CHANGED_UNEXPECTEDLY:$id"
  Assert ($pp.live_or_lab_status -ne 'PROVEN_LIVE') "PROVEN_LIVE_FORBIDDEN:$id"
}
Assert ([int]$p.memory_validators_passed -eq 2) 'MEMORY_VALIDATOR_COUNT_BAD'
Assert ([int]$p.reasoning_validators_passed -eq 3) 'REASONING_VALIDATOR_COUNT_BAD'
Assert ($p.no_active_passports_created -eq $true) 'ACTIVE_BOUNDARY_BAD'
Assert ($p.no_proven_live_claim -eq $true) 'LIVE_CLAIM_BOUNDARY_BAD'
Assert ($p.live_process_touched -eq $false) 'LIVE_TOUCHED_BAD'
Assert ($r.boundaries.lab_validation_only -eq $true) 'REPORT_LAB_ONLY_BAD'
Write-Host 'VALIDATION_PASS=PASS_MEMORY_REASONING_LAB_VALIDATION_V1'
Write-Host 'VALIDATED_ORGANS=operations_memory,operations_reasoning'
Write-Host 'MATURITY=VALIDATED_LAB'
Write-Host 'LIVE_OR_LAB_STATUS=PROVEN_LAB'
Write-Host "REPORT_PATH=$reportPath"
Write-Host "PROOF_PATH=$proofPath"
