$ErrorActionPreference='Stop'
$RepoRoot=(Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
Set-Location $RepoRoot
function Assert($Cond,[string]$Msg){if(-not $Cond){throw $Msg}}
$reportPath='reports/self_development/ORGAN_PASSPORT_MATURITY_SUMMARY_V1.json'
$proofPath='tests/self_development/ORGAN_PASSPORT_MATURITY_SUMMARY_V1_PROOF.json'
foreach($p in @($reportPath,$proofPath)){Assert (Test-Path $p) "MISSING:$p"}
$r=Get-Content $reportPath -Raw|ConvertFrom-Json
$p=Get-Content $proofPath -Raw|ConvertFrom-Json
Assert ($r.status -eq 'PASS_ORGAN_PASSPORT_MATURITY_SUMMARY_V1') 'REPORT_STATUS_BAD'
Assert ($p.status -eq 'PASS_ORGAN_PASSPORT_MATURITY_SUMMARY_V1') 'PROOF_STATUS_BAD'
Assert ([int]$r.total_passports -eq 159) 'TOTAL_PASSPORTS_BAD'
Assert ([int]$p.total_passports -eq 159) 'PROOF_TOTAL_BAD'
Assert ([int]$r.validated_or_proven_count -ge 4) 'VALIDATED_COUNT_TOO_LOW'
Assert ([int]$p.draft_with_validators_count -ge 1) 'DRAFT_TAIL_EXPECTED'
Assert (@($r.next_five_review_candidates).Count -eq [int]$p.next_five_count) 'NEXT_FIVE_COUNT_MISMATCH'
Assert ($r.interpretation.repair_does_not_mean_broken_runtime -eq $true) 'INTERPRETATION_REPAIR_BAD'
Assert ($r.interpretation.deletion_requires_separate_owner_decision -eq $true) 'DELETE_BOUNDARY_BAD'
Assert ($r.boundaries.summary_only -eq $true) 'SUMMARY_ONLY_BAD'
Assert ($r.boundaries.no_files_deleted -eq $true) 'NO_DELETE_BOUNDARY_BAD'
Assert ($r.boundaries.no_live_runtime_touched -eq $true) 'LIVE_BOUNDARY_BAD'
Write-Host 'VALIDATION_PASS=PASS_ORGAN_PASSPORT_MATURITY_SUMMARY_V1'
Write-Host ('TOTAL_PASSPORTS='+$r.total_passports)
Write-Host ('VALIDATED_OR_PROVEN='+$r.validated_or_proven_count)
Write-Host ('DRAFT_WITH_VALIDATORS='+$r.draft_with_validators_count)
Write-Host "REPORT_PATH=$reportPath"
Write-Host "PROOF_PATH=$proofPath"
