$ErrorActionPreference='Stop'
$RepoRoot=(Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
Set-Location $RepoRoot
function Assert($Cond,[string]$Msg){if(-not $Cond){throw $Msg}}
$contract=Get-Content 'self_model/ORGAN_PASSPORT_V1_CONTRACT.json' -Raw|ConvertFrom-Json
$reportPath='reports/self_development/ORGAN_PASSPORT_DRAFT_GENERATOR_FAST_LANE_V1.json'
$proofPath='tests/self_development/ORGAN_PASSPORT_DRAFT_GENERATOR_FAST_LANE_V1_PROOF.json'
foreach($p in @($reportPath,$proofPath)){Assert (Test-Path $p) ("MISSING:{0}" -f $p)}
$r=Get-Content $reportPath -Raw|ConvertFrom-Json
$p=Get-Content $proofPath -Raw|ConvertFrom-Json
Assert ($r.status -eq 'PASS_ORGAN_PASSPORT_DRAFT_GENERATOR_FAST_LANE_V1') 'REPORT_STATUS_BAD'
Assert ($p.status -eq 'PASS_ORGAN_PASSPORT_DRAFT_GENERATOR_FAST_LANE_V1') 'PROOF_STATUS_BAD'
$drafts=@($r.generated_drafts)
Assert ($drafts.Count -ge 2) 'DRAFT_COUNT_BAD'; Assert (@($drafts|Where-Object{$_.organ_id -eq 'operations_organ_promotion_lanes'}).Count -eq 1) 'TARGET_OPERATIONS_ORGAN_PROMOTION_LANES_DRAFT_MISSING'
foreach($d in $drafts){
  Assert (Test-Path $d.passport_path) ("PASSPORT_MISSING:{0}" -f $d.passport_path)
  Assert (Test-Path $d.doc_path) ("PASSPORT_DOC_MISSING:{0}" -f $d.doc_path)
  $pass=Get-Content $d.passport_path -Raw|ConvertFrom-Json
  foreach($field in @($contract.required_fields)){Assert ($pass.PSObject.Properties.Name -contains $field) ("REQUIRED_FIELD_MISSING:{0}:{1}" -f $d.organ_id,$field)}
  Assert ($pass.status -eq 'PASSPORT_DRAFT_FROM_EVIDENCE') ("PASSPORT_NOT_DRAFT:{0}" -f $d.organ_id)
  Assert (@('DRAFT','VALIDATED_LAB') -contains $pass.maturity) ("MATURITY_NOT_ALLOWED:{0}:{1}" -f $d.organ_id,$pass.maturity)
  Assert (@('NOT_PROVEN','PROVEN_LAB') -contains $pass.live_or_lab_status) ("LIVE_OR_LAB_NOT_ALLOWED:{0}:{1}" -f $d.organ_id,$pass.live_or_lab_status)
  Assert (@($pass.owned_files).Count -gt 0) ("OWNED_FILES_EMPTY:{0}" -f $d.organ_id)
  Assert (@($pass.source_evidence).Count -gt 0) ("SOURCE_EVIDENCE_EMPTY:{0}" -f $d.organ_id)
  Assert ($pass.status -ne 'PASSPORT_ACTIVE') ("ACTIVE_STATUS_FORBIDDEN:{0}" -f $d.organ_id)
  Assert ($pass.live_or_lab_status -ne 'PROVEN_LIVE') ("PROVEN_LIVE_FORBIDDEN:{0}" -f $d.organ_id)
}
Assert ($r.boundaries.no_active_passports_created -eq $true) 'ACTIVE_BOUNDARY_BAD'
Assert ($r.boundaries.no_live_claims -eq $true) 'LIVE_CLAIM_BOUNDARY_BAD'
Assert ($r.boundaries.passport_generator_for_all_candidates_blocked -eq $true) 'ALL_CANDIDATES_BLOCK_BAD'; Assert ($r.boundaries.passport_generator_repeatable_fast_lane -eq $true) 'REPEATABLE_FAST_LANE_BOUNDARY_MISSING'
Assert ($p.no_active_passports_created -eq $true) 'PROOF_ACTIVE_FALSE'
foreach($legacy in @('reports/self_development/CURRENT_BODY_CAPABILITY_SNAPSHOT_V1.json','self_knowledge/BUILDER_SELF_MODEL.json')){Assert (-not(Test-Path $legacy)) ("LEGACY_MAP_PRESENT:{0}" -f $legacy)}
Write-Host 'VALIDATION_PASS=PASS_ORGAN_PASSPORT_DRAFT_GENERATOR_FAST_LANE_V1'
Write-Host ('REPORT_PATH='+$reportPath)
Write-Host ('PROOF_PATH='+$proofPath)

