$ErrorActionPreference='Stop'
$RepoRoot=(Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
Set-Location $RepoRoot
function Assert($Cond,[string]$Msg){if(-not $Cond){throw $Msg}}
function Write-Json($Obj,[string]$Path){$dir=Split-Path $Path -Parent; if($dir -and -not(Test-Path $dir)){New-Item -ItemType Directory -Path $dir -Force|Out-Null}; $Obj|ConvertTo-Json -Depth 40|Set-Content -Path $Path -Encoding UTF8}
$contract=Get-Content 'self_model/ORGAN_PASSPORT_V1_CONTRACT.json' -Raw|ConvertFrom-Json
$reportPath='reports/self_development/ORGAN_PASSPORT_DRAFT_REVIEW_AND_INDEX_GATE_V1.json'
$proofPath='tests/self_development/ORGAN_PASSPORT_DRAFT_REVIEW_AND_INDEX_GATE_V1_PROOF.json'
$indexPath='self_model/organ_passports/_index/ORGAN_PASSPORT_DRAFT_INDEX_V1.json'
$passportFiles=@(Get-ChildItem 'self_model/organ_passports' -Recurse -Filter 'ORGAN_PASSPORT_V1.json'|Sort-Object FullName)
Assert ($passportFiles.Count -ge 2) 'PASSPORT_SCAN_COUNT_BAD'
$items=@()
foreach($file in $passportFiles){
  $rel=($file.FullName.Substring($RepoRoot.Length+1) -replace '\\','/')
  $pass=Get-Content $file.FullName -Raw|ConvertFrom-Json
  foreach($field in @($contract.required_fields)){Assert ($pass.PSObject.Properties.Name -contains $field) ("FIELD_MISSING:{0}:{1}" -f $pass.organ_id,$field)}
  Assert ($pass.status -eq 'PASSPORT_DRAFT_FROM_EVIDENCE') ("STATUS_NOT_DRAFT:{0}" -f $pass.organ_id)
  Assert (@('DRAFT','VALIDATED_LAB') -contains $pass.maturity) ("MATURITY_NOT_ALLOWED:{0}:{1}" -f $pass.organ_id,$pass.maturity)
  Assert (@('NOT_PROVEN','PROVEN_LAB') -contains $pass.live_or_lab_status) ("LIVE_STATUS_NOT_ALLOWED:{0}:{1}" -f $pass.organ_id,$pass.live_or_lab_status)
  $active=($pass.status -eq 'PASSPORT_ACTIVE' -or $pass.maturity -eq 'ACTIVE')
  $live=($pass.live_or_lab_status -eq 'PROVEN_LIVE')
  $decision='PASSPORT_DRAFT_VALIDATED_BLOCKED_RUNTIME_PROOF'
  if($pass.organ_id -eq 'operations_self_model'){$decision='LAB_VALIDATED_NOT_ACTIVE'}
  $items += [ordered]@{
    organ_id=$pass.organ_id
    passport_path=$rel
    owning_root=$pass.owning_root
    review_decision=$decision
    status=$pass.status
    maturity=$pass.maturity
    live_or_lab_status=$pass.live_or_lab_status
    validator_count=@($pass.validators).Count
    proof_count=@($pass.proof_refs).Count
    active_claim_detected=$active
    live_claim_detected=$live
  }
}
$items=@($items|Sort-Object organ_id)
Assert (@($items|Where-Object{$_.organ_id -eq 'operations_organ_promotion_lanes'}).Count -eq 1) 'TARGET_OPERATIONS_ORGAN_PROMOTION_LANES_REVIEW_MISSING'
Assert (@($items|Where-Object{$_.active_claim_detected -eq $true}).Count -eq 0) 'ACTIVE_CLAIM_DETECTED'
Assert (@($items|Where-Object{$_.live_claim_detected -eq $true}).Count -eq 0) 'PROVEN_LIVE_CLAIM_DETECTED'
$index=[ordered]@{
  schema='organ_passport_draft_index_v1'
  status='PASS_ORGAN_PASSPORT_DRAFT_INDEX_V1'
  generated_from='self_model/organ_passports/*/ORGAN_PASSPORT_V1.json'
  draft_count=$items.Count
  passports=$items
  entries=$items
  boundaries=[ordered]@{index_only=$true;no_status_mutation=$true;no_active_passports_created=$true;no_proven_live_claims_created=$true;live_process_touched=$false}
  created_at=(Get-Date).ToString('o')
}
$report=[ordered]@{
  schema='organ_passport_draft_review_and_index_gate_v1'
  status='PASS_ORGAN_PASSPORT_DRAFT_REVIEW_AND_INDEX_GATE_V1'
  source_passport_glob='self_model/organ_passports/*/ORGAN_PASSPORT_V1.json'
  reviewed_count=$items.Count
  items=$items
  root_cause_fixed='Review/index gate no longer assumes exactly two draft passports; it scans canonical passport drafts and validates target presence.'
  boundaries=[ordered]@{index_only=$true;no_status_mutation=$true;no_active_passports_created=$true;no_proven_live_claims_created=$true;live_process_touched=$false}
  created_at=(Get-Date).ToString('o')
}
$proof=[ordered]@{
  schema='organ_passport_draft_review_and_index_gate_v1_proof'
  status='PASS_ORGAN_PASSPORT_DRAFT_REVIEW_AND_INDEX_GATE_V1'
  report_path=$reportPath
  index_path=$indexPath
  reviewed_count=$items.Count
  reviewed_organ_ids=@($items.organ_id)
  operations_organ_promotion_lanes_reviewed=(@($items|Where-Object{$_.organ_id -eq 'operations_organ_promotion_lanes'}).Count -eq 1)
  no_active_passports_created=$true
  no_proven_live_claims=$true
  accepted_atom_calibrated=(@($items|Where-Object{$_.organ_id -eq 'contracts_accepted_atom_retention_organ'}).Count -eq 1)
  accepted_atom_review_decision='PASSPORT_DRAFT_VALIDATED_BLOCKED_RUNTIME_PROOF'
  live_process_touched=$false
  created_at=(Get-Date).ToString('o')
}
Write-Json $index $indexPath
Write-Json $report $reportPath
Write-Json $proof $proofPath
foreach($legacy in @('reports/self_development/CURRENT_BODY_CAPABILITY_SNAPSHOT_V1.json','self_knowledge/BUILDER_SELF_MODEL.json')){Assert (-not(Test-Path $legacy)) ("LEGACY_MAP_PRESENT:{0}" -f $legacy)}
Write-Host 'VALIDATION_PASS=PASS_ORGAN_PASSPORT_DRAFT_REVIEW_AND_INDEX_GATE_V1'
Write-Host ('REPORT_PATH='+$reportPath)
Write-Host ('PROOF_PATH='+$proofPath)
Write-Host ('INDEX_PATH='+$indexPath)
