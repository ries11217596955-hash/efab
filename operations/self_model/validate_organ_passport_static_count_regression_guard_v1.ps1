$ErrorActionPreference='Stop'
$RepoRoot=(Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
Set-Location $RepoRoot
function Assert($Cond,[string]$Msg){if(-not $Cond){throw $Msg}}
function Write-Json($Obj,[string]$Path){$dir=Split-Path $Path -Parent; if($dir -and -not(Test-Path $dir)){New-Item -ItemType Directory -Path $dir -Force|Out-Null}; $Obj|ConvertTo-Json -Depth 30|Set-Content -Path $Path -Encoding UTF8}
$build='operations/self_model/build_organ_passport_draft_generator_fast_lane_v1.ps1'
$gen='operations/self_model/validate_organ_passport_draft_generator_fast_lane_v1.ps1'
$gate='operations/self_model/validate_organ_passport_draft_review_and_index_gate_v1.ps1'
$reportPath='reports/self_development/ORGAN_PASSPORT_STATIC_COUNT_REGRESSION_GUARD_V1.json'
$proofPath='tests/self_development/ORGAN_PASSPORT_STATIC_COUNT_REGRESSION_GUARD_V1_PROOF.json'
foreach($p in @($build,$gen,$gate)){Assert (Test-Path $p) "MISSING:$p"}
$buildText=Get-Content $build -Raw
$genText=Get-Content $gen -Raw
$gateText=Get-Content $gate -Raw
$allText=$buildText + "`n---GEN---`n" + $genText + "`n---GATE---`n" + $gateText
$forbidden=@(
  'Assert \(\$drafts\.Count -eq 2\)',
  'Assert \(\$items\.Count -eq 2\)',
  'Assert \(\$idxItems\.Count -eq 2\)',
  'Assert \(\@\(\$index\.entries\)\.Count -eq 2\)',
  'DRAFT_COUNT_BAD''\s*\)??\s*$'
)
$hits=@()
foreach($pattern in $forbidden){
  if($allText -match $pattern){$hits += $pattern}
}
Assert ($hits.Count -eq 0) ('STATIC_COUNT_REGRESSION_PATTERN_FOUND:' + ($hits -join ','))
Assert ($buildText -match 'param\(') 'BUILD_SCRIPT_NOT_INVOCABLE_PARAM_MISSING'
Assert ($buildText -match 'CandidateId') 'BUILD_SCRIPT_CANDIDATE_ID_PARAM_MISSING'
Assert ($buildText -match 'Get-ChildItem.*organ_passports.*ORGAN_PASSPORT_V1\.json' -or $buildText -match "Get-ChildItem 'self_model/organ_passports' -Recurse -Filter 'ORGAN_PASSPORT_V1.json'") 'BUILD_INDEX_SCAN_MISSING'
Assert ($buildText -match 'Group-Object organ_id') 'BUILD_DEDUP_BY_ORGAN_ID_MISSING'
Assert ($buildText -match 'passport_generator_repeatable_fast_lane') 'BUILD_REPEATABLE_BOUNDARY_MISSING'
Assert ($genText -match 'operations_organ_promotion_lanes') 'GENERATOR_TARGET_PRESENCE_CHECK_MISSING'
Assert ($genText -match 'passport_generator_repeatable_fast_lane') 'GENERATOR_REPEATABLE_BOUNDARY_CHECK_MISSING'
Assert ($gateText -match 'Get-ChildItem.*organ_passports.*ORGAN_PASSPORT_V1\.json' -or $gateText -match "Get-ChildItem 'self_model/organ_passports' -Recurse -Filter 'ORGAN_PASSPORT_V1.json'") 'GATE_SCAN_BASED_REVIEW_MISSING'
Assert ($gateText -match 'operations_organ_promotion_lanes') 'GATE_TARGET_PRESENCE_CHECK_MISSING'
$generatorReport=Get-Content 'reports/self_development/ORGAN_PASSPORT_DRAFT_GENERATOR_FAST_LANE_V1.json' -Raw|ConvertFrom-Json
$index=Get-Content 'self_model/organ_passports/_index/ORGAN_PASSPORT_DRAFT_INDEX_V1.json' -Raw|ConvertFrom-Json
$passportFiles=@(Get-ChildItem 'self_model/organ_passports' -Recurse -Filter 'ORGAN_PASSPORT_V1.json')
Assert ([int]$generatorReport.generated_count -ge 3) 'GENERATOR_REPORT_NOT_MULTI_DRAFT'
Assert (@($generatorReport.generated_drafts|Where-Object{$_.organ_id -eq 'operations_organ_promotion_lanes'}).Count -eq 1) 'GENERATOR_REPORT_TARGET_MISSING'
Assert ([int]$index.draft_count -eq $passportFiles.Count) 'INDEX_COUNT_NOT_SCAN_COUNT'
Assert (@($index.passports|Where-Object{$_.organ_id -eq 'operations_organ_promotion_lanes'}).Count -eq 1) 'INDEX_TARGET_MISSING'
$report=[ordered]@{
  schema='organ_passport_static_count_regression_guard_v1'
  status='PASS_ORGAN_PASSPORT_STATIC_COUNT_REGRESSION_GUARD_V1'
  purpose='Prevent regression of the passport generator/review gate back to static two-passport assumptions.'
  checked_files=@($build,$gen,$gate)
  forbidden_static_count_patterns=$forbidden
  generator_report_generated_count=[int]$generatorReport.generated_count
  passport_file_scan_count=$passportFiles.Count
  index_draft_count=[int]$index.draft_count
  target_candidate='operations_organ_promotion_lanes'
  target_present_in_generator_report=$true
  target_present_in_index=$true
  repeatable_fast_lane_boundary_present=$true
  no_active_claims=$true
  no_proven_live_claims=$true
  live_process_touched=$false
  created_at=(Get-Date).ToString('o')
}
$proof=[ordered]@{
  schema='organ_passport_static_count_regression_guard_v1_proof'
  status='PASS_ORGAN_PASSPORT_STATIC_COUNT_REGRESSION_GUARD_V1'
  report_path=$reportPath
  static_count_regression_absent=$true
  scan_based_indexing_present=$true
  target_presence_checks_present=$true
  generated_count_at_least_three=([int]$generatorReport.generated_count -ge 3)
  index_count_matches_passport_scan=([int]$index.draft_count -eq $passportFiles.Count)
  live_process_touched=$false
  created_at=(Get-Date).ToString('o')
}
Write-Json $report $reportPath
Write-Json $proof $proofPath
Write-Host 'VALIDATION_PASS=PASS_ORGAN_PASSPORT_STATIC_COUNT_REGRESSION_GUARD_V1'
Write-Host ('REPORT_PATH='+$reportPath)
Write-Host ('PROOF_PATH='+$proofPath)
