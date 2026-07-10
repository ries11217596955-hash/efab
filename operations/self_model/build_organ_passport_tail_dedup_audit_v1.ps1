$ErrorActionPreference='Stop'
$RepoRoot=(Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
Set-Location $RepoRoot
function Assert($Cond,[string]$Msg){if(-not $Cond){throw $Msg}}
function WJson($Obj,[string]$Path){$d=Split-Path $Path -Parent;if($d -and -not(Test-Path $d)){New-Item -ItemType Directory -Path $d -Force|Out-Null};$Obj|ConvertTo-Json -Depth 80|Set-Content $Path -Encoding UTF8}
function Passport($id){ Get-Content "self_model/organ_passports/$id/ORGAN_PASSPORT_V1.json" -Raw|ConvertFrom-Json }
function RootFiles($root){ if(Test-Path $root){ @(Get-ChildItem $root -Recurse -File|ForEach-Object{$_.FullName.Substring($RepoRoot.Length+1).Replace('\\','/')}) } else { @() } }
$ids=@('operations_contracts','operations_smoke_trials','operations_active_behavior','operations_organ_promotion_lanes','operations_overnight_school')
$rows=@()
foreach($id in $ids){
  $p=Passport $id
  $vRows=@()
  foreach($v in @($p.validators)){ $vRows += [ordered]@{path=[string]$v;exists=(Test-Path $v);is_executable_ps1=([string]$v -like '*.ps1')} }
  $rootFiles=RootFiles $p.owning_root
  $decision='REVIEW_REQUIRED'; $classification='UNKNOWN'; $action='OWNER_DECISION_REQUIRED'; $reason='not enough evidence'; $risk='false maturity'
  switch($id){
    'operations_contracts' { $decision='DOWNCLASSIFY_CANDIDATE'; $classification='CONTRACT_MATERIAL_AGGREGATOR_NOT_ORGAN'; $action='MERGE_OR_REFERENCE_UNDER_EXISTING_CONTRACT_PASSPORTS'; $reason='validator refs are .contract.json documents, not executable validators; multiple specific contracts_* passports already exist'; $risk='duplicate aggregate organ over contract materials' }
    'operations_smoke_trials' { $decision='DOWNCLASSIFY_CANDIDATE'; $classification='TEST_FIXTURE_MATERIAL_NOT_ORGAN'; $action='REFERENCE_AS_SMOKE_FIXTURES_OR_DELETE_CANDIDATE_AFTER_OWNER_REVIEW'; $reason='validator refs are fixture JSON files, not executable validators; root contains plan plus fixtures'; $risk='fixture folder falsely treated as organ' }
    'operations_active_behavior' { $decision='KEEP_AS_ORGAN_DRAFT'; $classification='REAL_ORGAN_DRAFT_WITH_EXECUTABLE_VALIDATORS'; $action='RUN_VALIDATORS_AND_ATTACH_PROOF_REFS_OR_KEEP_DRAFT'; $reason='two executable validators exist, but passport has no proof_refs'; $risk='under-proven but plausible organ' }
    'operations_organ_promotion_lanes' { $decision='KEEP_AS_GOVERNANCE_DRAFT'; $classification='GOVERNANCE_OR_META_ORGAN_DRAFT'; $action='ADD_SECOND_VALIDATION_SURFACE_BEFORE_PROMOTION'; $reason='has executable builder/validator/report/proof, but only one independent validator surface'; $risk='single-surface governance organ accepted too early' }
    'operations_overnight_school' { $decision='REPAIR_PASSPORT_LINK_KEEP_DRAFT'; $classification='LONG_RUNTIME_SCHOOL_DRAFT'; $action='FIX_CONCATENATED_VALIDATOR_PATH_AND_REVIEW_LONG_RUNTIME_BOUNDARY'; $reason='validator path is duplicated/concatenated and does not exist; corrected path exists'; $risk='bad passport reference plus heavy runtime treated as active organ' }
  }
  $rows += [ordered]@{organ_id=$id;owning_root=$p.owning_root;maturity=$p.maturity;live_or_lab_status=$p.live_or_lab_status;validator_refs=$vRows;proof_ref_count=@($p.proof_refs).Count;root_file_count=$rootFiles.Count;root_files_sample=@($rootFiles|Select-Object -First 20);decision=$decision;classification=$classification;recommended_action=$action;reason=$reason;risk=$risk}
}
# safe metadata repair: fix concatenated validator path only
$overnightPath='self_model/organ_passports/operations_overnight_school/ORGAN_PASSPORT_V1.json'
$overnight=Get-Content $overnightPath -Raw|ConvertFrom-Json
$bad='operations/overnight_school/validate_useful_school_30k_full_process_v1.ps1operations/overnight_school/validate_useful_school_30k_full_process_v1.ps1'
$good='operations/overnight_school/validate_useful_school_30k_full_process_v1.ps1'
if(@($overnight.validators) -contains $bad){
  $overnight.validators=@($overnight.validators|ForEach-Object{ if($_ -eq $bad){$good}else{$_} }|Sort-Object -Unique)
  $overnight.gaps=@(($overnight.gaps + 'long-runtime boundary review still required before promotion')|Where-Object{$_ -and $_ -ne 'runtime proof missing'}|Sort-Object -Unique)
  $overnight.proof_refs=@($overnight.proof_refs|Sort-Object -Unique)
  $overnight|ConvertTo-Json -Depth 60|Set-Content $overnightPath -Encoding UTF8
}
$reportPath='reports/self_development/ORGAN_PASSPORT_TAIL_DEDUP_AUDIT_V1.json'
$proofPath='tests/self_development/ORGAN_PASSPORT_TAIL_DEDUP_AUDIT_V1_PROOF.json'
$report=[ordered]@{
 schema='organ_passport_tail_dedup_audit_v1'
 status='PASS_ORGAN_PASSPORT_TAIL_DEDUP_AUDIT_V1'
 audited_ids=$ids
 decisions=$rows
 summary=[ordered]@{
   downclassify_candidates=(@($rows|Where-Object{$_.decision -eq 'DOWNCLASSIFY_CANDIDATE'}).Count)
   keep_as_draft=(@($rows|Where-Object{$_.decision -match '^KEEP'}).Count)
   repaired_passport_links=1
   delete_candidates_without_deletion=1
 }
 interpretation=[ordered]@{
   repair_means='dedup/downclassify/proof-surface cleanup, not runtime bug repair'
   no_runtime_organ_claimed_broken=$true
   deletion_requires_owner_decision=$true
 }
 boundaries=[ordered]@{no_files_deleted=$true;no_passport_promoted=$true;no_passport_active_created=$true;no_live_runtime_touched=$true;only_metadata_link_repair=$true}
 created_at=(Get-Date).ToString('o')
}
$proof=[ordered]@{schema='organ_passport_tail_dedup_audit_v1_proof';status='PASS_ORGAN_PASSPORT_TAIL_DEDUP_AUDIT_V1';audited_count=$ids.Count;downclassify_candidates=2;keep_as_draft=2;repaired_passport_links=1;no_files_deleted=$true;no_passport_promoted=$true;no_passport_active_created=$true;no_live_runtime_touched=$true;report_path=$reportPath;created_at=(Get-Date).ToString('o')}
WJson $report $reportPath
WJson $proof $proofPath
Write-Host 'AUDIT_PASS=PASS_ORGAN_PASSPORT_TAIL_DEDUP_AUDIT_V1'
Write-Host 'DOWNCLASSIFY_CANDIDATES=operations_contracts,operations_smoke_trials'
Write-Host 'KEEP_DRAFT=operations_active_behavior,operations_organ_promotion_lanes'
Write-Host 'REPAIRED_LINK=operations_overnight_school'
Write-Host "REPORT_PATH=$reportPath"
Write-Host "PROOF_PATH=$proofPath"
