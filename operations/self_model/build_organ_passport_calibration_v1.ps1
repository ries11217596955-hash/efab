$ErrorActionPreference='Stop'
$RepoRoot=(Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
Set-Location $RepoRoot
function Assert($Cond,[string]$Msg){if(-not $Cond){throw $Msg}}
function WJson($Obj,[string]$Path){$d=Split-Path $Path -Parent;if($d -and -not(Test-Path $d)){New-Item -ItemType Directory -Path $d -Force|Out-Null};$Obj|ConvertTo-Json -Depth 60|Set-Content $Path -Encoding UTF8}
function Decision($v,$p,[string]$id){
  if($v -ge 2 -and $p -ge 1){return 'READY_FOR_LAB_VALIDATION'}
  if($v -ge 1 -and $p -eq 0){return 'NEEDS_PROOF_RUN'}
  if($v -eq 0 -and $p -ge 1){return 'NEEDS_VALIDATOR_SURFACE'}
  return 'BLOCKED_OR_TOO_GENERIC'
}
$triagePath='reports/self_development/ORGAN_PASSPORT_MATURITY_TRIAGE_V1.json'
Assert (Test-Path $triagePath) 'MISSING_TRIAGE_REPORT'
$triage=Get-Content $triagePath -Raw|ConvertFrom-Json
$targets=@($triage.items|Where-Object{$_.triage_decision -eq 'CALIBRATE_ORGAN_DRAFT'})
Assert ($targets.Count -eq 27) 'EXPECTED_27_ORGAN_DRAFTS'
$items=@()
foreach($t in $targets){
  $v=[int]$t.validator_count; $p=[int]$t.proof_count; $id=[string]$t.organ_id
  $d=Decision $v $p $id
  $why=switch($d){
    'READY_FOR_LAB_VALIDATION' {'has validators and proof references; candidate may enter lab validation, not activation'}
    'NEEDS_PROOF_RUN' {'has validator surface but lacks proof refs; run/attach proof before lab validation'}
    'NEEDS_VALIDATOR_SURFACE' {'has proof refs but lacks validator surface; add validator before lab validation'}
    default {'lacks validator and proof surface or is too generic for lab validation'}
  }
  $items += [pscustomobject]@{organ_id=$id;calibration_decision=$d;reason=$why;passport_kind=$t.passport_kind;source_lane=$t.source_lane;validator_count=$v;proof_count=$p;passport_path=$t.passport_path;next_action=($d -replace '_',' ')}
}
$items=@($items|Sort-Object calibration_decision,organ_id)
$ready=@($items|Where-Object{$_.calibration_decision -eq 'READY_FOR_LAB_VALIDATION'})
$shortlist=@($ready|Sort-Object @{Expression='validator_count';Descending=$true},@{Expression='proof_count';Descending=$true},organ_id|Select-Object -First 5)
$byDecision=@($items|Group-Object calibration_decision|Sort-Object Name|ForEach-Object{[ordered]@{calibration_decision=$_.Name;count=$_.Count}})
$report=[ordered]@{
  schema='organ_passport_calibration_v1'
  status='PASS_ORGAN_PASSPORT_CALIBRATION_V1'
  source_triage=$triagePath
  organ_draft_count=$targets.Count
  by_decision=$byDecision
  ready_for_lab_validation_count=$ready.Count
  lab_validation_shortlist=$shortlist
  items=$items
  boundaries=[ordered]@{calibration_only=$true;no_passport_status_mutation=$true;no_validated_lab_claim_created=$true;no_active_passports_created=$true;no_live_claims=$true;live_process_touched=$false}
  created_at=(Get-Date).ToString('o')
}
$proof=[ordered]@{
  schema='organ_passport_calibration_v1_proof'
  status='PASS_ORGAN_PASSPORT_CALIBRATION_V1'
  organ_draft_count=$targets.Count
  ready_for_lab_validation_count=$ready.Count
  needs_proof_run_count=@($items|Where-Object{$_.calibration_decision -eq 'NEEDS_PROOF_RUN'}).Count
  needs_validator_surface_count=@($items|Where-Object{$_.calibration_decision -eq 'NEEDS_VALIDATOR_SURFACE'}).Count
  blocked_or_too_generic_count=@($items|Where-Object{$_.calibration_decision -eq 'BLOCKED_OR_TOO_GENERIC'}).Count
  shortlist_ids=@($shortlist.organ_id)
  no_validated_lab_claim_created=$true
  no_active_passports_created=$true
  no_live_claims=$true
  live_process_touched=$false
  report_path='reports/self_development/ORGAN_PASSPORT_CALIBRATION_V1.json'
  created_at=(Get-Date).ToString('o')
}
WJson $report 'reports/self_development/ORGAN_PASSPORT_CALIBRATION_V1.json'
WJson $proof 'tests/self_development/ORGAN_PASSPORT_CALIBRATION_V1_PROOF.json'
Write-Host 'CALIBRATION_PASS=PASS_ORGAN_PASSPORT_CALIBRATION_V1'
Write-Host ('ORGAN_DRAFT_COUNT='+$targets.Count)
$byDecision|ForEach-Object{Write-Host ($_.calibration_decision+'='+$_.count)}
Write-Host ('SHORTLIST='+(@($shortlist.organ_id)-join ','))
