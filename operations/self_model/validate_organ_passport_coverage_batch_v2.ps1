$ErrorActionPreference='Stop'
$RepoRoot=(Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
Set-Location $RepoRoot
function Assert($Cond,[string]$Msg){if(-not $Cond){throw $Msg}}
function Write-Json($Obj,[string]$Path){$dir=Split-Path $Path -Parent;if($dir -and -not(Test-Path $dir)){New-Item -ItemType Directory -Path $dir -Force|Out-Null};$Obj|ConvertTo-Json -Depth 50|Set-Content -Path $Path -Encoding UTF8}
$lanesPath='self_model/organ_promotion_lanes/ORGAN_PROMOTION_LANES_V1.json'
$indexPath='self_model/organ_passports/_index/ORGAN_PASSPORT_DRAFT_INDEX_V1.json'
$reportPath='reports/self_development/ORGAN_PASSPORT_COVERAGE_BATCH_V2.json'
$proofPath='tests/self_development/ORGAN_PASSPORT_COVERAGE_BATCH_V2_PROOF.json'
foreach($x in @($lanesPath,$indexPath,$reportPath,$proofPath)){Assert (Test-Path $x) "MISSING:$x"}
$lanes=Get-Content $lanesPath -Raw|ConvertFrom-Json
$laneIds=@($lanes.lane_decisions|ForEach-Object{[string]$_.candidate_id})
$passports=@(Get-ChildItem 'self_model/organ_passports' -Recurse -Filter 'ORGAN_PASSPORT_V1.json'|ForEach-Object{ $p=Get-Content $_.FullName -Raw|ConvertFrom-Json; [pscustomobject]@{id=[string]$p.organ_id; path=$_.FullName.Substring($RepoRoot.Length+1).Replace('\','/'); status=$p.status; maturity=$p.maturity; live=$p.live_or_lab_status; kind=$p.passport_kind; lane=$p.source_lane; validators=@($p.validators).Count; proofs=@($p.proof_refs).Count} })
$passIds=@($passports.id)
$missing=@($laneIds|Where-Object{$passIds -notcontains $_})
$extra=@($passports|Where-Object{$laneIds -notcontains $_.id})
Assert ($missing.Count -eq 0) ('LANE_IDS_WITHOUT_PASSPORT:' + ($missing -join ','))
Assert ($extra.Count -eq 1 -and $extra[0].id -eq 'operations_self_model') ('UNEXPECTED_EXTRA_PASSPORTS:' + (@($extra.id)-join ','))
foreach($p in $passports){
  Assert ($p.status -eq 'PASSPORT_DRAFT_FROM_EVIDENCE') "PASSPORT_STATUS_BAD:$($p.id)"
  Assert ($p.maturity -eq 'DRAFT' -or $p.maturity -eq 'VALIDATED_LAB') "PASSPORT_MATURITY_BAD:$($p.id):$($p.maturity)"
  Assert ($p.live -ne 'PROVEN_LIVE') "PROVEN_LIVE_FORBIDDEN:$($p.id)"
}
$index=Get-Content $indexPath -Raw|ConvertFrom-Json
Assert ([int]$index.draft_count -eq $passports.Count) 'INDEX_COUNT_NOT_FILE_COUNT'
$generatedReport=Get-Content $reportPath -Raw|ConvertFrom-Json
$kindCounts=@($passports|Group-Object kind|ForEach-Object{[ordered]@{passport_kind=if([string]::IsNullOrWhiteSpace($_.Name)){'UNCLASSIFIED_EXISTING'}else{$_.Name};count=$_.Count}})
$laneCounts=@($passports|Where-Object{$laneIds -contains $_.id}|Group-Object lane|ForEach-Object{[ordered]@{source_lane=if([string]::IsNullOrWhiteSpace($_.Name)){'UNCLASSIFIED_EXISTING'}else{$_.Name};count=$_.Count}})
$report=[ordered]@{
  schema='organ_passport_coverage_batch_v2'
  status='PASS_ORGAN_PASSPORT_COVERAGE_BATCH_V2'
  previous_passport_count=$generatedReport.previous_passport_count
  generated_count=$generatedReport.generated_count
  lane_decision_count=$laneIds.Count
  lane_passport_coverage_count=$laneIds.Count
  total_passport_file_count=$passports.Count
  extra_passports_not_in_lanes=@($extra|ForEach-Object{[ordered]@{organ_id=$_.id;path=$_.path;reason='pre-existing self-model/meta passport outside lane decisions'}})
  lane_coverage_complete=$true
  generated_by_kind=$kindCounts
  covered_by_lane=$laneCounts
  generated_drafts=$generatedReport.generated_drafts
  boundaries=[ordered]@{draft_only=$true;coverage_not_activation=$true;no_active_passports_created=$true;no_live_claims=$true;live_process_touched=$false;extra_self_model_passport_preserved=$true}
  created_at=(Get-Date).ToString('o')
}
$proof=[ordered]@{
  schema='organ_passport_coverage_batch_v2_proof'
  status='PASS_ORGAN_PASSPORT_COVERAGE_BATCH_V2'
  report_path=$reportPath
  generated_count=$generatedReport.generated_count
  lane_decision_count=$laneIds.Count
  lane_passport_coverage_count=$laneIds.Count
  total_passport_file_count=$passports.Count
  extra_passport_count=$extra.Count
  extra_passport_ids=@($extra.id)
  lane_coverage_complete=$true
  no_active_passports_created=$true
  no_live_claims=$true
  live_process_touched=$false
  created_at=(Get-Date).ToString('o')
}
Write-Json $report $reportPath
Write-Json $proof $proofPath
Write-Host 'VALIDATION_PASS=PASS_ORGAN_PASSPORT_COVERAGE_BATCH_V2'
Write-Host ('LANE_COVERAGE='+$laneIds.Count)
Write-Host ('TOTAL_PASSPORT_FILES='+$passports.Count)
Write-Host ('EXTRA_PASSPORTS='+(@($extra.id)-join ','))
Write-Host ('REPORT_PATH='+$reportPath)
Write-Host ('PROOF_PATH='+$proofPath)
