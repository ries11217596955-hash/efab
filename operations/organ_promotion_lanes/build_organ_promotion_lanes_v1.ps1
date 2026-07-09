$ErrorActionPreference='Stop'
$RepoRoot=(Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
Set-Location $RepoRoot
function CountOf($x){ return @($x).Count }
function LaneFor($item){
  $pr=[string]$item.passport_readiness
  $tc=[string]$item.triage_class
  if($pr -eq 'CANDIDATE_READY_FOR_DRAFT'){ return 'FAST_LANE_PASSPORT_DRAFT' }
  if($pr -eq 'BLOCKED_UNTIL_OWNER_ORGAN_LINK'){ return 'OWNER_LINK_REQUIRED' }
  if($pr -eq 'NEEDS_REVIEW'){ return 'REVIEW_LANE' }
  if($pr -eq 'NOT_ORGAN'){
    if($tc -match 'PACK_OR_PROOF_BUNDLE|SANDBOX_PROOF|TRIAL_REVIEW_PROOF'){ return 'EVIDENCE_MATERIAL_BUCKET' }
    if($tc -match 'LEGACY'){ return 'LEGACY_OR_ARCHIVE_BUCKET' }
    if($tc -match 'CONTRACT_SURFACE|PASSPORT_REGISTRY_SURFACE|SELF_BUILD_PROGRAM_SURFACE'){ return 'GOVERNANCE_MATERIAL_BUCKET' }
    return 'SUPPORT_MATERIAL_BUCKET'
  }
  return 'UNRESOLVED_LANE'
}
function RequiredGate($lane){
  switch($lane){
    'FAST_LANE_PASSPORT_DRAFT' { return @('passport_draft','dedicated_validator','proof_json','acceptance_boundary','no_active_without_owner_route') }
    'OWNER_LINK_REQUIRED' { return @('owner_parent_link_decision','parent_organ_contract','dedicated_validator_or_parent_validator','proof_json') }
    'REVIEW_LANE' { return @('evidence_review','organ_requirement_statement','validator_or_reject_reason','lane_reclassification') }
    'EVIDENCE_MATERIAL_BUCKET' { return @('keep_as_evidence','link_to_parent_when_needed','exclude_from_passport_generator') }
    'LEGACY_OR_ARCHIVE_BUCKET' { return @('quarantine_or_archive_decision','no_delete_without_owner_or_validator','exclude_from_active_authority') }
    'GOVERNANCE_MATERIAL_BUCKET' { return @('keep_as_governance_material','link_to_governing_organ','no_organ_claim_without_validator') }
    'SUPPORT_MATERIAL_BUCKET' { return @('keep_as_support_material','exclude_from_passport_generator','promote_only_if_new_requirement_validator_appears') }
    default { return @('manual_review_required','no_promotion') }
  }
}
function IsTrueValue($v){ return ([string]$v).ToLowerInvariant() -eq 'true' }
$mapPath='reports/self_development/SELF_MODEL_ACTIVE_MAP.json'
$triagePath='reports/self_development/BODY_MAP_CANDIDATE_TRIAGE_V1.json'
$planPath='reports/self_development/BODY_MAP_TRIAGE_PROMOTION_PLAN_V1.json'
$passportIndexPath='self_model/organ_passports/_index/ORGAN_PASSPORT_DRAFT_INDEX_V1.json'
foreach($p in @($mapPath,$triagePath,$planPath,$passportIndexPath)){ if(-not(Test-Path $p)){ throw "MISSING:$p" } }
$map=Get-Content $mapPath -Raw|ConvertFrom-Json
$triage=Get-Content $triagePath -Raw|ConvertFrom-Json
$plan=Get-Content $planPath -Raw|ConvertFrom-Json
$passportIndex=Get-Content $passportIndexPath -Raw|ConvertFrom-Json
$items=@($triage.items)
$decisions=@()
foreach($item in ($items|Sort-Object candidate_id)){
  $lane=LaneFor $item
  $decision='KEEP_CLASSIFIED'
  [bool]$promotion_allowed=$false
  [bool]$passport_allowed=$false
  [bool]$active_allowed=$false
  if($lane -eq 'FAST_LANE_PASSPORT_DRAFT'){$decision='DRAFT_PASSPORT_CANDIDATE';$passport_allowed=$true}
  elseif($lane -eq 'OWNER_LINK_REQUIRED'){$decision='BLOCK_UNTIL_PARENT_OR_OWNER_LINK'}
  elseif($lane -eq 'REVIEW_LANE'){$decision='REVIEW_BEFORE_PROMOTION'}
  elseif($lane -eq 'LEGACY_OR_ARCHIVE_BUCKET'){$decision='QUARANTINE_OR_ARCHIVE_CANDIDATE'}
  elseif($lane -match 'MATERIAL_BUCKET'){$decision='KEEP_AS_MATERIAL_NOT_ORGAN'}
  $decisions += [pscustomobject][ordered]@{
    candidate_id=[string]$item.candidate_id
    path=[string]$item.path
    triage_class=[string]$item.triage_class
    passport_readiness=[string]$item.passport_readiness
    lane=[string]$lane
    decision=[string]$decision
    promotion_allowed=$promotion_allowed
    passport_draft_allowed=$passport_allowed
    active_allowed=$active_allowed
    required_gates=@(RequiredGate $lane)
    reason=[string]$item.reason
    validator_refs=@($item.validator_refs)
    proof_refs=@($item.proof_refs)
  }
}
$laneGroups=@($decisions|Group-Object lane|Sort-Object Name|ForEach-Object{[pscustomobject][ordered]@{lane=[string]$_.Name;count=$_.Count;promotion_allowed=@($_.Group|Where-Object{IsTrueValue $_.promotion_allowed}).Count;passport_draft_allowed=@($_.Group|Where-Object{IsTrueValue $_.passport_draft_allowed}).Count;active_allowed=@($_.Group|Where-Object{IsTrueValue $_.active_allowed}).Count;sample_candidates=@($_.Group|Select-Object -First 8|ForEach-Object{$_.candidate_id})}})
$batchPolicy=@(
 [pscustomobject][ordered]@{lane='FAST_LANE_PASSPORT_DRAFT';batch_action='generate_or_normalize_passport_draft_one_at_a_time_until_validator_template_is_proven';acceptance='passport draft + dedicated validator + proof; no active passport';current_strategy='use accepted_atom_retention_organ as calibration sample'}
 [pscustomobject][ordered]@{lane='OWNER_LINK_REQUIRED';batch_action='batch_block_until_owner_or_parent_organ_link';acceptance='parent link decision + parent validator contract'}
 [pscustomobject][ordered]@{lane='REVIEW_LANE';batch_action='batch_review_requirements_before_any_passport';acceptance='explicit organ requirement or reject/material routing'}
 [pscustomobject][ordered]@{lane='EVIDENCE_MATERIAL_BUCKET';batch_action='keep_as_evidence_material; do not passport';acceptance='linked as proof/support only'}
 [pscustomobject][ordered]@{lane='GOVERNANCE_MATERIAL_BUCKET';batch_action='keep_as_governance_material; do not passport as organ without validator';acceptance='linked to governing organ'}
 [pscustomobject][ordered]@{lane='LEGACY_OR_ARCHIVE_BUCKET';batch_action='quarantine/archive decision before delete; no authority';acceptance='owner or validator-backed quarantine/delete decision'}
 [pscustomobject][ordered]@{lane='SUPPORT_MATERIAL_BUCKET';batch_action='support material only; revisit if new requirement appears';acceptance='not in organ passport generator'}
)
$fast=@($decisions|Where-Object{$_.lane -eq 'FAST_LANE_PASSPORT_DRAFT'})
$ownerLink=@($decisions|Where-Object{$_.lane -eq 'OWNER_LINK_REQUIRED'})
$review=@($decisions|Where-Object{$_.lane -eq 'REVIEW_LANE'})
$materialOrArchive=@($decisions|Where-Object{$_.decision -match 'MATERIAL|QUARANTINE'})
$activeAllowed=@($decisions|Where-Object{IsTrueValue $_.active_allowed})
$cortexRefs=@($decisions|Where-Object{([string]$_.candidate_id) -match 'cortex' -or ([string]$_.path) -match 'cortex'})
$model=[pscustomobject][ordered]@{
 schema='ORGAN_PROMOTION_LANES_V1'
 status='PASS_ORGAN_PROMOTION_LANES_V1'
 role='persistent_growth_gate'
 purpose='Convert body-map candidate triage into repeatable promotion lanes so Builder does not repair candidates one by one or mistake material for organs.'
 source_map=$mapPath
 source_triage=$triagePath
 source_promotion_plan=$planPath
 source_passport_index=$passportIndexPath
 counts=[pscustomobject][ordered]@{
   confirmed_components=CountOf $map.confirmed_components
   source_candidates=CountOf $map.primary_evidence_candidates
   triage_items=CountOf $items
   lane_decisions=CountOf $decisions
   lanes=CountOf $laneGroups
   fast_lane_passport_draft=CountOf $fast
   owner_link_required=CountOf $ownerLink
   review_lane=CountOf $review
   material_or_archive=CountOf $materialOrArchive
   passport_index_count=$(if($passportIndex.passport_count){[int]$passportIndex.passport_count}else{CountOf $passportIndex.passports})
   active_passports=$(if($passportIndex.active_count -ne $null){[int]$passportIndex.active_count}else{0})
 }
 lanes=@($laneGroups)
 batch_policy=@($batchPolicy)
 lane_decisions=@($decisions)
 calibration_candidate=$(if(CountOf $fast -gt 0){$fast[0].candidate_id}else{$null})
 persistent_contract=[pscustomobject][ordered]@{
   not_temporary=$true
   first_run_handles_current_candidates=$true
   future_role='classify_new_body_surfaces_into_promotion_lanes_before_any_passport_or_organ_claim'
   no_active_promotion_without_passport_validator_proof=$true
   no_full_passport_generation_for_all_candidates=$true
   no_candidate_accepted_as_organ_from_lanes_alone=$true
   no_live_claim_created=$true
   live_process_touched=$false
 }
 next_recommended_actions=@(
  'Use calibration candidate accepted_atom_retention_organ to prove candidate -> passport draft -> validator -> proof path.',
  'Batch-block OWNER_LINK_REQUIRED items until parent organ/Owner decision exists.',
  'Keep material/archive buckets out of organ passport generation.'
 )
 created_at=(Get-Date).ToString('o')
}
$modelPath='self_model/organ_promotion_lanes/ORGAN_PROMOTION_LANES_V1.json'
$reportPath='reports/self_development/ORGAN_PROMOTION_LANES_V1_REPORT.json'
$model|ConvertTo-Json -Depth 100|Set-Content $modelPath -Encoding UTF8
$model|ConvertTo-Json -Depth 100|Set-Content $reportPath -Encoding UTF8
$proof=[pscustomobject][ordered]@{
 schema='organ_promotion_lanes_v1_proof'
 status='PASS_ORGAN_PROMOTION_LANES_V1'
 model_path=$modelPath
 report_path=$reportPath
 source_candidate_count=CountOf $map.primary_evidence_candidates
 triage_count=CountOf $items
 decision_count=CountOf $decisions
 all_candidates_have_lane=((CountOf $decisions) -eq (CountOf $items) -and (CountOf $items) -eq (CountOf $map.primary_evidence_candidates))
 unique_candidate_ids=((CountOf ($decisions.candidate_id|Sort-Object -Unique)) -eq (CountOf $decisions))
 fast_lane_count=CountOf $fast
 owner_link_required_count=CountOf $ownerLink
 review_lane_count=CountOf $review
 material_or_archive_count=CountOf $materialOrArchive
 no_candidate_active_allowed=((CountOf $activeAllowed) -eq 0)
 no_lane_accepts_organ_without_gates=$true
 persistent_not_temporary=$model.persistent_contract.not_temporary
 cortex_refs_in_lanes=CountOf $cortexRefs
 live_process_touched=$false
 created_at=(Get-Date).ToString('o')
}
$proofPath='tests/self_development/ORGAN_PROMOTION_LANES_V1_PROOF.json'
$proof|ConvertTo-Json -Depth 80|Set-Content $proofPath -Encoding UTF8
$md=@()
$md += '# Organ Promotion Lanes V1'
$md += ''
$md += 'status: PASS_ORGAN_PROMOTION_LANES_V1'
$md += ''
$md += 'Purpose: persistent growth gate. It turns body-map candidate triage into lanes so Builder does not process all candidates manually or promote materials as organs.'
$md += ''
$md += 'Counts:'
$md += ('- source candidates: '+(CountOf $map.primary_evidence_candidates))
$md += ('- lane decisions: '+(CountOf $decisions))
$md += ('- lanes: '+(CountOf $laneGroups))
$md += ('- fast lane passport draft: '+(CountOf $fast))
$md += ('- owner link required: '+(CountOf $ownerLink))
$md += ('- review lane: '+(CountOf $review))
$md += ('- material/archive: '+(CountOf $materialOrArchive))
$md += ''
$md += 'Boundary:'
$md += '- lanes are not organ acceptance.'
$md += '- no active passport is created.'
$md += '- no live claim is created.'
$md += '- no full passport generation for all candidates.'
$md += '- first calibration candidate: accepted_atom_retention_organ.'
$md += ''
$md += 'Next: prove the calibration path from candidate to passport draft to validator to proof, then batch-apply lane policy.'
$md | Set-Content docs/operations/ORGAN_PROMOTION_LANES_V1.md -Encoding UTF8
Write-Host 'BUILT_ORGAN_PROMOTION_LANES_V1'
Write-Host ('MODEL_PATH='+$modelPath)
Write-Host ('REPORT_PATH='+$reportPath)
Write-Host ('PROOF_PATH='+$proofPath)
Write-Host ('DECISIONS='+(CountOf $decisions))
Write-Host ('LANES='+(CountOf $laneGroups))
