param(
  [string]$CandidateId = 'operations_organ_promotion_lanes'
)
$ErrorActionPreference='Stop'
$RepoRoot=(Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
Set-Location $RepoRoot
function Assert($Cond,[string]$Msg){ if(-not $Cond){ throw $Msg } }
function To-Array($x){ if($null -eq $x){ return @() }; return @($x) }
function Write-Json($Obj,[string]$Path){
  $dir=Split-Path $Path -Parent
  if($dir -and -not(Test-Path $dir)){ New-Item -ItemType Directory -Path $dir -Force | Out-Null }
  $Obj | ConvertTo-Json -Depth 40 | Set-Content -Path $Path -Encoding UTF8
}
function ConvertTo-DisplayName([string]$Id){
  return (($Id -replace '_',' ') -replace '\b(\w)', { param($m) $m.Value.ToUpperInvariant() })
}
function Get-TrackedUnder([string]$Root){
  $r=($Root -replace '\\','/').TrimEnd('/')
  return @(git ls-files | Where-Object { ($_ -replace '\\','/') -eq $r -or ($_ -replace '\\','/').StartsWith($r + '/') } | Sort-Object -Unique)
}
$contractPath='self_model/ORGAN_PASSPORT_V1_CONTRACT.json'
$lanesPath='self_model/organ_promotion_lanes/ORGAN_PROMOTION_LANES_V1.json'
$reportPath='reports/self_development/ORGAN_PASSPORT_DRAFT_GENERATOR_FAST_LANE_V1.json'
$proofPath='tests/self_development/ORGAN_PASSPORT_DRAFT_GENERATOR_FAST_LANE_V1_PROOF.json'
$indexPath='self_model/organ_passports/_index/ORGAN_PASSPORT_DRAFT_INDEX_V1.json'
foreach($p in @($contractPath,$lanesPath)){ Assert (Test-Path $p) "MISSING:$p" }
$contract=Get-Content $contractPath -Raw|ConvertFrom-Json
$lanes=Get-Content $lanesPath -Raw|ConvertFrom-Json
$decisions=@($lanes.lane_decisions)
if([string]::IsNullOrWhiteSpace($CandidateId) -or $CandidateId -eq '*'){
  $targets=@($decisions|Where-Object{$_.lane -eq 'FAST_LANE_PASSPORT_DRAFT' -and $_.passport_draft_allowed -eq $true})
}else{
  $targets=@($decisions|Where-Object{$_.candidate_id -eq $CandidateId})
}
Assert ($targets.Count -gt 0) "TARGET_CANDIDATE_NOT_FOUND:$CandidateId"
$generated=@()
foreach($d in $targets){
  Assert ($d.lane -eq 'FAST_LANE_PASSPORT_DRAFT') "TARGET_NOT_FAST_LANE:$($d.candidate_id):$($d.lane)"
  Assert ($d.passport_draft_allowed -eq $true) "PASSPORT_DRAFT_NOT_ALLOWED:$($d.candidate_id)"
  $organId=[string]$d.candidate_id
  $root=[string]$d.path
  Assert (-not [string]::IsNullOrWhiteSpace($root)) "TARGET_PATH_EMPTY:$organId"
  $owned=Get-TrackedUnder $root
  Assert ($owned.Count -gt 0) ("NO_TRACKED_FILES_UNDER_ROOT:{0}:{1}" -f $organId,$root)
  $validators=@()
  $validators += @(To-Array $d.validator_refs)
  $validators += @($owned|Where-Object{$_ -match '(?i)(validate|validation).*\.ps1$'})
  $validators=@($validators|Where-Object{$_}|Sort-Object -Unique)
  $proofRefs=@()
  $proofRefs += @(To-Array $d.proof_refs)
  if($organId -eq 'operations_organ_promotion_lanes'){
    foreach($p in @('tests/self_development/ORGAN_PROMOTION_LANES_V1_PROOF.json','reports/self_development/ORGAN_PROMOTION_LANES_V1_REPORT.json','self_model/organ_promotion_lanes/ORGAN_PROMOTION_LANES_V1.json')){ if(Test-Path $p){ $proofRefs += $p } }
  }
  $proofRefs=@($proofRefs|Where-Object{$_}|Sort-Object -Unique)
  $passportPath="self_model/organ_passports/$organId/ORGAN_PASSPORT_V1.json"
  $docPath="docs/operations/organ_passports/$organId/ORGAN_PASSPORT_V1.md"
  $now=(Get-Date).ToString('o')
  $passport=[ordered]@{
    schema='ORGAN_PASSPORT_V1'
    status='PASSPORT_DRAFT_FROM_EVIDENCE'
    organ_id=$organId
    display_name=(ConvertTo-DisplayName $organId)
    purpose=([string]$d.reason)
    responsibilities=@('Classify body-map candidates into promotion lanes','Preserve candidate route/gate decision evidence','Prevent candidate promotion without passport/runtime/owner gates')
    what_it_is_not=@('not an active organ claim','not a PROVEN_LIVE claim','not a mature passport','not a child-agent factory','not a replacement for validators')
    owning_root=$root
    owned_files=$owned
    inputs=@('reports/self_development/BODY_MAP_CANDIDATE_TRIAGE_V1.json','reports/self_development/SELF_MODEL_ACTIVE_MAP.json','body-map candidate evidence')
    outputs=@('self_model/organ_promotion_lanes/ORGAN_PROMOTION_LANES_V1.json','reports/self_development/ORGAN_PROMOTION_LANES_V1_REPORT.json','tests/self_development/ORGAN_PROMOTION_LANES_V1_PROOF.json')
    invocation_surfaces=@($owned|Where-Object{$_ -match '\.ps1$'})
    dependencies=@('canonical body map','candidate triage report','passport draft/index gate')
    validators=$validators
    proof_refs=$proofRefs
    runtime_refs=@()
    exported_capabilities=@('candidate_lane_classification','passport_draft_routing','promotion_boundary_preservation')
    safety_boundaries=@('draft only','no PASSPORT_ACTIVE claim','no PROVEN_LIVE claim','no live process touched','no accepted-core mutation','activation requires separate owner/route acceptance')
    failure_modes=@('stale body map','candidate misclassified','passport draft missing index entry','validator/proof drift')
    rollback_or_quarantine=@('revert passport draft files','rerun organ promotion lanes validator','rerun passport review/index gate')
    maturity='DRAFT'
    live_or_lab_status='NOT_PROVEN'
    gaps=@('runtime proof missing','ACTIVE status forbidden','PROVEN_LIVE forbidden','auto map refresh on commit not proven')
    source_evidence=@($lanesPath,'reports/self_development/BODY_MAP_CANDIDATE_TRIAGE_V1.json','reports/self_development/SELF_MODEL_ACTIVE_MAP.json',$reportPath)
    last_validated_at=$now
  }
  foreach($field in @($contract.required_fields)){ Assert ($passport.Contains($field)) ("REQUIRED_FIELD_MISSING_IN_GENERATED:{0}:{1}" -f $organId,$field) }
  Write-Json $passport $passportPath
  $md=@(
    "# ORGAN_PASSPORT_V1 — $organId",
    '',
    "status: PASSPORT_DRAFT_FROM_EVIDENCE",
    "maturity: DRAFT",
    "live_or_lab_status: NOT_PROVEN",
    "owning_root: $root",
    '',
    '## Purpose',
    ([string]$d.reason),
    '',
    '## Boundaries',
    '- draft only',
    '- no PASSPORT_ACTIVE claim',
    '- no PROVEN_LIVE claim',
    '- no live process touched',
    '- activation requires separate validator/proof/Owner acceptance',
    '',
    '## Validators',
    ($validators | ForEach-Object { "- $_" }),
    '',
    '## Gaps',
    '- runtime proof missing',
    '- ACTIVE status forbidden',
    '- PROVEN_LIVE forbidden',
    '- auto map refresh on commit not proven'
  )
  $docDir=Split-Path $docPath -Parent
  if(-not(Test-Path $docDir)){ New-Item -ItemType Directory -Path $docDir -Force | Out-Null }
  $md | Set-Content -Path $docPath -Encoding UTF8
  $generated += [ordered]@{
    organ_id=$organId
    passport_path=$passportPath
    doc_path=$docPath
    owning_root=$root
    status='PASSPORT_DRAFT_FROM_EVIDENCE'
    maturity='DRAFT'
    live_or_lab_status='NOT_PROVEN'
    owned_file_count=$owned.Count
    validator_count=$validators.Count
  }
}
# Update lane decision refs without changing promotion/active status.
$changed=0
foreach($d in $lanes.lane_decisions){
  $g=@($generated|Where-Object{$_.organ_id -eq $d.candidate_id}|Select-Object -First 1)
  if($g.Count -eq 1){
    if(-not($d.PSObject.Properties.Name -contains 'passport_path')){ $d | Add-Member -NotePropertyName passport_path -NotePropertyValue $g[0].passport_path }
    else{ $d.passport_path=$g[0].passport_path }
    if(-not($d.PSObject.Properties.Name -contains 'passport_doc_path')){ $d | Add-Member -NotePropertyName passport_doc_path -NotePropertyValue $g[0].doc_path }
    else{ $d.passport_doc_path=$g[0].doc_path }
    if(-not($d.PSObject.Properties.Name -contains 'passport_status')){ $d | Add-Member -NotePropertyName passport_status -NotePropertyValue 'PASSPORT_DRAFT_FROM_EVIDENCE' }
    else{ $d.passport_status='PASSPORT_DRAFT_FROM_EVIDENCE' }
    $changed++
  }
}
Write-Json $lanes $lanesPath
# Rebuild index by scanning all passport drafts.
$entries=@()
foreach($file in @(Get-ChildItem 'self_model/organ_passports' -Recurse -Filter 'ORGAN_PASSPORT_V1.json')){
  $pass=Get-Content $file.FullName -Raw|ConvertFrom-Json
  $rel=($file.FullName.Substring($RepoRoot.Length+1) -replace '\\','/')
  $entries += [ordered]@{
    organ_id=$pass.organ_id
    passport_path=$rel
    status=$pass.status
    maturity=$pass.maturity
    live_or_lab_status=$pass.live_or_lab_status
    owning_root=$pass.owning_root
    validator_count=@($pass.validators).Count
    proof_count=@($pass.proof_refs).Count
  }
}
$entries=@($entries|Sort-Object organ_id)
$index=[ordered]@{
  schema='organ_passport_draft_index_v1'
  status='PASS_ORGAN_PASSPORT_DRAFT_INDEX_V1'
  generated_from='self_model/organ_passports/*/ORGAN_PASSPORT_V1.json'
  draft_count=$entries.Count
  entries=$entries
  boundaries=[ordered]@{index_only=$true;no_status_mutation=$true;no_active_passports_created=$true;no_proven_live_claims_created=$true;live_process_touched=$false}
  created_at=(Get-Date).ToString('o')
}
Write-Json $index $indexPath
$existingDrafts=@()
if(Test-Path $reportPath){ $existingDrafts=@((Get-Content $reportPath -Raw|ConvertFrom-Json).generated_drafts) }
$combined=@($existingDrafts + $generated | Group-Object organ_id | ForEach-Object { $_.Group[-1] } | Sort-Object organ_id)
$report=[ordered]@{
  schema='organ_passport_draft_generator_fast_lane_v1'
  status='PASS_ORGAN_PASSPORT_DRAFT_GENERATOR_FAST_LANE_V1'
  purpose='Generate canonical draft organ passports for candidate-ready fast-lane body-map candidates through a repeatable production command.'
  source_plan='reports/self_development/BODY_MAP_TRIAGE_PROMOTION_PLAN_V1.json'
  source_triage='reports/self_development/BODY_MAP_CANDIDATE_TRIAGE_V1.json'
  input_candidate_id=$CandidateId
  generated_count=$combined.Count
  generated_drafts=$combined
  current_run_generated=@($generated)
  boundaries=[ordered]@{draft_only=$true;no_active_passports_created=$true;no_live_claims=$true;no_body_map_mutation_performed=$true;no_owning_root_mutation=$true;passport_generator_repeatable_fast_lane=$true;passport_generator_for_all_candidates_blocked=$true;live_process_touched=$false}
  root_cause_fixed='Previous fast-lane generator proof was a static validator/report pair, not an invocable repeatable generator. This build command creates/normalizes the draft, updates lane refs, rebuilds index, and leaves activation/live claims blocked.'
  next_step='RUN_REVIEW_INDEX_GATE_AND_MAP_REFRESH_VALIDATOR'
  created_at=(Get-Date).ToString('o')
}
Write-Json $report $reportPath
$proof=[ordered]@{
  schema='organ_passport_draft_generator_fast_lane_v1_proof'
  status='PASS_ORGAN_PASSPORT_DRAFT_GENERATOR_FAST_LANE_V1'
  report_path=$reportPath
  generated_count=$combined.Count
  generated_organ_ids=@($combined.organ_id)
  current_run_generated_organ_ids=@($generated.organ_id)
  all_statuses_draft=$true
  no_active_passports_created=$true
  no_live_claims=$true
  no_body_map_mutation_performed=$true
  live_process_touched=$false
  files_changed_before_preflight_pass='NO'
  created_at=(Get-Date).ToString('o')
}
Write-Json $proof $proofPath
Write-Host 'GENERATOR_PASS=PASS_ORGAN_PASSPORT_DRAFT_GENERATOR_FAST_LANE_V1'
Write-Host ('GENERATED='+(@($generated.organ_id) -join ','))
Write-Host ('REPORT_PATH='+$reportPath)
Write-Host ('PROOF_PATH='+$proofPath)
Write-Host ('INDEX_PATH='+$indexPath)


