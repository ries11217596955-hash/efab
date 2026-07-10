$ErrorActionPreference='Stop'
$RepoRoot=(Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
Set-Location $RepoRoot
function Assert($Cond,[string]$Msg){if(-not $Cond){throw $Msg}}
function WJson($Obj,[string]$Path){$d=Split-Path $Path -Parent;if($d -and -not(Test-Path $d)){New-Item -ItemType Directory -Path $d -Force|Out-Null};$Obj|ConvertTo-Json -Depth 60|Set-Content $Path -Encoding UTF8}
function KindFromLane([string]$lane,[string]$id){
  if($id -eq 'operations_self_model'){return 'SELF_MODEL_META'}
  switch($lane){
    'FAST_LANE_PASSPORT_DRAFT' {return 'ORGAN_DRAFT_FAST_LANE'}
    'REVIEW_LANE' {return 'ORGAN_DRAFT_REVIEW'}
    'OWNER_LINK_REQUIRED' {return 'OWNER_LINK_REQUIRED_REFERENCE'}
    'EVIDENCE_MATERIAL_BUCKET' {return 'EVIDENCE_MATERIAL_REFERENCE'}
    'LEGACY_OR_ARCHIVE_BUCKET' {return 'LEGACY_ARCHIVE_REFERENCE'}
    'SUPPORT_MATERIAL_BUCKET' {return 'SUPPORT_MATERIAL_REFERENCE'}
    'GOVERNANCE_MATERIAL_BUCKET' {return 'GOVERNANCE_MATERIAL_REFERENCE'}
    'CALIBRATED_PASSPORT_DRAFT_BLOCKED_RUNTIME' {return 'BLOCKED_RUNTIME_REFERENCE'}
    default {return 'COVERAGE_REFERENCE'}
  }
}
function DecisionForKind([string]$kind){
  if($kind -like 'ORGAN_DRAFT*'){return 'CALIBRATE_ORGAN_DRAFT'}
  if($kind -eq 'OWNER_LINK_REQUIRED_REFERENCE'){return 'OWNER_LINK_REQUIRED'}
  if($kind -eq 'BLOCKED_RUNTIME_REFERENCE'){return 'BLOCKED_RUNTIME_PROOF'}
  if($kind -eq 'SELF_MODEL_META'){return 'KEEP_META_PASSPORT'}
  return 'KEEP_AS_REFERENCE_MATERIAL'
}
$lanes=Get-Content 'self_model/organ_promotion_lanes/ORGAN_PROMOTION_LANES_V1.json' -Raw|ConvertFrom-Json
$laneById=@{}; foreach($d in @($lanes.lane_decisions)){$laneById[[string]$d.candidate_id]=$d}
$items=@()
foreach($f in @(Get-ChildItem 'self_model/organ_passports' -Recurse -Filter 'ORGAN_PASSPORT_V1.json')){
  $p=Get-Content $f.FullName -Raw|ConvertFrom-Json
  $id=[string]$p.organ_id
  $lane=''
  if($laneById.ContainsKey($id)){$lane=[string]$laneById[$id].lane}
  $kind=[string]$p.passport_kind
  if([string]::IsNullOrWhiteSpace($kind)){$kind=KindFromLane $lane $id}
  $decision=DecisionForKind $kind
  $rel=$f.FullName.Substring($RepoRoot.Length+1).Replace('\','/')
  $items += [pscustomobject]@{organ_id=$id;passport_kind=$kind;source_lane=$lane;triage_decision=$decision;passport_path=$rel;status=$p.status;maturity=$p.maturity;live_or_lab_status=$p.live_or_lab_status;validator_count=@($p.validators).Count;proof_count=@($p.proof_refs).Count}
}
$items=@($items|Sort-Object organ_id)
$byDecision=@($items|Group-Object triage_decision|Sort-Object Name|ForEach-Object{[ordered]@{triage_decision=$_.Name;count=$_.Count}})
$byKind=@($items|Group-Object passport_kind|Sort-Object Name|ForEach-Object{[ordered]@{passport_kind=$_.Name;count=$_.Count}})
$byLane=@($items|Group-Object source_lane|Sort-Object Name|ForEach-Object{[ordered]@{source_lane=if([string]::IsNullOrWhiteSpace($_.Name)){'NO_LANE_META'}else{$_.Name};count=$_.Count}})
$report=[ordered]@{schema='organ_passport_maturity_triage_v1';status='PASS_ORGAN_PASSPORT_MATURITY_TRIAGE_V1';passport_count=$items.Count;by_decision=$byDecision;by_kind=$byKind;by_lane=$byLane;items=$items;boundaries=[ordered]@{triage_only=$true;no_passport_status_mutation=$true;no_active_passports_created=$true;no_live_claims=$true;live_process_touched=$false};created_at=(Get-Date).ToString('o')}
$proof=[ordered]@{schema='organ_passport_maturity_triage_v1_proof';status='PASS_ORGAN_PASSPORT_MATURITY_TRIAGE_V1';passport_count=$items.Count;calibrate_organ_draft_count=@($items|Where-Object{$_.triage_decision -eq 'CALIBRATE_ORGAN_DRAFT'}).Count;owner_link_required_count=@($items|Where-Object{$_.triage_decision -eq 'OWNER_LINK_REQUIRED'}).Count;reference_material_count=@($items|Where-Object{$_.triage_decision -eq 'KEEP_AS_REFERENCE_MATERIAL'}).Count;blocked_runtime_count=@($items|Where-Object{$_.triage_decision -eq 'BLOCKED_RUNTIME_PROOF'}).Count;meta_count=@($items|Where-Object{$_.triage_decision -eq 'KEEP_META_PASSPORT'}).Count;no_active_passports_created=$true;no_live_claims=$true;live_process_touched=$false;report_path='reports/self_development/ORGAN_PASSPORT_MATURITY_TRIAGE_V1.json';created_at=(Get-Date).ToString('o')}
WJson $report 'reports/self_development/ORGAN_PASSPORT_MATURITY_TRIAGE_V1.json'
WJson $proof 'tests/self_development/ORGAN_PASSPORT_MATURITY_TRIAGE_V1_PROOF.json'
Write-Host 'TRIAGE_PASS=PASS_ORGAN_PASSPORT_MATURITY_TRIAGE_V1'
Write-Host ('PASSPORT_COUNT='+$items.Count)
$byDecision|ForEach-Object{Write-Host ($_.triage_decision+'='+$_.count)}

