$ErrorActionPreference='Stop'
$RepoRoot=(Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
Set-Location $RepoRoot
function Assert($Cond,[string]$Msg){if(-not $Cond){throw $Msg}}
$reportPath='reports/self_development/ORGAN_PASSPORT_REVIEW_LANE_BATCH_GENERATOR_V1.json'
$proofPath='tests/self_development/ORGAN_PASSPORT_REVIEW_LANE_BATCH_GENERATOR_V1_PROOF.json'
$indexPath='self_model/organ_passports/_index/ORGAN_PASSPORT_DRAFT_INDEX_V1.json'
foreach($p in @($reportPath,$proofPath,$indexPath)){Assert (Test-Path $p) "MISSING:$p"}
$r=Get-Content $reportPath -Raw|ConvertFrom-Json
$p=Get-Content $proofPath -Raw|ConvertFrom-Json
$i=Get-Content $indexPath -Raw|ConvertFrom-Json
Assert ($r.status -eq 'PASS_ORGAN_PASSPORT_REVIEW_LANE_BATCH_GENERATOR_V1') 'REPORT_STATUS_BAD'
Assert ($p.status -eq 'PASS_ORGAN_PASSPORT_REVIEW_LANE_BATCH_GENERATOR_V1') 'PROOF_STATUS_BAD'
Assert ([int]$r.generated_count -ge 10) 'BATCH_TOO_SMALL'
Assert ([int]$p.generated_count -eq [int]$r.generated_count) 'PROOF_REPORT_COUNT_MISMATCH'
Assert ($r.boundaries.draft_only -eq $true) 'DRAFT_BOUNDARY_BAD'
Assert ($r.boundaries.review_lane_only -eq $true) 'REVIEW_LANE_BOUNDARY_BAD'
Assert ($r.boundaries.no_active_passports_created -eq $true) 'ACTIVE_BOUNDARY_BAD'
Assert ($r.boundaries.no_live_claims -eq $true) 'LIVE_BOUNDARY_BAD'
Assert ($r.boundaries.live_process_touched -eq $false) 'LIVE_TOUCHED_BAD'
foreach($d in @($r.generated_drafts)){
  Assert (Test-Path $d.passport_path) "PASSPORT_MISSING:$($d.organ_id)"
  Assert (Test-Path $d.doc_path) "DOC_MISSING:$($d.organ_id)"
  $pass=Get-Content $d.passport_path -Raw|ConvertFrom-Json
  Assert ($pass.status -eq 'PASSPORT_DRAFT_FROM_EVIDENCE') "STATUS_NOT_DRAFT:$($d.organ_id)"
  Assert ($pass.maturity -eq 'DRAFT') "MATURITY_NOT_DRAFT:$($d.organ_id)"
  Assert ($pass.live_or_lab_status -eq 'NOT_PROVEN') "LIVE_STATUS_BAD:$($d.organ_id)"
  Assert (@($pass.owned_files).Count -gt 0) "OWNED_EMPTY:$($d.organ_id)"
  Assert (@($i.entries|Where-Object{$_.organ_id -eq $d.organ_id}).Count -eq 1) "INDEX_ENTRY_MISSING:$($d.organ_id)"
}
$scanCount=@(Get-ChildItem 'self_model/organ_passports' -Recurse -Filter 'ORGAN_PASSPORT_V1.json').Count
Assert ([int]$i.draft_count -eq $scanCount) 'INDEX_SCAN_COUNT_MISMATCH'
Write-Host 'VALIDATION_PASS=PASS_ORGAN_PASSPORT_REVIEW_LANE_BATCH_GENERATOR_V1'
Write-Host ('REPORT_PATH='+$reportPath)
Write-Host ('PROOF_PATH='+$proofPath)
