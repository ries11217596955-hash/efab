$ErrorActionPreference='Stop'
$RepoRoot=(Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
Set-Location $RepoRoot
function WJson($Obj,[string]$Path){$d=Split-Path $Path -Parent;if($d -and -not(Test-Path $d)){New-Item -ItemType Directory -Path $d -Force|Out-Null};$Obj|ConvertTo-Json -Depth 80|Set-Content $Path -Encoding UTF8}
function ReadJson($Path){ if(Test-Path $Path){ return (Get-Content $Path -Raw|ConvertFrom-Json) }; return $null }
$idx=ReadJson 'self_model/organ_passports/_index/ORGAN_PASSPORT_DRAFT_INDEX_V1.json'
$cal=ReadJson 'reports/self_development/ORGAN_PASSPORT_CALIBRATION_V1.json'
$proofRun=ReadJson 'reports/self_development/ORGAN_PASSPORT_PROOF_RUN_CALIBRATION_V1.json'
$entries=@($idx.entries)
$validated=@($entries|Where-Object{$_.maturity -match '^VALIDATED' -or $_.live_or_lab_status -match '^PROVEN'})
$organDrafts=@($entries|Where-Object{$_.passport_kind -in @('ORGAN_DRAFT_FAST_LANE','ORGAN_DRAFT_REVIEW','SELF_MODEL_META','BLOCKED_RUNTIME_REFERENCE') -or $_.organ_id -like 'operations_*'})
$notOrgans=@($entries|Where-Object{$_.passport_kind -match 'REFERENCE'})
$draftWithValidators=@($entries|Where-Object{$_.maturity -eq 'DRAFT' -and [int]$_.validator_count -gt 0})
$tailItems=@()
foreach($e in $draftWithValidators){
  $role='UNKNOWN_TAIL'
  $action='REVIEW'
  $why='draft has validators but no accepted maturity proof'
  if($e.passport_kind -match 'REFERENCE'){$role='MISLEADING_REFERENCE_WITH_VALIDATORS';$action='CONFIRM_REFERENCE_OR_PROMOTE_ONLY_IF_REAL_ORGAN';$why='reference/material has validator-like refs; likely not an organ'}
  elseif($e.organ_id -eq 'operations_live_start'){$role='ALREADY_INITIAL_LIVE_PROVEN_OR_INDEX_STALE';$action='VERIFY_INDEX_REFRESH';$why='live_start should be validated_live_initial after latest proof'}
  elseif([int]$e.validator_count -eq 1){$role='SINGLE_VALIDATOR_SURFACE';$action='EITHER_ADD_SECOND_SURFACE_OR_DOWNCLASSIFY_TO_MATERIAL';$why='one validator is not enough for organ maturity'}
  elseif([int]$e.validator_count -ge 2 -and [int]$e.proof_count -eq 0){$role='VALIDATORS_WITHOUT_PROOF_REFS';$action='RUN_OR_REPAIR_PROOF_REFS';$why='validators exist but passport lacks proof refs'}
  elseif([int]$e.validator_count -ge 2 -and [int]$e.proof_count -gt 0){$role='REVIEW_READY_DRAFT';$action='VALIDATE_OR_DOWNCLASSIFY';$why='has proof surface but still draft'}
  $tailItems += [ordered]@{organ_id=$e.organ_id;passport_kind=$e.passport_kind;source_lane=$e.source_lane;maturity=$e.maturity;live_or_lab_status=$e.live_or_lab_status;validator_count=[int]$e.validator_count;proof_count=[int]$e.proof_count;role=$role;recommended_action=$action;why=$why}
}
$topFive=@($tailItems|Sort-Object @{Expression={ if($_.role -eq 'REVIEW_READY_DRAFT'){0}elseif($_.role -eq 'VALIDATORS_WITHOUT_PROOF_REFS'){1}elseif($_.role -eq 'SINGLE_VALIDATOR_SURFACE'){2}else{3}}}, organ_id | Select-Object -First 5)
$byMaturity=@($entries|Group-Object maturity|Sort-Object Name|ForEach-Object{[ordered]@{name=$_.Name;count=$_.Count}})
$byLive=@($entries|Group-Object live_or_lab_status|Sort-Object Name|ForEach-Object{[ordered]@{name=$_.Name;count=$_.Count}})
$byKind=@($entries|Group-Object passport_kind|Sort-Object Name|ForEach-Object{[ordered]@{name=$_.Name;count=$_.Count}})
$report=[ordered]@{
 schema='organ_passport_maturity_summary_v1'
 status='PASS_ORGAN_PASSPORT_MATURITY_SUMMARY_V1'
 total_passports=$entries.Count
 by_maturity=$byMaturity
 by_live_or_lab_status=$byLive
 by_passport_kind=$byKind
 validated_or_proven_count=$validated.Count
 validated_or_proven=@($validated|Select-Object organ_id,passport_kind,maturity,live_or_lab_status,validator_count,proof_count)
 draft_with_validators_count=$draftWithValidators.Count
 tail_items=$tailItems
 next_five_review_candidates=$topFive
 interpretation=[ordered]@{
   repair_does_not_mean_broken_runtime=$true
   repair_means='classification/proof cleanup: remove duplicates, downclassify materials, add missing proof surface, or promote only with fresh evidence'
   deletion_requires_separate_owner_decision=$true
   no_deletion_performed=$true
 }
 boundaries=[ordered]@{summary_only=$true;no_passport_maturity_changed=$true;no_files_deleted=$true;no_live_runtime_touched=$true}
 created_at=(Get-Date).ToString('o')
}
$proof=[ordered]@{schema='organ_passport_maturity_summary_v1_proof';status='PASS_ORGAN_PASSPORT_MATURITY_SUMMARY_V1';total_passports=$entries.Count;validated_or_proven_count=$validated.Count;draft_with_validators_count=$draftWithValidators.Count;next_five_count=$topFive.Count;summary_only=$true;no_passport_maturity_changed=$true;no_files_deleted=$true;no_live_runtime_touched=$true;report_path='reports/self_development/ORGAN_PASSPORT_MATURITY_SUMMARY_V1.json';created_at=(Get-Date).ToString('o')}
WJson $report 'reports/self_development/ORGAN_PASSPORT_MATURITY_SUMMARY_V1.json'
WJson $proof 'tests/self_development/ORGAN_PASSPORT_MATURITY_SUMMARY_V1_PROOF.json'
Write-Host 'SUMMARY_PASS=PASS_ORGAN_PASSPORT_MATURITY_SUMMARY_V1'
Write-Host ('TOTAL_PASSPORTS='+$entries.Count)
Write-Host ('VALIDATED_OR_PROVEN='+$validated.Count)
Write-Host ('DRAFT_WITH_VALIDATORS='+$draftWithValidators.Count)
Write-Host 'NEXT_FIVE='; $topFive|ForEach-Object{Write-Host ($_.organ_id+'|'+$_.role+'|'+$_.recommended_action)}
